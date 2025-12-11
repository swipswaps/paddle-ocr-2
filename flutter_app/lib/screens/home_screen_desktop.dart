import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../services/ocr_service.dart';
import '../services/database_service.dart';
import 'result_screen.dart';
import 'history_screen.dart';

/// Desktop-optimized home screen (no camera support)
class HomeScreenDesktop extends StatefulWidget {
  final DatabaseService databaseService;

  const HomeScreenDesktop({super.key, required this.databaseService});

  @override
  State<HomeScreenDesktop> createState() => _HomeScreenDesktopState();
}

class _HomeScreenDesktopState extends State<HomeScreenDesktop> {
  final OCRService _ocrService = OCRService();
  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _pickAndProcessImage() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Selecting image...';
    });

    try {
      // Use file picker for desktop
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'jpeg', 'png', 'bmp', 'gif'],
      );
      
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      
      if (file == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No file selected';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Processing image with OCR...';
      });

      // Process with OCR
      final imageFile = File(file.path);
      final result = await _ocrService.processImage(imageFile);

      // Save to database
      await widget.databaseService.saveResult(result);

      // Navigate to result screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid OCR - Desktop'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoryScreen(
                    databaseService: widget.databaseService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _statusMessage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.document_scanner,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Hybrid OCR Scanner',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Desktop Version',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 60),
                  ElevatedButton.icon(
                    onPressed: _pickAndProcessImage,
                    icon: const Icon(Icons.folder_open, size: 28),
                    label: const Text(
                      'Choose Image File',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

