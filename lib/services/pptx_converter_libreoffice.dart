import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PptxConverterLibreOffice {
  static Future<List<String>> convertPptxToImages(
      String pptxPath, {
        void Function(double progress)? onProgress,
        bool forceRefresh = false,
      }) async {
    final tempDir = Directory.systemTemp;
    final outputDir = Directory('${tempDir.path}/pptx_cache');

    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final fileHash = _generateHash(pptxPath);
    final slideDir = Directory('${outputDir.path}/$fileHash');

    onProgress?.call(0.05);

    print('🔄 Starting fresh conversion (cache disabled)...');

    try {
      // Clean old cache
      if (slideDir.existsSync()) {
        print('🗑️ Deleting old cache...');
        slideDir.deleteSync(recursive: true);
      }
      slideDir.createSync(recursive: true);

      onProgress?.call(0.1);

      // Find bundled tools
      final libreOfficePath = await _findLibreOffice();
      final pdftoppmPath = await _findPdfToPpm();

      if (libreOfficePath == null) {
        throw Exception('LibreOffice not found. Please reinstall the application.');
      }

      if (pdftoppmPath == null) {
        throw Exception('Poppler not found. Please reinstall the application.');
      }

      print('🔧 Tools found:');
      print('   LibreOffice: $libreOfficePath');
      print('   pdftoppm: $pdftoppmPath');

      // Step 1: Convert PPTX to PDF
      onProgress?.call(0.2);
      final pdfPath = await _convertPptxToPdf(
        pptxPath,
        slideDir,
        libreOfficePath,
        onProgress,
      );

      if (pdfPath == null) {
        throw Exception('Failed to convert PPTX to PDF');
      }

      onProgress?.call(0.5);

      // Step 2: Convert PDF to PNG using pdftoppm
      final images = await _convertPdfToImagesWithPoppler(
        pdfPath,
        slideDir,
        pdftoppmPath,
        onProgress,
      );

      // Clean up PDF
      final pdfFile = File(pdfPath);
      if (pdfFile.existsSync()) {
        pdfFile.deleteSync();
        print('🗑️ Deleted temporary PDF');
      }

      onProgress?.call(1.0);

      print('✅ Successfully converted ${images.length} slides');
      return images;
    } catch (e) {
      print('❌ Conversion failed: $e');
      onProgress?.call(1.0);
      rethrow;
    }
  }

  static String _generateHash(String path) {
    final bytes = utf8.encode(path);
    int hash = 0;
    for (int byte in bytes) {
      hash = ((hash << 5) - hash) + byte;
      hash = hash & hash;
    }
    return hash.abs().toRadixString(16);
  }

  static Future<String?> _convertPptxToPdf(
      String pptxPath,
      Directory outputDir,
      String libreOfficePath,
      void Function(double)? onProgress,
      ) async {
    print('📄 Converting PPTX to PDF...');
    print('   Input: $pptxPath');
    print('   Output: ${outputDir.path}');

    // Use Process.run for better completion detection
    final result = await Process.run(
      libreOfficePath,
      [
        '--headless',
        '--convert-to', 'pdf',
        '--outdir', outputDir.path,
        pptxPath,
      ],
    );

    print('   Exit code: ${result.exitCode}');

    if (result.exitCode != 0) {
      final stderr = result.stderr?.toString() ?? '';
      throw Exception('PPTX to PDF conversion failed. Exit code: ${result.exitCode}\n$stderr');
    }

    onProgress?.call(0.4);

    // Wait for PDF to be fully written
    await Future.delayed(Duration(seconds: 2));

    final pdfFiles = outputDir.listSync()
        .where((f) => f.path.endsWith('.pdf'))
        .toList();

    if (pdfFiles.isEmpty) {
      throw Exception('No PDF file generated');
    }

    print('   PDF created: ${pdfFiles.first.path}');
    return pdfFiles.first.path;
  }

  static Future<List<String>> _convertPdfToImagesWithPoppler(
      String pdfPath,
      Directory outputDir,
      String pdftoppmPath,
      void Function(double)? onProgress,
      ) async {
    try {
      print('🖼️ Converting PDF to PNG...');
      print('   Using pdftoppm: $pdftoppmPath');

      final prefix = '${outputDir.path}/slide';

      final result = await Process.run(
        pdftoppmPath,
        [
          '-png',
          '-r', '150',
          pdfPath,
          prefix,
        ],
      );

      print('   Exit code: ${result.exitCode}');

      if (result.exitCode != 0) {
        final stderr = result.stderr?.toString() ?? '';
        throw Exception('pdftoppm conversion failed. Exit code: ${result.exitCode}\n$stderr');
      }

      onProgress?.call(0.7);

      // Wait for files to be written
      await Future.delayed(Duration(milliseconds: 500));

      final pngFiles = outputDir.listSync()
          .where((f) => f.path.endsWith('.png') && f.path.contains('slide'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      print('   Found ${pngFiles.length} PNG files');

      if (pngFiles.isEmpty) {
        throw Exception('No PNG files generated');
      }

      final images = <String>[];
      for (int i = 0; i < pngFiles.length; i++) {
        final newPath = '${outputDir.path}/slide_${i + 1}.png';

        if (pngFiles[i].path != newPath) {
          try {
            File(pngFiles[i].path).renameSync(newPath);
          } catch (e) {
            print('   Error renaming, trying copy: $e');
            File(pngFiles[i].path).copySync(newPath);
          }
        }

        images.add(newPath);
      }

      onProgress?.call(0.9);

      print('   Created ${images.length} images');
      return images;
    } catch (e) {
      print('❌ PDF to image conversion failed: $e');
      rethrow;
    }
  }

  static Future<String?> _findLibreOffice() async {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent;

    print('🔍 Searching for LibreOffice...');

    final bundledPaths = [
      // Windows - bundled
      '${executableDir.path}/tools/libreoffice/program/soffice.exe',
      '${executableDir.path}/tools/LibreOffice/program/soffice.exe',
      // Windows - system
      r'C:\Program Files\LibreOffice\program\soffice.exe',
      r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
      // macOS - development
      '/opt/homebrew/bin/soffice',
      '/Applications/LibreOffice.app/Contents/MacOS/soffice',
      '/usr/local/bin/soffice',
      '/usr/bin/soffice',
    ];

    for (final path in bundledPaths) {
      if (File(path).existsSync()) {
        print('✅ Found LibreOffice at: $path');
        return path;
      }
    }

    // Search recursively in tools directory
    try {
      final toolsDir = Directory('${executableDir.path}/tools');
      if (toolsDir.existsSync()) {
        final files = toolsDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File && file.path.toLowerCase().endsWith('soffice.exe')) {
            print('✅ Found LibreOffice recursively at: ${file.path}');
            return file.path;
          }
        }
      }
    } catch (e) {
      print('Error searching: $e');
    }

    // Try which command (macOS/Linux)
    try {
      final result = await Process.run('which', ['soffice']);
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final path = result.stdout.toString().trim();
        print('✅ Found soffice via which: $path');
        return path;
      }
    } catch (e) {
      // Continue
    }

    // Try where command (Windows)
    if (Platform.isWindows) {
      try {
        final result = await Process.run('where', ['soffice']);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          final path = result.stdout.toString().trim().split('\n').first;
          print('✅ Found soffice via where: $path');
          return path;
        }
      } catch (e) {
        // Continue
      }
    }

    print('⚠️ LibreOffice not found');
    return null;
  }

  static Future<String?> _findPdfToPpm() async {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent;

    print('🔍 Searching for pdftoppm...');

    final knownPaths = [
      // Windows - bundled
      '${executableDir.path}/tools/poppler/pdftoppm.exe',
      '${executableDir.path}/tools/poppler/bin/pdftoppm.exe',
      '${executableDir.path}/tools/poppler/Library/bin/pdftoppm.exe',
      // Windows - system
      r'C:\Program Files\poppler\bin\pdftoppm.exe',
      r'C:\Program Files (x86)\poppler\bin\pdftoppm.exe',
      // macOS - development
      '/opt/homebrew/bin/pdftoppm',
      '/usr/local/bin/pdftoppm',
      '/usr/bin/pdftoppm',
    ];

    for (final path in knownPaths) {
      if (File(path).existsSync()) {
        print('✅ Found pdftoppm at: $path');
        return path;
      }
    }

    // Search recursively in tools directory
    try {
      final toolsDir = Directory('${executableDir.path}/tools');
      if (toolsDir.existsSync()) {
        final files = toolsDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File && file.path.toLowerCase().endsWith('pdftoppm.exe')) {
            print('✅ Found pdftoppm recursively at: ${file.path}');
            return file.path;
          }
        }
      }
    } catch (e) {
      print('Error searching: $e');
    }

    // Try which command (macOS/Linux)
    try {
      final result = await Process.run('which', ['pdftoppm']);
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final path = result.stdout.toString().trim();
        print('✅ Found pdftoppm via which: $path');
        return path;
      }
    } catch (e) {
      // Continue
    }

    // Try where command (Windows)
    if (Platform.isWindows) {
      try {
        final result = await Process.run('where', ['pdftoppm']);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          final path = result.stdout.toString().trim().split('\n').first;
          print('✅ Found pdftoppm via where: $path');
          return path;
        }
      } catch (e) {
        // Continue
      }
    }

    print('⚠️ pdftoppm not found');
    return null;
  }

  static Future<void> preloadPptx(String pptxPath) async {
    print('🔄 Preloading PPTX...');
    await convertPptxToImages(pptxPath);
    print('✅ PPTX preloaded');
  }

  static void clearAllCaches() {
    final tempDir = Directory.systemTemp;
    final cacheDir = Directory('${tempDir.path}/pptx_cache');
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
      print('🗑️ Cleared all caches');
    }
  }
}