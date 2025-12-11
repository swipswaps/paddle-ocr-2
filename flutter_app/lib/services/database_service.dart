import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ocr_result.dart';

/// Local SQLite database for offline-first storage
class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hybrid_ocr.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ocr_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT NOT NULL,
        engine TEXT NOT NULL,
        confidence REAL NOT NULL,
        raw_text TEXT NOT NULL,
        blocks TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        processing_time REAL NOT NULL,
        tesseract_result TEXT
      )
    ''');
  }

  Future<void> initialize() async {
    await database;
  }

  /// Save OCR result to database
  Future<int> saveResult(HybridOCRResult result) async {
    final db = await database;
    
    return await db.insert('ocr_results', {
      'filename': result.filename,
      'engine': result.primaryResult.engine,
      'confidence': result.primaryResult.confidence,
      'raw_text': result.primaryResult.rawText,
      'blocks': _encodeBlocks(result.primaryResult.blocks),
      'timestamp': result.primaryResult.timestamp.toIso8601String(),
      'processing_time': result.totalProcessingTime,
      'tesseract_result': result.tesseractResult != null
          ? _encodeOCRResult(result.tesseractResult!)
          : null,
    });
  }

  /// Get all OCR results
  Future<List<Map<String, dynamic>>> getAllResults() async {
    final db = await database;
    return await db.query(
      'ocr_results',
      orderBy: 'timestamp DESC',
    );
  }

  /// Get result by ID
  Future<Map<String, dynamic>?> getResultById(int id) async {
    final db = await database;
    final results = await db.query(
      'ocr_results',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Delete result by ID
  Future<int> deleteResult(int id) async {
    final db = await database;
    return await db.delete(
      'ocr_results',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Search results by text
  Future<List<Map<String, dynamic>>> searchResults(String query) async {
    final db = await database;
    return await db.query(
      'ocr_results',
      where: 'raw_text LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
    );
  }

  String _encodeBlocks(List<OCRTextBlock> blocks) {
    return blocks.map((b) => b.toJson()).toList().toString();
  }

  String _encodeOCRResult(OCRResult result) {
    return result.toJson().toString();
  }
}

