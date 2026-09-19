import 'dart:io';
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
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${page.pageNumber}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.indigo : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? Colors.indigo : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: _buildThumbnailPreview(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    final hasContent = page.strokes.isNotEmpty ||
        page.texts.isNotEmpty ||
        currentStroke != null;
    return Stack(
      children: [
        _buildBackground(hasContent),
        Positioned.fill(
          child: CustomPaint(
            painter: _ThumbnailPainter(
              strokes: page.strokes,
              currentStroke: currentStroke,
              texts: page.texts,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(bool hasContent) {
    // Blank slide
    if (page.contentPath == null || page.contentPath!.isEmpty) {
      final bgColor = page.backgroundColor ?? Colors.white;
      if (hasContent) return Container(color: bgColor);

      return Container(
        color: bgColor,
        child: Center(
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
            maximumDpi: 100,
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

    final paint = Paint()
      ..strokeWidth = (stroke.width * (size.width / 1920)).clamp(0.5, 3.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (stroke.tool == DrawingTool.eraser) {
      paint.blendMode = BlendMode.clear;
    } else {
      paint.color = stroke.color;
    }

    if (stroke.tool == DrawingTool.highlighter) {
      paint.color = stroke.color.withOpacity(0.3);
      paint.strokeWidth *= 2;
    }

    final path = Path();
    path.moveTo(
        stroke.points[0].dx * size.width, stroke.points[0].dy * size.height);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx * size.width,
          stroke.points[i].dy * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) => true;
}