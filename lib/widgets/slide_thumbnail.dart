import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/drawing_stroke.dart';

class SlideThumbnail extends StatelessWidget {
  final PresentationPage page;
  final DrawingStroke? currentStroke;
  final bool isSelected;
  final VoidCallback onTap;
  final PdfDocument? pdfDocument;

  const SlideThumbnail({
    Key? key,
    required this.page,
    this.currentStroke,
    required this.isSelected,
    required this.onTap,
    this.pdfDocument,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        child: AspectRatio(
          aspectRatio: page.aspectRatio ?? (16 / 9),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? Colors.indigo : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : [
                      const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: _buildThumbnailPreview(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPreview(BuildContext context) {
    final hasContent = page.strokes.isNotEmpty ||
        page.texts.isNotEmpty ||
        currentStroke != null;
    return Stack(
      children: [
        Positioned.fill(child: _buildBackground(context, hasContent)),
        Positioned.fill(
          child: CustomPaint(
            painter: _ThumbnailPainter(
              strokes: page.strokes,
              currentStroke: currentStroke,
              texts: page.texts,
            ),
          ),
        ),
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.indigo
                  : Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${page.pageNumber}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(BuildContext context, bool hasContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = (page.backgroundColor != null && page.backgroundColor != Colors.white)
        ? page.backgroundColor!
        : (isDark ? const Color(0xFF181825) : Colors.white);

    // Blank slide
    if (page.contentPath == null || page.contentPath!.isEmpty) {
      if (hasContent) return Container(color: bgColor);

      return Container(
        color: bgColor,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.gesture,
                  size: 24,
                  color: bgColor.computeLuminance() > 0.5
                      ? Colors.grey.shade300
                      : Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Blank',
                  style: TextStyle(
                    fontSize: 8,
                    color: bgColor.computeLuminance() > 0.5
                        ? Colors.grey.shade400
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    switch (page.contentType) {
      case PageContentType.image:
        return Container(
          color: Colors.grey.shade100,
          child: Image.file(
            File(page.contentPath!),
            fit: BoxFit.contain,
            cacheHeight: 300,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image,
                        color: Colors.red.shade300, size: 24),
                    const SizedBox(height: 4),
                    const Text(
                      'Load Error',
                      style: TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              if (frame == null) {
                return const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: child,
              );
            },
          ),
        );

      case PageContentType.pdf:
      // Use the already-loaded PdfDocument from the parent screen.
      // Do NOT open a new instance here, or the thumbnail will hang.
        if (pdfDocument == null) {
          return Container(
            color: Colors.grey.shade100,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return Container(
          color: Colors.white,
          child: PdfPageView(
            document: pdfDocument!,
            pageNumber: (page.pdfPageIndex ?? 0) + 1,
            maximumDpi: 180,
          ),
        );

      case PageContentType.placeholder:
      default:
        final bgColor = page.backgroundColor ?? Colors.white;
        return Container(
          color: bgColor,
          child: Center(
            child: Icon(
              page.icon,
              size: 24,
              color: bgColor.computeLuminance() > 0.5
                  ? Colors.indigo.shade200
                  : Colors.white.withOpacity(0.5),
            ),
          ),
        );
    }
  }
}

// Custom painter for thumbnail drawings - handles eraser and texts correctly
class _ThumbnailPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final List<DrawingText> texts;

  _ThumbnailPainter({
    required this.strokes,
    this.currentStroke,
    required this.texts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isNotEmpty || currentStroke != null) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

      for (final stroke in strokes) {
        _drawSingleStroke(canvas, stroke, size);
      }

      if (currentStroke != null) {
        _drawSingleStroke(canvas, currentStroke!, size);
      }

      canvas.restore();
    }

    for (final textElement in texts) {
      if (textElement.text.trim().isEmpty) continue;

      final textSpan = TextSpan(
        text: textElement.text,
        style: TextStyle(
          color: textElement.color,
          fontSize:
          (textElement.fontSize * (size.width / 1920)).clamp(1.0, 10.0),
          fontWeight: textElement.isBold ? FontWeight.bold : FontWeight.normal,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: textElement.alignment,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );

      textPainter.layout(maxWidth: textElement.width * (size.width / 1920));
      textPainter.paint(
        canvas,
        Offset(textElement.position.dx * size.width,
            textElement.position.dy * size.height),
      );
    }
  }

  void _drawSingleStroke(Canvas canvas, DrawingStroke stroke, Size size) {
    if (stroke.points.length < 2) return;

    if (stroke.tool == DrawingTool.eraser &&
        (stroke.dusterType == DusterType.feltBlock || stroke.dusterType == DusterType.sponge)) {
      _drawDirectionalBlockEraserThumbnail(canvas, stroke, size);
      return;
    }

    final double widthScale = size.width / 1920.0;
    double calculatedWidth = stroke.width * widthScale;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (stroke.tool == DrawingTool.eraser) {
      paint.blendMode = BlendMode.clear;
      calculatedWidth = (calculatedWidth * 3.0).clamp(3.0, 100.0);
    } else {
      paint.color = stroke.color;
      calculatedWidth = calculatedWidth.clamp(1.2, 50.0);
    }

    if (stroke.tool == DrawingTool.highlighter) {
      paint.color = stroke.color.withOpacity(0.3);
      calculatedWidth *= 2;
    }

    paint.strokeWidth = calculatedWidth;

    final path = Path()
      ..moveTo(stroke.points[0].dx * size.width, stroke.points[0].dy * size.height);

    if (stroke.points.length == 2) {
      path.lineTo(
          stroke.points[1].dx * size.width, stroke.points[1].dy * size.height);
    } else {
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final midPoint = Offset(
          ((stroke.points[i].dx + stroke.points[i + 1].dx) / 2) * size.width,
          ((stroke.points[i].dy + stroke.points[i + 1].dy) / 2) * size.height,
        );
        path.quadraticBezierTo(
          stroke.points[i].dx * size.width,
          stroke.points[i].dy * size.height,
          midPoint.dx,
          midPoint.dy,
        );
      }
      path.lineTo(
        stroke.points.last.dx * size.width,
        stroke.points.last.dy * size.height,
      );
    }

    canvas.drawPath(path, paint);
  }

  void _drawDirectionalBlockEraserThumbnail(Canvas canvas, DrawingStroke stroke, Size size) {
    final double widthScale = size.width / 1920.0;
    final double baseWidth = stroke.width * widthScale * 3.0;

    final double blockW = (stroke.dusterType == DusterType.feltBlock) ? baseWidth * 1.8 : baseWidth * 1.5;
    final double blockH = (stroke.dusterType == DusterType.feltBlock) ? baseWidth * 0.9 : baseWidth * 1.0;
    final paint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p1 = Offset(stroke.points[i].dx * size.width, stroke.points[i].dy * size.height);
      final p2 = Offset(stroke.points[i + 1].dx * size.width, stroke.points[i + 1].dy * size.height);
      final delta = p2 - p1;
      final dist = delta.distance;
      if (dist < 0.1) continue;

      final angle = math.atan2(delta.dy, delta.dx);
      final step = math.max(1.5, blockH * 0.25);
      final steps = (dist / step).ceil();

      for (int s = 0; s <= steps; s++) {
        final t = s / steps;
        final pos = Offset.lerp(p1, p2, t)!;

        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle);
        final rect = Rect.fromCenter(center: Offset.zero, width: blockW, height: blockH);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(stroke.dusterType == DusterType.feltBlock ? 2 : 5)),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) => true;
}