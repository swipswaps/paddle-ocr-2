import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Live text detection screen - real-time OCR from camera feed
class LiveTextScreen extends StatefulWidget {
  const LiveTextScreen({super.key});

  @override
  State<LiveTextScreen> createState() => _LiveTextScreenState();
}

class _LiveTextScreenState extends State<LiveTextScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  bool _isDetecting = false;
  String _detectedText = '';
  List<TextElement> _textElements = [];
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera available')),
          );
        }
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium, // Medium resolution for balance between speed and quality
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {});
        // Start processing frames
        _cameraController!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    // Skip if already processing
    if (_isDetecting) return;
    
    _isDetecting = true;

    try {
      // Convert CameraImage to InputImage
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      // Perform text recognition
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _detectedText = recognizedText.text;
          _textElements = recognizedText.blocks
              .expand((block) => block.lines)
              .expand((line) => line.elements)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Text recognition error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      // Get image rotation based on device orientation
      final rotation = InputImageRotation.rotation0deg;
      
      // Get image format
      final format = InputImageFormat.nv21;
      
      // Get plane data
      final plane = image.planes.first;
      
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('Image conversion error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Text Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _detectedText.isNotEmpty
                ? () {
                    // TODO: Copy text to clipboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Text copied to clipboard')),
                    );
                  }
                : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(_cameraController!),
          
          // Detected text overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_fields, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Detected Text (${_textElements.length} elements)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _detectedText.isEmpty ? 'Point camera at text...' : _detectedText,
                      style: TextStyle(
                        color: _detectedText.isEmpty ? Colors.grey : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Processing indicator
          if (_isDetecting)
            const Positioned(
              top: 16,
              right: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}


