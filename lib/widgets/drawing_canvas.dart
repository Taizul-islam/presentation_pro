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
  final Function(List<int>, Offset)? onStrokesMoved;

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
    this.onStrokesMoved,
  }) : super(key: key);

  @override
  _DrawingCanvasState createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  bool _isDrawing = false;
  Rect? _selectionRect;
  List<int> _selectedIndices = [];
  Offset? _dragStart;
  Offset? _currentDragOffset;
  bool _isMoving = false;

  @override
  void didUpdateWidget(DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTool == DrawingTool.selector &&
        widget.selectedTool != DrawingTool.selector) {
      _clearSelection();
    }
    if (widget.strokes.isEmpty && oldWidget.strokes.isNotEmpty) {
      _clearSelection();
    }
  }

  void _clearSelection() {
    setState(() {
      _selectionRect = null;
      _selectedIndices = [];
      _isMoving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        if (!_isDrawing && !_isMoving) {
          widget.onHoverUpdate(event.localPosition);
        }
      },
      onExit: (_) => widget.onHoverUpdate(null),
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          if (widget.selectedTool == DrawingTool.selector) {
            _handleSelectionStart(event.localPosition);
          } else {
            _isDrawing = true;
            widget.onHoverUpdate(null);
            widget.onStrokeStart(event.localPosition);
          }
        },
        onPointerMove: (PointerMoveEvent event) {
          if (widget.selectedTool == DrawingTool.selector) {
            _handleSelectionUpdate(event.localPosition);
          } else if (_isDrawing) {
            widget.onStrokeUpdate(event.localPosition);
          } else {
            widget.onHoverUpdate(event.localPosition);
          }
        },
        onPointerUp: (PointerUpEvent event) {
          if (widget.selectedTool == DrawingTool.selector) {
            _handleSelectionEnd();
          } else if (_isDrawing) {
            _isDrawing = false;
            widget.onStrokeEnd();
            widget.onHoverUpdate(event.localPosition);
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
            selectionRect: _selectionRect,
            selectedIndices: _selectedIndices,
            dragOffset: _currentDragOffset,
          ),
        ),
      ),
    );
  }

  void _handleSelectionStart(Offset position) {
    if (_selectionRect != null && _selectionRect!.contains(position)) {
      _isMoving = true;
      _dragStart = position;
      _currentDragOffset = Offset.zero;
    } else {
      setState(() {
        _selectionRect = Rect.fromPoints(position, position);
        _selectedIndices = [];
        _isMoving = false;
      });
    }
  }

  void _handleSelectionUpdate(Offset position) {
    if (_isMoving && _dragStart != null) {
      setState(() {
        _currentDragOffset = position - _dragStart!;
      });
    } else if (_selectionRect != null) {
      setState(() {
        _selectionRect = Rect.fromPoints(_selectionRect!.topLeft, position);
        _updateSelectedIndices();
      });
    }
  }

  void _handleSelectionEnd() {
    if (_isMoving) {
      if (_currentDragOffset != null && _currentDragOffset != Offset.zero) {
        widget.onStrokesMoved?.call(_selectedIndices, _currentDragOffset!);
      }
      setState(() {
        if (_selectionRect != null && _currentDragOffset != null) {
          _selectionRect = _selectionRect!.shift(_currentDragOffset!);
        }
        _currentDragOffset = null;
        _isMoving = false;
      });
    } else if (_selectionRect != null) {
      if (_selectionRect!.width < 5 && _selectionRect!.height < 5) {
        setState(() {
          _selectionRect = null;
          _selectedIndices = [];
        });
      }
    }
  }

  void _updateSelectedIndices() {
    if (_selectionRect == null) return;
    List<int> indices = [];
    for (int i = 0; i < widget.strokes.length; i++) {
      if (_selectionRect!.overlaps(widget.strokes[i].boundingBox)) {
        indices.add(i);
      }
    }
    _selectedIndices = indices;
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
  final Rect? selectionRect;
  final List<int> selectedIndices;
  final Offset? dragOffset;

  DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
    required this.eraserWidth,
    required this.tool,
    required this.hoverPosition,
    this.selectionRect,
    this.selectedIndices = const [],
    this.dragOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (int i = 0; i < strokes.length; i++) {
      var stroke = strokes[i];
      if (selectedIndices.contains(i) && dragOffset != null) {
        _drawStroke(canvas, stroke.translate(dragOffset!));
      } else {
        _drawStroke(canvas, stroke);
      }
    }

    if (currentStroke != null && currentStroke!.points.length > 1) {
      _drawStroke(canvas, currentStroke!);
    }

    canvas.restore();

    // Draw Selection UI
    if (selectionRect != null) {
      final rect = dragOffset != null ? selectionRect!.shift(dragOffset!) : selectionRect!;
      _drawSelectionBox(canvas, rect);
    }

    // Draw Eraser Preview
    if (tool == DrawingTool.eraser && hoverPosition != null) {
      final previewPaint = Paint()
        ..color = Colors.indigo.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(hoverPosition!, eraserWidth / 2, previewPaint);
      canvas.drawCircle(hoverPosition!, 1.5, previewPaint..style = PaintingStyle.fill);
    }
  }

  void _drawSelectionBox(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw dashed rectangle
    final dashWidth = 5.0;
    final dashSpace = 5.0;
    
    _drawDashedRect(canvas, rect, paint, dashWidth, dashSpace);

    // Draw background
    canvas.drawRect(rect, Paint()..color = Colors.blue.withOpacity(0.05)..style = PaintingStyle.fill);

    // Draw handles (white circles)
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final handles = [
      rect.topLeft, rect.topCenter, rect.topRight,
      rect.centerLeft, rect.centerRight,
      rect.bottomLeft, rect.bottomCenter, rect.bottomRight,
    ];

    for (var h in handles) {
      canvas.drawCircle(h, 5, handlePaint);
      canvas.drawCircle(h, 5, handleBorderPaint);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint, double dashWidth, double dashSpace) {
    void drawDashedLine(Offset p1, Offset p2) {
      var distance = (p2 - p1).distance;
      var dx = (p2.dx - p1.dx) / distance;
      var dy = (p2.dy - p1.dy) / distance;
      var currentDist = 0.0;
      while (currentDist < distance) {
        var nextDist = currentDist + dashWidth;
        if (nextDist > distance) nextDist = distance;
        canvas.drawLine(
          p1 + Offset(dx * currentDist, dy * currentDist),
          p1 + Offset(dx * nextDist, dy * nextDist),
          paint,
        );
        currentDist += dashWidth + dashSpace;
      }
    }

    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
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