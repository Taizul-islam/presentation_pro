import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/drawing_stroke.dart';

class SlideThumbnail extends StatelessWidget {
  final PresentationPage page;
  final bool isSelected;
  final VoidCallback onTap;

  const SlideThumbnail({
    Key? key,
    required this.page,
    required this.isSelected,
    required this.onTap,
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
                        )
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
    // Check for blank slide with drawings - show drawing preview with background color
    if ((page.contentPath == null || page.contentPath!.isEmpty) && page.strokes.isNotEmpty) {
      final bgColor = page.backgroundColor ?? Colors.white;
      return Stack(
        children: [
          // Background color
          Container(color: bgColor),
          // Drawing overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _ThumbnailPainter(strokes: page.strokes),
            ),
          ),
        ],
      );
    }

    // Check for blank slide without drawings - show background color
    if (page.contentPath == null || page.contentPath!.isEmpty) {
      final bgColor = page.backgroundColor ?? Colors.white;
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
                    : Colors.white.withOpacity(0.5),
              ),
              SizedBox(height: 4),
              Text(
                'Blank',
                style: TextStyle(
                  fontSize: 8,
                  color: bgColor.computeLuminance() > 0.5
                      ? Colors.grey.shade400
                      : Colors.white.withOpacity(0.7),
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
                    Icon(Icons.broken_image, color: Colors.red.shade300, size: 24),
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
        return PdfDocumentViewBuilder.file(
          page.contentPath!,
          loadingBuilder: (context) => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          builder: (context, document) {
            if (document == null) {
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return PdfPageView(
              document: document,
              pageNumber: (page.pdfPageIndex ?? 0) + 1,
              maximumDpi: 100,
            );
          },
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

// Custom painter for thumbnail drawings - handles eraser correctly
class _ThumbnailPainter extends CustomPainter {
  final List<DrawingStroke> strokes;

  _ThumbnailPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    // Scale factor to fit 100px height thumbnail
    final scaleFactor = size.height / 600; // Assuming slide height ~600px

    // Save canvas state for eraser
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final paint = Paint()
        ..strokeWidth = (stroke.width * scaleFactor).clamp(0.5, 5.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      // Handle eraser differently - use BlendMode.clear
      if (stroke.tool == DrawingTool.eraser) {
        paint.color = Colors.white;
        paint.blendMode = BlendMode.clear;
      } else {
        paint.color = stroke.color;
      }

      final path = Path();
      path.moveTo(
        stroke.points[0].dx * scaleFactor,
        stroke.points[0].dy * scaleFactor,
      );

      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(
          stroke.points[i].dx * scaleFactor,
          stroke.points[i].dy * scaleFactor,
        );
      }

      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}