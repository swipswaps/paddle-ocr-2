import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/ocr_result.dart';

class ResultScreen extends StatefulWidget {
  final HybridOCRResult result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentTabIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getCurrentTabContent() {
    switch (_currentTabIndex) {
      case 0: // Text
        return widget.result.primaryResult.rawText;
      case 1: // CSV
        return _generateCSV();
      case 2: // JSON
        return _generateJSON();
      case 3: // SQL
        return _generateSQL();
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _getCurrentTabContent()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${_getTabName(_currentTabIndex)} copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share functionality - coming soon')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.text_fields), text: 'Text'),
            Tab(icon: Icon(Icons.table_chart), text: 'CSV'),
            Tab(icon: Icon(Icons.code), text: 'JSON'),
            Tab(icon: Icon(Icons.storage), text: 'SQL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTextTab(),
          _buildCSVTab(),
          _buildJSONTab(),
          _buildSQLTab(),
        ],
      ),
    );
  }

  String _getTabName(int index) {
    switch (index) {
      case 0: return 'Text';
      case 1: return 'CSV';
      case 2: return 'JSON';
      case 3: return 'SQL';
      default: return 'Content';
    }
  }

  // Tab views
  Widget _buildTextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetadataCard(),
          const SizedBox(height: 16),
          _buildTextCard('Primary Result', widget.result.primaryResult),
          if (widget.result.tesseractResult != null) ...[
            const SizedBox(height: 16),
            _buildTextCard('Tesseract Result (for comparison)', widget.result.tesseractResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildCSVTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetadataCard(),
          const SizedBox(height: 16),
          _buildCodeCard('CSV Format', _generateCSV(), 'csv'),
        ],
      ),
    );
  }

  Widget _buildJSONTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetadataCard(),
          const SizedBox(height: 16),
          _buildCodeCard('JSON Format', _generateJSON(), 'json'),
        ],
      ),
    );
  }

  Widget _buildSQLTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetadataCard(),
          const SizedBox(height: 16),
          _buildCodeCard('SQL Insert Statement', _generateSQL(), 'sql'),
        ],
      ),
    );
  }

  // Data generators
  String _generateCSV() {
    final lines = <String>[];
    lines.add('Block,Line,Text,Confidence');

    int blockIndex = 0;
    for (final block in widget.result.primaryResult.blocks) {
      blockIndex++;
      int lineIndex = 0;
      for (final line in block.lines) {
        lineIndex++;
        final text = line.replaceAll('"', '""'); // Escape quotes
        final confidence = (widget.result.primaryResult.confidence * 100).toStringAsFixed(1);
        lines.add('"Block $blockIndex","Line $lineIndex","$text","$confidence%"');
      }
    }

    return lines.join('\n');
  }

  String _generateJSON() {
    final data = {
      'filename': widget.result.filename,
      'engine': widget.result.primaryResult.engine,
      'confidence': widget.result.primaryResult.confidence,
      'processing_time': widget.result.totalProcessingTime,
      'timestamp': widget.result.primaryResult.timestamp.toIso8601String(),
      'text': widget.result.primaryResult.rawText,
      'blocks': widget.result.primaryResult.blocks.map((block) => {
        'text': block.text,
        'lines': block.lines,
      }).toList(),
    };

    if (widget.result.tesseractResult != null) {
      data['tesseract_result'] = {
        'engine': widget.result.tesseractResult!.engine,
        'confidence': widget.result.tesseractResult!.confidence,
        'text': widget.result.tesseractResult!.rawText,
      };
    }

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  String _generateSQL() {
    final text = widget.result.primaryResult.rawText.replaceAll("'", "''"); // Escape quotes
    final filename = widget.result.filename.replaceAll("'", "''");
    final timestamp = widget.result.primaryResult.timestamp.toIso8601String();

    return '''INSERT INTO ocr_results (
  filename,
  engine,
  confidence,
  raw_text,
  timestamp,
  processing_time
) VALUES (
  '$filename',
  '${widget.result.primaryResult.engine}',
  ${widget.result.primaryResult.confidence},
  '$text',
  '$timestamp',
  ${widget.result.totalProcessingTime}
);''';
  }

  Widget _buildMetadataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metadata',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMetadataRow('File', widget.result.filename),
            _buildMetadataRow('Engine', widget.result.primaryResult.engine.toUpperCase()),
            _buildMetadataRow(
              'Confidence',
              '${(widget.result.primaryResult.confidence * 100).toStringAsFixed(1)}%',
            ),
            _buildMetadataRow(
              'Processing Time',
              '${widget.result.totalProcessingTime.toStringAsFixed(1)}s',
            ),
            _buildMetadataRow(
              'Blocks',
              '${widget.result.primaryResult.blocks.length}',
            ),
            if (widget.result.tesseractResult != null)
              _buildMetadataRow(
                'Tesseract Blocks',
                '${widget.result.tesseractResult!.blocks.length}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard(String title, String content, String language) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(language.toUpperCase()),
                  backgroundColor: Colors.blue[100],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                content,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard(String title, OCRResult ocrResult) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(
                    '${(ocrResult.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _getConfidenceColor(ocrResult.confidence),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                ocrResult.rawText.isNotEmpty
                    ? ocrResult.rawText
                    : 'No text detected',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.85) return Colors.green[100]!;
    if (confidence >= 0.70) return Colors.orange[100]!;
    return Colors.red[100]!;
  }
}

