import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/ocr_result.dart';
import 'result_screen.dart';

/// History screen showing all past OCR results
class HistoryScreen extends StatefulWidget {
  final DatabaseService databaseService;

  const HistoryScreen({super.key, required this.databaseService});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _filteredResults = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final results = await widget.databaseService.getAllResults();
    setState(() {
      _results = results;
      _filteredResults = results;
      _isLoading = false;
    });
  }

  void _searchResults(String query) {
    if (query.isEmpty) {
      setState(() => _filteredResults = _results);
      return;
    }

    setState(() {
      _filteredResults = _results.where((result) {
        final text = (result['raw_text'] as String).toLowerCase();
        final filename = (result['filename'] as String).toLowerCase();
        final searchLower = query.toLowerCase();
        return text.contains(searchLower) || filename.contains(searchLower);
      }).toList();
    });
  }

  Future<void> _deleteResult(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Result'),
        content: const Text('Are you sure you want to delete this result?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.databaseService.deleteResult(id);
      _loadResults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Result deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadResults,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search results...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchResults('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchResults,
            ),
          ),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredResults.length} result${_filteredResults.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Results list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No OCR results yet'
                                  : 'No results found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredResults.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final result = _filteredResults[index];
                          return _buildResultCard(result);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final id = result['id'] as int;
    final filename = result['filename'] as String;
    final engine = result['engine'] as String;
    final confidence = result['confidence'] as double;
    final rawText = result['raw_text'] as String;
    final timestamp = DateTime.parse(result['timestamp'] as String);
    final processingTime = result['processing_time'] as double;

    // Preview text (first 100 characters)
    final preview = rawText.length > 100
        ? '${rawText.substring(0, 100)}...'
        : rawText;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to result screen
          // TODO: Reconstruct HybridOCRResult from database
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('View full result - coming soon')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      filename,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteResult(id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Metadata row
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildChip(
                    Icons.memory,
                    engine.toUpperCase(),
                    Colors.blue,
                  ),
                  _buildChip(
                    Icons.check_circle,
                    '${(confidence * 100).toStringAsFixed(0)}%',
                    _getConfidenceColor(confidence),
                  ),
                  _buildChip(
                    Icons.timer,
                    '${processingTime.toStringAsFixed(1)}s',
                    Colors.grey,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Preview text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  preview.isEmpty ? 'No text detected' : preview,
                  style: TextStyle(
                    fontSize: 13,
                    color: preview.isEmpty ? Colors.grey : Colors.black87,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 8),

              // Timestamp
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.85) return Colors.green;
    if (confidence >= 0.70) return Colors.orange;
    return Colors.red;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}


