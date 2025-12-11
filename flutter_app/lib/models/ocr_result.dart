import 'package:equatable/equatable.dart';

/// OCR result from any engine (ML Kit, Tesseract, or PaddleOCR)
class OCRResult extends Equatable {
  final String engine;           // 'mlkit', 'tesseract', or 'paddleocr'
  final double confidence;       // 0.0 - 1.0
  final String rawText;          // Extracted text
  final List<OCRTextBlock> blocks;  // Text blocks with coordinates
  final DateTime timestamp;
  final double processingTime;   // Seconds

  const OCRResult({
    required this.engine,
    required this.confidence,
    required this.rawText,
    required this.blocks,
    required this.timestamp,
    required this.processingTime,
  });

  @override
  List<Object?> get props => [
        engine,
        confidence,
        rawText,
        blocks,
        timestamp,
        processingTime,
      ];

  Map<String, dynamic> toJson() => {
        'engine': engine,
        'confidence': confidence,
        'raw_text': rawText,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
        'processing_time': processingTime,
      };

  factory OCRResult.fromJson(Map<String, dynamic> json) => OCRResult(
        engine: json['engine'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        rawText: json['raw_text'] as String,
        blocks: (json['blocks'] as List)
            .map((b) => OCRTextBlock.fromJson(b as Map<String, dynamic>))
            .toList(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        processingTime: (json['processing_time'] as num).toDouble(),
      );
}

/// Individual text block with position and confidence
class OCRTextBlock extends Equatable {
  final String text;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  const OCRTextBlock({
    required this.text,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  List<Object?> get props => [text, confidence, x, y, width, height];

  Map<String, dynamic> toJson() => {
        'text': text,
        'confidence': confidence,
        '_x': x,
        '_y': y,
        '_w': width,
        '_h': height,
      };

  factory OCRTextBlock.fromJson(Map<String, dynamic> json) => OCRTextBlock(
        text: json['text'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        x: (json['_x'] as num).toDouble(),
        y: (json['_y'] as num).toDouble(),
        width: (json['_w'] as num).toDouble(),
        height: (json['_h'] as num).toDouble(),
      );

  // Helper to get lines from text
  List<String> get lines => text.split('\n');
}

/// Hybrid OCR result containing results from multiple engines
class HybridOCRResult extends Equatable {
  final OCRResult primaryResult;      // The result that was used
  final OCRResult? tesseractResult;   // Tesseract result (if available)
  final String filename;
  final double totalProcessingTime;

  const HybridOCRResult({
    required this.primaryResult,
    this.tesseractResult,
    required this.filename,
    required this.totalProcessingTime,
  });

  @override
  List<Object?> get props => [
        primaryResult,
        tesseractResult,
        filename,
        totalProcessingTime,
      ];

  Map<String, dynamic> toJson() => {
        'primary_result': primaryResult.toJson(),
        'tesseract_result': tesseractResult?.toJson(),
        'filename': filename,
        'total_processing_time': totalProcessingTime,
      };

  factory HybridOCRResult.fromJson(Map<String, dynamic> json) =>
      HybridOCRResult(
        primaryResult: OCRResult.fromJson(
            json['primary_result'] as Map<String, dynamic>),
        tesseractResult: json['tesseract_result'] != null
            ? OCRResult.fromJson(
                json['tesseract_result'] as Map<String, dynamic>)
            : null,
        filename: json['filename'] as String,
        totalProcessingTime:
            (json['total_processing_time'] as num).toDouble(),
      );
}

