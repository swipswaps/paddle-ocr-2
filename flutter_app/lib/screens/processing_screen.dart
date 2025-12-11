import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ocr_result.dart';
import '../services/ocr_service.dart';
import '../services/database_service.dart';
import 'result_screen.dart';

/// Processing screen with real-time logs (matches React frontend)
class ProcessingScreen extends StatefulWidget {
  final File imageFile;
  final OCRService ocrService;
  final DatabaseService databaseService;

  const ProcessingScreen({
    super.key,
    required this.imageFile,
    required this.ocrService,
    required this.databaseService,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isProcessing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addLog('[SYSTEM] Starting OCR processing...', LogType.system);
    _processImage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String message, LogType type) {
    setState(() {
      _logs.add(LogEntry(
        message: message,
        timestamp: DateTime.now(),
        type: type,
      ));
    });
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _processImage() async {
    try {
      _addLog('[SYSTEM] Connecting to backend...', LogType.system);
      
      // Process with backend (which streams logs)
      final result = await widget.ocrService.processImageWithLogs(
        widget.imageFile,
        onLog: (message, type) {
          if (mounted) {
            _addLog(message, type);
          }
        },
      );

      _addLog('[SYSTEM] OCR processing complete!', LogType.system);
      
      // Save to database
      await widget.databaseService.saveResult(result);
      _addLog('[SYSTEM] Result saved to database', LogType.system);

      setState(() {
        _isProcessing = false;
      });

      // Navigate to result screen
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(result: result),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _addLog('[ERROR] Processing failed: $e', LogType.error);
      setState(() {
        _isProcessing = false;
        _error = e.toString();
      });
    }
  }

  void _copyAllLogs() {
    final logsText = _logs.map((log) {
      final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
                   '${log.timestamp.minute.toString().padLeft(2, '0')}:'
                   '${log.timestamp.second.toString().padLeft(2, '0')}';
      return '$time ${log.message}';
    }).join('\n');

    Clipboard.setData(ClipboardData(text: logsText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing OCR'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Copy logs button
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy All Logs',
            onPressed: _logs.isEmpty ? null : _copyAllLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          if (_isProcessing)
            const LinearProgressIndicator(),

          // Logs panel
          Expanded(
            child: Container(
              color: Colors.black87,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return _buildLogEntry(log);
                },
              ),
            ),
          ),

          // Action buttons
          if (!_isProcessing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _copyAllLogs,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy All Logs'),
                  ),
                  if (_error != null)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    Color textColor;
    switch (log.type) {
      case LogType.error:
        textColor = Colors.red[300]!;
        break;
      case LogType.ocr:
        textColor = Colors.green[300]!;
        break;
      case LogType.system:
        textColor = Colors.blue[300]!;
        break;
      case LogType.raw:
        textColor = Colors.grey[400]!;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            '${log.timestamp.hour.toString().padLeft(2, '0')}:'
            '${log.timestamp.minute.toString().padLeft(2, '0')}:'
            '${log.timestamp.second.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              log.message,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Log entry model
class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogType type;

  LogEntry({
    required this.message,
    required this.timestamp,
    required this.type,
  });
}

/// Log types (matches React frontend)
enum LogType {
  system,
  ocr,
  error,
  raw,
}

