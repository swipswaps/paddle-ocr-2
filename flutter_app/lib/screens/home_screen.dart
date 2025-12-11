import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/ocr_service.dart';
import '../services/database_service.dart';
import '../models/ocr_result.dart';
import '../widgets/error_dialog.dart';
import 'result_screen.dart';
import 'live_text_screen.dart';
import 'history_screen.dart';
import 'processing_screen.dart';

class HomeScreen extends StatefulWidget {
  final DatabaseService databaseService;
  final String? backendUrl;

  const HomeScreen({
    super.key,
    required this.databaseService,
    this.backendUrl,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  late final OCRService _ocrService;
  
  bool _isProcessing = false;
  String _statusMessage = '';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _ocrService = OCRService(backendUrl: widget.backendUrl);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      final imageFile = File(image.path);

      // Navigate to processing screen with real-time logs
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProcessingScreen(
              imageFile: imageFile,
              ocrService: _ocrService,
              databaseService: widget.databaseService,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        await ErrorDialog.show(
          context,
          title: 'Image Selection Failed',
          message: 'Failed to select the image. Please try again.',
          error: e,
          stackTrace: stackTrace,
          onRetry: () => _pickImage(source),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid OCR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoryScreen(databaseService: widget.databaseService),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _isProcessing
            ? _buildProcessingView()
            : _buildIdleView(),
      ),
    );
  }

  Widget _buildIdleView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.document_scanner,
          size: 100,
          color: Colors.blue,
        ),
        const SizedBox(height: 32),
        const Text(
          'Hybrid OCR',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Fast, accurate text recognition with ML Kit, Tesseract, and PaddleOCR',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 48),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LiveTextScreen()),
            );
          },
          icon: const Icon(Icons.video_camera_front),
          label: const Text('Live Text Detection'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            backgroundColor: Colors.green,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take Photo'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Choose from Gallery'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          _statusMessage,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: LinearProgressIndicator(value: _progress),
        ),
      ],
    );
  }
}

