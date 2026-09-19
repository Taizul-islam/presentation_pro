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

    try {
      if (slideDir.existsSync()) {
        slideDir.deleteSync(recursive: true);
      }
      slideDir.createSync(recursive: true);

      onProgress?.call(0.1);

      final libreOfficePath = await _findLibreOffice();
      final pdftoppmPath = await _findPdfToPpm();

      if (libreOfficePath == null) {
        throw Exception('LibreOffice not found. Please reinstall the application.');
      }
      if (pdftoppmPath == null) {
        throw Exception('Poppler not found. Please reinstall the application.');
      }

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

      final images = await _convertPdfToImagesWithPoppler(
        pdfPath,
        slideDir,
        pdftoppmPath,
        onProgress,
      );

      final pdfFile = File(pdfPath);
      if (pdfFile.existsSync()) {
        pdfFile.deleteSync();
      }

      onProgress?.call(1.0);
      return images;
    } catch (e) {
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
    final result = await Process.run(
      libreOfficePath,
      [
        '--headless',
        '--convert-to', 'pdf',
        '--outdir', outputDir.path,
        pptxPath,
      ],
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr?.toString() ?? '';
      throw Exception('PPTX to PDF conversion failed. Exit code: ${result.exitCode}\n$stderr');
    }

    onProgress?.call(0.4);
    await Future.delayed(Duration(seconds: 2));

    final pdfFiles = outputDir.listSync()
        .where((f) => f.path.endsWith('.pdf'))
        .toList();

    if (pdfFiles.isEmpty) {
      throw Exception('No PDF file generated');
    }

    return pdfFiles.first.path;
  }

  /// Converts PDF to JPEG images at 100 DPI.
  /// JPEG at 100 DPI is 5-10x smaller than PNG at 150 DPI while still
  /// looking sharp on any screen.
  static Future<List<String>> _convertPdfToImagesWithPoppler(
      String pdfPath,
      Directory outputDir,
      String pdftoppmPath,
      void Function(double)? onProgress,
      ) async {
    final prefix = '${outputDir.path}/slide';

    // CHANGED: -jpeg instead of -png, 100 DPI instead of 150 DPI
    final result = await Process.run(
      pdftoppmPath,
      ['-jpeg', '-r', '100', pdfPath, prefix],
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr?.toString() ?? '';
      throw Exception('pdftoppm conversion failed. Exit code: ${result.exitCode}\n$stderr');
    }

    onProgress?.call(0.7);
    await Future.delayed(Duration(milliseconds: 500));

    final jpegFiles = outputDir.listSync()
        .where((f) => f.path.endsWith('.jpg') && f.path.contains('slide'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (jpegFiles.isEmpty) {
      throw Exception('No JPEG files generated');
    }

    final images = <String>[];
    for (int i = 0; i < jpegFiles.length; i++) {
      final newPath = '${outputDir.path}/slide_${i + 1}.jpg';
      if (jpegFiles[i].path != newPath) {
        try {
          File(jpegFiles[i].path).renameSync(newPath);
        } catch (e) {
          File(jpegFiles[i].path).copySync(newPath);
        }
      }
      images.add(newPath);

      // Report progress periodically
      if (i % 10 == 0) {
        onProgress?.call(0.7 + (0.2 * i / jpegFiles.length));
      }
    }

    onProgress?.call(0.9);
    return images;
  }

  static Future<String?> _findLibreOffice() async {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent;

    final paths = [
      '${executableDir.path}/tools/libreoffice/program/soffice.exe',
      '${executableDir.path}/tools/LibreOffice/program/soffice.exe',
      '${executableDir.path}/tools/libreoffice/App/libreoffice/program/soffice.exe',
      '${executableDir.path}/tools/LibreOfficePortable/App/libreoffice/program/soffice.exe',
      r'C:\Program Files\LibreOffice\program\soffice.exe',
      r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
      '/opt/homebrew/bin/soffice',
      '/Applications/LibreOffice.app/Contents/MacOS/soffice',
      '/usr/local/bin/soffice',
      '/usr/bin/soffice',
    ];

    for (final path in paths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    try {
      final toolsDir = Directory('${executableDir.path}/tools');
      if (toolsDir.existsSync()) {
        final files = toolsDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File && file.path.toLowerCase().endsWith('soffice.exe')) {
            return file.path;
          }
        }
      }
    } catch (e) {
      // Continue
    }

    try {
      final result = await Process.run('which', ['soffice']);
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      // Continue
    }

    if (Platform.isWindows) {
      try {
        final result = await Process.run('where', ['soffice']);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          return result.stdout.toString().trim().split('\n').first;
        }
      } catch (e) {
        // Continue
      }
    }

    return null;
  }

  static Future<String?> _findPdfToPpm() async {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent;

    final knownPaths = [
      '${executableDir.path}/tools/poppler/pdftoppm.exe',
      '${executableDir.path}/tools/poppler/bin/pdftoppm.exe',
      '${executableDir.path}/tools/poppler/Library/bin/pdftoppm.exe',
      r'C:\Program Files\poppler\bin\pdftoppm.exe',
      r'C:\Program Files (x86)\poppler\bin\pdftoppm.exe',
      '/opt/homebrew/bin/pdftoppm',
      '/usr/local/bin/pdftoppm',
      '/usr/bin/pdftoppm',
    ];

    for (final path in knownPaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    try {
      final toolsDir = Directory('${executableDir.path}/tools');
      if (toolsDir.existsSync()) {
        final files = toolsDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File && file.path.toLowerCase().endsWith('pdftoppm.exe')) {
            return file.path;
          }
        }
      }
    } catch (e) {
      // Continue
    }

    try {
      final result = await Process.run('which', ['pdftoppm']);
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      // Continue
    }

    if (Platform.isWindows) {
      try {
        final result = await Process.run('where', ['pdftoppm']);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          return result.stdout.toString().trim().split('\n').first;
        }
      } catch (e) {
        // Continue
      }
    }

    return null;
  }

  static Future<void> preloadPptx(String pptxPath) async {
    await convertPptxToImages(pptxPath);
  }

  static void clearAllCaches() {
    final tempDir = Directory.systemTemp;
    final cacheDir = Directory('${tempDir.path}/pptx_cache');
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  }
}