import 'dart:io';
import 'dart:math' as math;
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

      // Save an isolated layer for strokes & duster masks so BlendMode.clear never burns holes through background PDF/image
      canvas.saveLayer(Rect.fromLTWH(0, 0, targetWidth, targetHeight), Paint());

      for (final stroke in page.strokes) {
        if (stroke.points.length < 2) continue;

        if (stroke.tool == DrawingTool.shape || stroke.shapeType != null) {
          _drawShapeExport(canvas, stroke, targetWidth, targetHeight);
          continue;
        }

        if (stroke.tool == DrawingTool.eraser &&
            (stroke.dusterType == DusterType.feltBlock || stroke.dusterType == DusterType.sponge)) {
          _drawDirectionalBlockEraserExport(canvas, stroke, targetWidth, targetHeight);
          continue;
        }

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

        final path = Path()
          ..moveTo(
            stroke.points[0].dx * targetWidth,
            stroke.points[0].dy * targetHeight,
          );

        if (stroke.points.length == 2) {
          path.lineTo(
            stroke.points[1].dx * targetWidth,
            stroke.points[1].dy * targetHeight,
          );
        } else {
          for (int i = 1; i < stroke.points.length - 1; i++) {
            final midPoint = Offset(
              ((stroke.points[i].dx + stroke.points[i + 1].dx) / 2) * targetWidth,
              ((stroke.points[i].dy + stroke.points[i + 1].dy) / 2) * targetHeight,
            );
            path.quadraticBezierTo(
              stroke.points[i].dx * targetWidth,
              stroke.points[i].dy * targetHeight,
              midPoint.dx,
              midPoint.dy,
            );
          }
          path.lineTo(
            stroke.points.last.dx * targetWidth,
            stroke.points.last.dy * targetHeight,
          );
        }

        canvas.drawPath(path, paint);
      }

      canvas.restore();

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

  static void _drawDirectionalBlockEraserExport(
      Canvas canvas, DrawingStroke stroke, double targetWidth, double targetHeight) {
    final double scaleFactor = targetWidth / 1920.0;
    final double baseWidth = stroke.width * scaleFactor;

    final double blockW = (stroke.dusterType == DusterType.feltBlock) ? baseWidth * 1.8 : baseWidth * 1.5;
    final double blockH = (stroke.dusterType == DusterType.feltBlock) ? baseWidth * 0.9 : baseWidth * 1.0;
    final paint = Paint()
      ..blendMode = ui.BlendMode.clear
      ..style = PaintingStyle.fill;

    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p1 = Offset(stroke.points[i].dx * targetWidth, stroke.points[i].dy * targetHeight);
      final p2 = Offset(stroke.points[i + 1].dx * targetWidth, stroke.points[i + 1].dy * targetHeight);
      final delta = p2 - p1;
      final dist = delta.distance;
      if (dist < 0.1) continue;

      final angle = math.atan2(delta.dy, delta.dx);
      final step = math.max(2.0, blockH * 0.25);
      final steps = (dist / step).ceil();

      for (int s = 0; s <= steps; s++) {
        final t = s / steps;
        final pos = Offset.lerp(p1, p2, t)!;

        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle);
        final rect = Rect.fromCenter(center: Offset.zero, width: blockW, height: blockH);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(stroke.dusterType == DusterType.feltBlock ? 4 : 10)),
          paint,
        );
        canvas.restore();
      }
    }
  }

  static void _drawShapeExport(Canvas canvas, DrawingStroke stroke, double targetWidth, double targetHeight) {
    if (stroke.points.length < 2) return;
    final p1 = Offset(stroke.points.first.dx * targetWidth, stroke.points.first.dy * targetHeight);
    final p2 = Offset(stroke.points.last.dx * targetWidth, stroke.points.last.dy * targetHeight);
    final rect = Rect.fromPoints(p1, p2);

    final double scaleFactor = targetWidth / 1920.0;
    final strokePaint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width * scaleFactor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    Paint? fillPaint;
    if (stroke.fillColor != null && stroke.fillColor != Colors.transparent) {
      fillPaint = Paint()
        ..color = stroke.fillColor!
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
    }

    final shape = stroke.shapeType ?? ShapeType.rectangle;

    switch (shape) {
      case ShapeType.rectangle:
        if (fillPaint != null) canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);
        break;

      case ShapeType.circle:
        if (fillPaint != null) canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);
        break;

      case ShapeType.triangle:
        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        if (fillPaint != null) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case ShapeType.diamond:
        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..lineTo(rect.left, rect.center.dy)
          ..close();
        if (fillPaint != null) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case ShapeType.star:
        final path = _createStarPathExport(rect);
        if (fillPaint != null) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case ShapeType.line:
        canvas.drawLine(p1, p2, strokePaint);
        break;

      case ShapeType.arrow:
        _drawArrowLineExport(canvas, p1, p2, strokePaint);
        break;

      case ShapeType.coordinateAxes:
        _drawCoordinateAxesExport(canvas, rect, strokePaint);
        break;

      case ShapeType.cube:
        _draw3DCubeExport(canvas, rect, strokePaint, fillPaint);
        break;
    }
  }

  static Path _createStarPathExport(Rect rect) {
    final path = Path();
    const points = 5;
    const double rawRx = 1.0;
    const double rawRy = 1.0;
    const double innerRx = rawRx * 0.4;
    const double innerRy = rawRy * 0.4;

    final List<Offset> rawPoints = [];
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - (math.pi / 2);
      final rX = i.isEven ? rawRx : innerRx;
      final rY = i.isEven ? rawRy : innerRy;
      rawPoints.add(Offset(rX * math.cos(angle), rY * math.sin(angle)));
    }

    double minX = rawPoints[0].dx;
    double maxX = rawPoints[0].dx;
    double minY = rawPoints[0].dy;
    double maxY = rawPoints[0].dy;

    for (final p in rawPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final double rawWidth = maxX - minX;
    final double rawHeight = maxY - minY;

    for (int i = 0; i < rawPoints.length; i++) {
      final p = rawPoints[i];
      final nx = rect.left + ((p.dx - minX) / rawWidth) * rect.width;
      final ny = rect.top + ((p.dy - minY) / rawHeight) * rect.height;
      if (i == 0) {
        path.moveTo(nx, ny);
      } else {
        path.lineTo(nx, ny);
      }
    }

    path.close();
    return path;
  }

  static void _drawArrowLineExport(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dist = (p2 - p1).distance;
    if (dist < 1.0) return;

    final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    final arrowLength = math.max(12.0, math.min(dist * 0.4, paint.strokeWidth * 3.8));
    const arrowAngle = math.pi / 7.0;

    final lineEnd = Offset(
      p2.dx - (arrowLength * 0.6) * math.cos(angle),
      p2.dy - (arrowLength * 0.6) * math.sin(angle),
    );
    canvas.drawLine(p1, lineEnd, paint);

    final arrowPath = Path()
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(
        p2.dx - arrowLength * math.cos(angle - arrowAngle),
        p2.dy - arrowLength * math.sin(angle - arrowAngle),
      )
      ..lineTo(
        p2.dx - (arrowLength * 0.75) * math.cos(angle),
        p2.dy - (arrowLength * 0.75) * math.sin(angle),
      )
      ..lineTo(
        p2.dx - arrowLength * math.cos(angle + arrowAngle),
        p2.dy - arrowLength * math.sin(angle + arrowAngle),
      )
      ..close();

    final fillHead = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(arrowPath, fillHead);
  }

  static void _drawCoordinateAxesExport(Canvas canvas, Rect rect, Paint paint) {
    final origin = Offset(rect.left, rect.bottom);
    _drawArrowLineExport(canvas, origin, Offset(rect.right, origin.dy), paint);
    _drawArrowLineExport(canvas, origin, Offset(origin.dx, rect.top), paint);
  }

  static void _draw3DCubeExport(Canvas canvas, Rect rect, Paint strokePaint, Paint? fillPaint) {
    final d = rect.width.abs() * 0.25;
    final front = Rect.fromLTWH(rect.left, rect.top + d, rect.width.abs() - d, rect.height.abs() - d);
    final back = Rect.fromLTWH(rect.left + d, rect.top, rect.width.abs() - d, rect.height.abs() - d);

    if (fillPaint != null) {
      canvas.drawRect(front, fillPaint);
      canvas.drawRect(back, fillPaint);
    }

    canvas.drawRect(front, strokePaint);
    canvas.drawRect(back, strokePaint);

    canvas.drawLine(front.topLeft, back.topLeft, strokePaint);
    canvas.drawLine(front.topRight, back.topRight, strokePaint);
    canvas.drawLine(front.bottomLeft, back.bottomLeft, strokePaint);
    canvas.drawLine(front.bottomRight, back.bottomRight, strokePaint);
  }
}