import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Error dialog with copy logs functionality (matches React frontend)
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? details;
  final VoidCallback? onRetry;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
            if (details != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Technical Details:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: SelectableText(
                  details!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (details != null)
          TextButton.icon(
            onPressed: () {
              final fullLog = '''
Error: $title

Message: $message

Details:
$details

Timestamp: ${DateTime.now().toIso8601String()}
''';
              Clipboard.setData(ClipboardData(text: fullLog));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error log copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Logs'),
          ),
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// Show error dialog with automatic error formatting
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    VoidCallback? onRetry,
  }) {
    String? details;
    if (error != null) {
      details = error.toString();
      if (stackTrace != null) {
        details += '\n\nStack Trace:\n${stackTrace.toString()}';
      }
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        details: details,
        onRetry: onRetry,
      ),
    );
  }
}

