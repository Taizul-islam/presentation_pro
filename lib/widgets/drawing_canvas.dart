import 'package:flutter/material.dart';
import '../models/drawing_stroke.dart';

class DrawingCanvas extends StatefulWidget {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final Color selectedColor;
  final double strokeWidth;
  final double eraserWidth;
  final DrawingTool selectedTool;
  final Offset? hoverPosition;
  final Function(Offset) onStrokeStart;
  final Function(Offset) onStrokeUpdate;
  final Function() onStrokeEnd;
  final Function(Offset?) onHoverUpdate;

  const DrawingCanvas({
    Key? key,
    required this.strokes,
    required this.currentStroke,
    required this.selectedColor,
    required this.strokeWidth,
    required this.eraserWidth,
    required this.selectedTool,
    required this.hoverPosition,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.onHoverUpdate,
  }) : super(key: key);

  @override
  _DrawingCanvasState createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        if (!_isDrawing) {
          widget.onHoverUpdate(event.localPosition);
        }
      },
      onExit: (_) => widget.onHoverUpdate(null),
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          _isDrawing = true;
          widget.onHoverUpdate(null); // Hide preview when drawing
          widget.onStrokeStart(event.localPosition);
        },
        onPointerMove: (PointerMoveEvent event) {
          if (_isDrawing) {
            widget.onStrokeUpdate(event.localPosition);
          } else {
            widget.onHoverUpdate(event.localPosition);
          }
        },
        onPointerUp: (PointerUpEvent event) {
          if (_isDrawing) {
            _isDrawing = false;
            widget.onStrokeEnd();
            widget.onHoverUpdate(event.localPosition);
          }
        },
        onPointerCancel: (PointerCancelEvent event) {
          if (_isDrawing) {
            _isDrawing = false;
            widget.onStrokeEnd();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          size: Size.infinite,
          painter: DrawingPainter(
            strokes: widget.strokes,
            currentStroke: widget.currentStroke,
            color: widget.selectedColor,
            strokeWidth: widget.strokeWidth,
            eraserWidth: widget.eraserWidth,
            tool: widget.selectedTool,
            hoverPosition: widget.hoverPosition,
          ),
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final Color color;
  final double strokeWidth;
  final double eraserWidth;
  final DrawingTool tool;
  final Offset? hoverPosition;

  DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
    required this.eraserWidth,
    required this.tool,
    required this.hoverPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // We use saveLayer so that BlendMode.clear only affects the ink layer, 
    // revealing the document (PDF/PPTX) underneath.
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Draw completed strokes
    for (var stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw current stroke
    if (currentStroke != null && currentStroke!.points.length > 1) {
      _drawStroke(canvas, currentStroke!);
    }

    canvas.restore();

    // Draw Duster/Eraser preview outline
    if (tool == DrawingTool.eraser && hoverPosition != null) {
      final previewPaint = Paint()
        ..color = Colors.indigo.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawCircle(hoverPosition!, eraserWidth / 2, previewPaint);
      
      // Draw a small center dot
      canvas.drawCircle(hoverPosition!, 1.5, previewPaint..style = PaintingStyle.fill);
    }
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // True Eraser: Clear the pixels instead of painting white
    if (stroke.tool == DrawingTool.eraser) {
      paint.blendMode = BlendMode.clear;
      // Eraser size is fixed during the stroke based on what was selected
      // stroke.width will already be set to eraserWidth by the caller
    }

    // Highlighter effect
    if (stroke.tool == DrawingTool.highlighter) {
      paint.color = stroke.color.withOpacity(0.3);
      paint.strokeWidth = stroke.width * 3;
    }

    final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);

    // Use quadratic bezier for smooth curves
    if (stroke.points.length == 2) {
      path.lineTo(stroke.points[1].dx, stroke.points[1].dy);
    } else {
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final midPoint = Offset(
          (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
          (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
          stroke.points[i].dx,
          stroke.points[i].dy,
          midPoint.dx,
          midPoint.dy,
        );
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return true;
  }
}