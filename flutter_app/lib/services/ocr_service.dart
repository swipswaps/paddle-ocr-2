import 'dart:io';
import 'dart:async';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img;
import '../models/ocr_result.dart';
import '../screens/processing_screen.dart';

/// Hybrid OCR service with cascade: ML Kit → Tesseract → PaddleOCR
/// On desktop (Linux/Windows): Tesseract → PaddleOCR (ML Kit not supported)
class OCRService {
  static const double mlKitThreshold = 0.90;
  static const double tesseractThreshold = 0.85;
  static const int maxImageDimension = 2048; // Downscale images larger than this

  final String? backendUrl;  // Optional backend URL for PaddleOCR
  final TextRecognizer? _textRecognizer; // Null on desktop platforms
  final bool _isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  OCRService({this.backendUrl})
    : _textRecognizer = (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
        ? null
        : TextRecognizer();

  /// Dispose resources
  void dispose() {
    _textRecognizer?.close();
  }

  /// Main entry point: Smart cascade OCR
  Future<HybridOCRResult> processImage(File imageFile) async {
    final startTime = DateTime.now();

    // Optimize image size before processing
    final optimizedFile = await _optimizeImage(imageFile);

    // DESKTOP: Use backend's hybrid endpoint (Tesseract → PaddleOCR)
    // Backend already has working Tesseract + PaddleOCR cascade
    if (_isDesktop) {
      if (backendUrl != null && await _isBackendAvailable()) {
        return await _recognizeWithBackendHybrid(optimizedFile);
      } else {
        throw Exception(
          'Backend required for desktop OCR.\n\n'
          'Start backend with: docker-compose up -d\n'
          'Or configure backendUrl in main.dart'
        );
      }
    }

    // MOBILE: Use local ML Kit → Tesseract → Backend cascade
    // Step 1: Try ML Kit (fastest, 2-3s)
    final mlKitResult = await _recognizeWithMLKit(optimizedFile);
    if (mlKitResult.confidence >= mlKitThreshold) {
      return HybridOCRResult(
        primaryResult: mlKitResult,
        filename: imageFile.path.split('/').last,
        totalProcessingTime: DateTime.now().difference(startTime).inMilliseconds / 1000.0,
      );
    }

    // Step 2: Try Tesseract (medium speed, 5-8s)
    final tesseractResult = await _recognizeWithTesseract(optimizedFile);
    if (tesseractResult.confidence >= tesseractThreshold) {
      return HybridOCRResult(
        primaryResult: tesseractResult,
        tesseractResult: tesseractResult,
        filename: imageFile.path.split('/').last,
        totalProcessingTime: DateTime.now().difference(startTime).inMilliseconds / 1000.0,
      );
    }

    // Step 3: Try PaddleOCR via backend (slowest, 60-90s, most accurate)
    if (backendUrl != null && await _isBackendAvailable()) {
      final paddleResult = await _recognizeWithPaddleOCR(optimizedFile);
      return HybridOCRResult(
        primaryResult: paddleResult,
        tesseractResult: tesseractResult,  // Include Tesseract result for comparison
        filename: imageFile.path.split('/').last,
        totalProcessingTime: DateTime.now().difference(startTime).inMilliseconds / 1000.0,
      );
    }

    // Fallback: Return best local result
    final bestResult = mlKitResult.confidence > tesseractResult.confidence
        ? mlKitResult
        : tesseractResult;

    return HybridOCRResult(
      primaryResult: bestResult,
      tesseractResult: tesseractResult,
      filename: imageFile.path.split('/').last,
      totalProcessingTime: DateTime.now().difference(startTime).inMilliseconds / 1000.0,
    );
  }

  /// Process image with real-time log streaming (for desktop with backend)
  Future<HybridOCRResult> processImageWithLogs(
    File imageFile, {
    required Function(String message, LogType type) onLog,
  }) async {
    final startTime = DateTime.now();

    // Optimize image size before processing
    final optimizedFile = await _optimizeImage(imageFile);

    // Desktop: Use backend with log streaming
    if (_isDesktop) {
      if (backendUrl == null || !await _isBackendAvailable()) {
        throw Exception(
          'Backend required for desktop OCR.\n\n'
          'Start backend with: docker-compose up -d\n'
          'Or configure backendUrl in main.dart'
        );
      }

      // Start log streaming
      final logStreamController = StreamController<String>();
      _streamBackendLogs(logStreamController.stream, onLog);

      try {
        final result = await _recognizeWithBackendHybrid(optimizedFile);
        logStreamController.close();
        return result;
      } catch (e) {
        logStreamController.close();
        rethrow;
      }
    }

    // Mobile: Use local processing (no log streaming for now)
    onLog('[SYSTEM] Using local OCR engines...', LogType.system);
    return await processImage(optimizedFile);
  }

  /// Stream logs from backend /logs/stream endpoint
  void _streamBackendLogs(
    Stream<String> logStream,
    Function(String message, LogType type) onLog,
  ) {
    // Connect to backend SSE stream
    final client = HttpClient();
    client.getUrl(Uri.parse('$backendUrl/logs/stream')).then((request) {
      return request.close();
    }).then((response) {
      response.transform(utf8.decoder).listen((data) {
        // Parse SSE format: "data: {...}\n\n"
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            try {
              final json = jsonDecode(jsonStr);
              final message = json['msg'] ?? json['message'] ?? '';
              if (message.isNotEmpty) {
                final type = _classifyLogType(message);
                onLog(message, type);
              }
            } catch (e) {
              // Ignore parse errors
            }
          }
        }
      });
    }).catchError((e) {
      onLog('[ERROR] Failed to connect to log stream: $e', LogType.error);
    });
  }

  /// Classify log message type (matches React frontend logic)
  LogType _classifyLogType(String message) {
    if (message.contains('[ERROR]') || message.toLowerCase().contains('error') || message.toLowerCase().contains('failed')) {
      return LogType.error;
    } else if (message.contains('[RAW]')) {
      return LogType.raw;
    } else if (message.contains('[REAL DATA]') || message.contains('[ INFO]') || message.contains('[Preprocess]') || message.contains('[OCR]') || message.contains('[TESSERACT]') || message.contains('[HYBRID]')) {
      return LogType.ocr;
    } else {
      return LogType.system;
    }
  }

  /// Optimize image size to reduce processing time
  Future<File> _optimizeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return imageFile;

      // Check if image needs downscaling
      if (image.width <= maxImageDimension && image.height <= maxImageDimension) {
        return imageFile; // No optimization needed
      }

      // Calculate new dimensions maintaining aspect ratio
      final aspectRatio = image.width / image.height;
      int newWidth, newHeight;

      if (image.width > image.height) {
        newWidth = maxImageDimension;
        newHeight = (maxImageDimension / aspectRatio).round();
      } else {
        newHeight = maxImageDimension;
        newWidth = (maxImageDimension * aspectRatio).round();
      }

      // Resize image
      final resized = img.copyResize(image, width: newWidth, height: newHeight);

      // Save to temporary file
      final tempPath = '${imageFile.parent.path}/optimized_${imageFile.path.split('/').last}';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(img.encodeJpg(resized, quality: 85));

      return tempFile;
    } catch (e) {
      // If optimization fails, return original
      return imageFile;
    }
  }

  /// ML Kit OCR (fast, mobile-optimized) - Mobile only
  Future<OCRResult> _recognizeWithMLKit(File imageFile) async {
    if (_textRecognizer == null) {
      throw UnsupportedError('ML Kit is not supported on desktop platforms');
    }

    final startTime = DateTime.now();
    final inputImage = InputImage.fromFile(imageFile);

    try {
      final recognizedText = await _textRecognizer!.processImage(inputImage);

      final blocks = <OCRTextBlock>[];
      double totalConfidence = 0.0;
      int blockCount = 0;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          // ML Kit doesn't provide confidence, estimate based on text quality
          final confidence = _estimateConfidence(line.text);
          totalConfidence += confidence;
          blockCount++;

          blocks.add(OCRTextBlock(
            text: line.text,
            confidence: confidence,
            x: line.boundingBox.left.toDouble(),
            y: line.boundingBox.top.toDouble(),
            width: line.boundingBox.width.toDouble(),
            height: line.boundingBox.height.toDouble(),
          ));
        }
      }

      final avgConfidence = blockCount > 0 ? totalConfidence / blockCount : 0.0;

      return OCRResult(
        engine: 'mlkit',
        confidence: avgConfidence,
        rawText: recognizedText.text,
        blocks: blocks,
        timestamp: DateTime.now(),
        processingTime: DateTime.now().difference(startTime).inMilliseconds / 1000.0,
      );
    } catch (e) {
      rethrow;
    }
    // Note: Don't close _textRecognizer here - it's reused across calls
  }

  /// Tesseract OCR (offline, good accuracy)
  Future<OCRResult> _recognizeWithTesseract(File imageFile) async {
    final startTime = DateTime.now();

    // Use Tesseract with PSM 6 (uniform block of text)
    final text = await FlutterTesseractOcr.extractText(
      imageFile.path,
      language: 'eng',
      args: {
        "psm": "6",  // Assume uniform block of text
        "preserve_interword_spaces": "1",
      },
    );

    // Tesseract doesn't provide per-block confidence in this API
    // Estimate based on text quality
    final confidence = _estimateConfidence(text);

    return OCRResult(
      engine: 'tesseract',
      confidence: confidence,
      rawText: text,
      blocks: [
        OCRTextBlock(
          text: text,
          confidence: confidence,
          x: 0,
          y: 0,
          width: 0,
          height: 0,
        ),
      ],
      timestamp: DateTime.now(),
      processingTime: DateTime.now().difference(startTime).inMilliseconds / 1000.0,
    );
  }

  /// Backend hybrid OCR (Tesseract → PaddleOCR cascade) - Desktop only
  Future<HybridOCRResult> _recognizeWithBackendHybrid(File imageFile) async {
    final startTime = DateTime.now();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendUrl/ocr/hybrid'),
    );

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
    ));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception('Backend OCR failed: ${json['error']}');
    }

    final blocks = (json['blocks'] as List)
        .map((b) => OCRTextBlock.fromJson(b as Map<String, dynamic>))
        .toList();

    final primaryResult = OCRResult(
      engine: json['engine'] as String? ?? 'hybrid',
      confidence: (json['confidence'] as num).toDouble(),
      rawText: json['raw_text'] as String,
      blocks: blocks,
      timestamp: DateTime.now(),
      processingTime: (json['duration'] as num?)?.toDouble() ?? 0.0,
    );

    // Check if Tesseract result is included
    OCRResult? tesseractResult;
    if (json.containsKey('tesseract_result')) {
      final tessJson = json['tesseract_result'] as Map<String, dynamic>;
      final tessBlocks = (tessJson['blocks'] as List?)
          ?.map((b) => OCRTextBlock.fromJson(b as Map<String, dynamic>))
          .toList() ?? [];

      tesseractResult = OCRResult(
        engine: 'tesseract',
        confidence: (tessJson['confidence'] as num).toDouble(),
        rawText: tessJson['text'] as String,
        blocks: tessBlocks,
        timestamp: DateTime.now(),
        processingTime: (tessJson['duration'] as num?)?.toDouble() ?? 0.0,
      );
    }

    return HybridOCRResult(
      primaryResult: primaryResult,
      tesseractResult: tesseractResult,
      filename: imageFile.path.split('/').last,
      totalProcessingTime: DateTime.now().difference(startTime).inMilliseconds / 1000.0,
    );
  }

  /// PaddleOCR via backend (most accurate, slowest) - Mobile fallback
  Future<OCRResult> _recognizeWithPaddleOCR(File imageFile) async {
    final startTime = DateTime.now();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendUrl/ocr'),
    );

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
    ));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception('PaddleOCR failed: ${json['error']}');
    }

    final blocks = (json['blocks'] as List)
        .map((b) => OCRTextBlock.fromJson(b as Map<String, dynamic>))
        .toList();

    return OCRResult(
      engine: 'paddleocr',
      confidence: (json['confidence'] as num).toDouble(),
      rawText: json['raw_text'] as String,
      blocks: blocks,
      timestamp: DateTime.now(),
      processingTime: DateTime.now().difference(startTime).inMilliseconds / 1000.0,
    );
  }

  /// Check if backend is available
  Future<bool> _isBackendAvailable() async {
    if (backendUrl == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$backendUrl/health'),
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Estimate confidence based on text quality (heuristic)
  double _estimateConfidence(String text) {
    if (text.isEmpty) return 0.0;

    // Count alphanumeric characters vs total
    final alphanumeric = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final ratio = alphanumeric.length / text.length;

    // Penalize very short text
    if (text.length < 10) return ratio * 0.5;

    // Reward longer text with good ratio
    return ratio * 0.95;
  }
}

