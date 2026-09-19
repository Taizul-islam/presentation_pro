import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:printing/printing.dart';

import '../models/drawing_stroke.dart';

class ExportService {
  static Future<void> printPages(
      List<PresentationPage> pages, {
        Function(int current, int total)? onProgress,
      }) async {
    try {
      final pdf = pw.Document();
      final Map<String, pdfrx.PdfDocument> docCache = {};

      final double slideRatio = pages.isNotEmpty
          ? (pages[0].aspectRatio ?? 16 / 9)
          : 16 / 9;

      for (int i = 0; i < pages.length; i++) {
        onProgress?.call(i + 1, pages.length);
        final page = pages[i];
        final imageBytes = await _renderPageToImage(
          page,
          docCache: docCache,
          forcedRatio: slideRatio,
        );

        if (imageBytes != null) {
          const double pageWidth = 1280.0;
          final double pageHeight = pageWidth / slideRatio;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(pageWidth, pageHeight),
              margin: const pw.EdgeInsets.all(0),
              build: (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  fit: pw.BoxFit.fill,
                ),
              ),
            ),
          );
        }
      }

      for (final doc in docCache.values) {
        await doc.dispose();
      }

      final Uint8List pdfBytes = await pdf.save();
      await Future.delayed(const Duration(milliseconds: 500));

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Presentation',
        dynamicLayout: false,
      );
    } catch (e) {
      debugPrint('Error in printPages: $e');
    }
  }

  static Future<String?> exportAsPdf(
      List<PresentationPage> pages,
      String fileName, {
        Function(int current, int total)? onProgress,
      }) async {
    try {
      final outputPath = await _getSavePath('$fileName.pdf');
      if (outputPath == null) return null;

      final pdf = pw.Document();
      final Map<String, pdfrx.PdfDocument> docCache = {};

      final double slideRatio = pages.isNotEmpty
          ? (pages[0].aspectRatio ?? 16 / 9)
          : 16 / 9;

      for (int i = 0; i < pages.length; i++) {
        onProgress?.call(i + 1, pages.length);
        final page = pages[i];

        final imageBytes = await _renderPageToImage(
          page,
          docCache: docCache,
          forcedRatio: slideRatio,
        );

        if (imageBytes != null) {
          const double pageWidth = 1280.0;
          final double pageHeight = pageWidth / slideRatio;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(pageWidth, pageHeight),
              margin: const pw.EdgeInsets.all(0),
              build: (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  fit: pw.BoxFit.fill,
                ),
              ),
            ),
          );
        }
      }

      for (final doc in docCache.values) {
        await doc.dispose();
      }

      final bytes = await pdf.save();
      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('File save failed. The path may be invalid or too long.');
      }

      return outputPath;
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      return null;
    }
  }

  static Future<String?> _getSavePath(String fileName) async {
    try {
      final safeFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Presentation As',
        fileName: safeFileName,
        type: FileType.custom,
        allowedExtensions: [safeFileName.split('.').last],
      );

      if (result != null) {
        try {
          final testFile = File(result);
          await testFile.writeAsBytes([0]);
          await testFile.delete();
          return result;
        } catch (writeError) {
          debugPrint('DEBUG: Path is not writable: $writeError');
        }
      }
    } catch (e) {
      debugPrint('DEBUG: File picker failed: $e');
    }

    try {
      final tempDir = Directory.systemTemp;
      final shortPath =
          '${tempDir.path}${Platform.pathSeparator}Export_${DateTime.now().millisecondsSinceEpoch}.${fileName.split('.').last}';
      return shortPath;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _renderPageToImage(
      PresentationPage page, {
        Map<String, pdfrx.PdfDocument>? docCache,
        double? forcedRatio,
      }) async {
    try {
      // 1600px is the balance point:
      // - Sharp on 1080p and 1440p displays
      // - Acceptable on 4K displays (only visible difference at 400%+ zoom)
      // - 3-4x smaller than 2400px PNG
      const double targetWidth = 1600.0;
      final double ratio = forcedRatio ?? page.aspectRatio ?? 16 / 9;
      final double targetHeight = targetWidth / ratio;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final bgColor = page.backgroundColor ?? Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, targetWidth, targetHeight),
        Paint()..color = bgColor,
      );

      if (page.contentPath != null && page.contentPath!.isNotEmpty) {
        ui.Image? bgImage;

        if (page.contentType == PageContentType.pdf &&
            page.pdfPageIndex != null) {
          pdfrx.PdfDocument? doc;
          if (docCache != null && docCache.containsKey(page.contentPath)) {
            doc = docCache[page.contentPath];
          } else {
            doc = await pdfrx.PdfDocument.openFile(page.contentPath!);
            docCache?[page.contentPath!] = doc;
          }

          if (doc != null) {
            final pdfPage = doc.pages[page.pdfPageIndex!];
            final pdfImage = await pdfPage.render(
              fullWidth: targetWidth,
              fullHeight: targetHeight,
            );
            if (pdfImage != null) {
              bgImage = await pdfImage.createImage();
            }
          }
        } else {
          final file = File(page.contentPath!);
          if (file.existsSync()) {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            bgImage = frame.image;
          }
        }

        if (bgImage != null) {
          final double bgW = bgImage.width.toDouble();
          final double bgH = bgImage.height.toDouble();
          final double bgRatio = bgW / bgH;

          double srcX = 0, srcY = 0, srcW = bgW, srcH = bgH;
          if (bgRatio > ratio) {
            srcW = bgH * ratio;
            srcX = (bgW - srcW) / 2;
          } else if (bgRatio < ratio) {
            srcH = bgW / ratio;
            srcY = (bgH - srcH) / 2;
          }

          canvas.drawImageRect(
            bgImage,
            Rect.fromLTWH(srcX, srcY, srcW, srcH),
            Rect.fromLTWH(0, 0, targetWidth, targetHeight),
            Paint()..filterQuality = ui.FilterQuality.high,
          );
          bgImage.dispose();
        }
      }

      final double scaleFactor = targetWidth / 1920.0;

      for (final stroke in page.strokes) {
        if (stroke.points.length < 2) continue;

        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width * scaleFactor
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;

        if (stroke.tool == DrawingTool.eraser) {
          paint.blendMode = ui.BlendMode.clear;
        }

        if (stroke.tool == DrawingTool.highlighter) {
          paint.color = stroke.color.withOpacity(0.3);
          paint.strokeWidth *= 3;
        }

        final path = Path();
        path.moveTo(
          stroke.points[0].dx * targetWidth,
          stroke.points[0].dy * targetHeight,
        );
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(
            stroke.points[i].dx * targetWidth,
            stroke.points[i].dy * targetHeight,
          );
        }
        canvas.drawPath(path, paint);
      }

      for (final textElement in page.texts) {
        if (textElement.text.trim().isEmpty) continue;

        final textStyle = _getRenderTextStyle(textElement);
        final textSpan = TextSpan(
          text: textElement.text,
          style: textStyle.copyWith(
            fontSize: textElement.fontSize * scaleFactor,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textAlign: textElement.alignment,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(maxWidth: (textElement.width * scaleFactor) + 20);
        textPainter.paint(
          canvas,
          Offset(
            textElement.position.dx * targetWidth,
            textElement.position.dy * targetHeight,
          ),
        );
      }

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        targetWidth.toInt(),
        targetHeight.toInt(),
      );

      final byteData = await finalImage
          .toByteData(format: ui.ImageByteFormat.png)
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () => null,
      );

      finalImage.dispose();

      if (byteData == null) {
        debugPrint('CRITICAL: ByteData was null. Likely OOM or timeout.');
        return null;
      }

      // Convert PNG to JPEG at quality 92.
      // At this quality, the difference from PNG is invisible to the eye
      // for slide content, but the file is 6-8x smaller.
      try {
        final pngBytes = byteData.buffer.asUint8List();
        final decoded = img.decodePng(pngBytes);
        if (decoded != null) {
          final jpegBytes = img.encodeJpg(decoded, quality: 92);
          return Uint8List.fromList(jpegBytes);
        }
      } catch (e) {
        debugPrint('JPEG conversion failed, falling back to PNG: $e');
      }

      return Uint8List.fromList(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error in _renderPageToImage: $e');
      return null;
    }
  }

  static TextStyle _getRenderTextStyle(DrawingText element) {
    try {
      return GoogleFonts.getFont(
        element.fontFamily,
        color: element.color,
        fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: element.isUnderlined
            ? TextDecoration.underline
            : TextDecoration.none,
      );
    } catch (e) {
      return TextStyle(
        color: element.color,
        fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: element.isUnderlined
            ? TextDecoration.underline
            : TextDecoration.none,
      );
    }
  }
}