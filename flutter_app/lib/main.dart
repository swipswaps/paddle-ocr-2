import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/home_screen.dart';
import 'services/ocr_service.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for desktop platforms
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize database
  final databaseService = DatabaseService();
  await databaseService.initialize();

  // Configure backend URL
  // Desktop: Required for OCR (Tesseract + PaddleOCR via backend)
  // Mobile: Optional (uses ML Kit + Tesseract locally, backend for PaddleOCR fallback)
  final backendUrl = Platform.isLinux || Platform.isWindows || Platform.isMacOS
      ? 'http://localhost:5001'  // Desktop: localhost
      : null;  // Mobile: configure if needed (e.g., 'http://192.168.1.135:5001')

  runApp(MyApp(
    databaseService: databaseService,
    backendUrl: backendUrl,
  ));
}

class MyApp extends StatelessWidget {
  final DatabaseService databaseService;
  final String? backendUrl;

  const MyApp({
    super.key,
    required this.databaseService,
    this.backendUrl,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hybrid OCR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: HomeScreen(
        databaseService: databaseService,
        backendUrl: backendUrl,
      ),
    );
  }
}

