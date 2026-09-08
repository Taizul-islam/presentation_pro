import 'dart:math' as math;
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
  final Function(List<int>, double, double, Offset)? onStrokesScaled;
  final Function(List<int>, double, Offset)? onStrokesRotated;
  final Function(Rect?, List<int>)? onSelectionChanged;
  final Function(Offset)? onTextCreated;
  final VoidCallback? onInteraction;

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
    this.onStrokesScaled,
    this.onStrokesRotated,
    this.onSelectionChanged,
    this.onTextCreated,
    this.onInteraction,
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

  // Scaling state
  int? _activeHandleIndex; // 0: TL, 1: TR, 2: BL, 3: BR
  Offset? _scalePivot;
  double _scaleX = 1.0;
  double _scaleY = 1.0;

  // Rotation state
  bool _isRotating = false;
  double _rotationAngle = 0.0;
  Offset? _rotationCenter;

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
    // Use post frame callback to avoid "setState during build" errors in parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSelectionChanged?.call(null, []);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        return MouseRegion(
          onHover: (event) {
            if (!_isDrawing && !_isMoving) {
              widget.onHoverUpdate(event.localPosition);
            }
          },
          onExit: (_) => widget.onHoverUpdate(null),
          child: Listener(
            onPointerDown: (PointerDownEvent event) {
              widget.onInteraction?.call();
              final pos = event.localPosition;
              if (widget.selectedTool == DrawingTool.selector) {
                _handleSelectionStart(pos);
              } else if (widget.selectedTool == DrawingTool.text) {
                // Pass normalized position to parent
                widget.onTextCreated?.call(Offset(pos.dx / canvasSize.width, pos.dy / canvasSize.height));
              } else {
                _isDrawing = true;
                widget.onHoverUpdate(null);
                // Pass normalized position to parent
                widget.onStrokeStart(Offset(pos.dx / canvasSize.width, pos.dy / canvasSize.height));
              }
            },
            onPointerMove: (PointerMoveEvent event) {
              final pos = event.localPosition;
              if (widget.selectedTool == DrawingTool.selector) {
                _handleSelectionUpdate(pos);
              } else if (_isDrawing) {
                // Pass normalized position to parent
                widget.onStrokeUpdate(Offset(pos.dx / canvasSize.width, pos.dy / canvasSize.height));
              } else {
                widget.onHoverUpdate(pos);
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
                scaleX: _scaleX,
                scaleY: _scaleY,
                scalePivot: _scalePivot,
                rotationAngle: _rotationAngle,
                rotationCenter: _rotationCenter,
                canvasSize: canvasSize, // Pass canvas size for scaling
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleSelectionStart(Offset position) {
    if (_selectionRect != null) {
      // Check for corner handles first (high priority)
      final handles = [
        _selectionRect!.topLeft,
        _selectionRect!.topRight,
        _selectionRect!.bottomLeft,
        _selectionRect!.bottomRight,
      ];

      for (int i = 0; i < handles.length; i++) {
        if ((position - handles[i]).distance < 20) {
          setState(() {
            _activeHandleIndex = i;
            // Pivot is the opposite corner
            if (i == 0) _scalePivot = _selectionRect!.bottomRight;
            if (i == 1) _scalePivot = _selectionRect!.bottomLeft;
            if (i == 2) _scalePivot = _selectionRect!.topRight;
            if (i == 3) _scalePivot = _selectionRect!.topLeft;
            _dragStart = position;
            _scaleX = 1.0;
            _scaleY = 1.0;
          });
          return;
        }
      }

      // Check for rotation handle (35px above top center)
      final rotateHandle = _selectionRect!.topCenter + const Offset(0, -35);
      if ((position - rotateHandle).distance < 20) {
        setState(() {
          _isRotating = true;
          _rotationCenter = _selectionRect!.center;
          _rotationAngle = 0.0;
          _dragStart = position;
        });
        return;
      }

      if (_selectionRect!.contains(position)) {
        setState(() {
          _isMoving = true;
          _dragStart = position;
          _currentDragOffset = Offset.zero;
        });
        return;
      }
    }

    setState(() {
      _selectionRect = Rect.fromPoints(position, position);
      _selectedIndices = [];
      _isMoving = false;
      _activeHandleIndex = null;
      _isRotating = false;
    });
  }

  void _handleSelectionUpdate(Offset position) {
    if (_isRotating && _rotationCenter != null) {
      final currentVector = position - _rotationCenter!;
      final startVector = _dragStart! - _rotationCenter!;
      
      // Calculate angle between start vector and current vector
      double angle = math.atan2(currentVector.dy, currentVector.dx) - 
                    math.atan2(startVector.dy, startVector.dx);
      
      setState(() {
        _rotationAngle = angle;
      });
    } else if (_activeHandleIndex != null && _scalePivot != null) {
      // Calculate scale based on drag distance from pivot
      double initialWidth = (_scalePivot!.dx - _dragStart!.dx).abs();
      double initialHeight = (_scalePivot!.dy - _dragStart!.dy).abs();
      double currentWidth = (_scalePivot!.dx - position.dx).abs();
      double currentHeight = (_scalePivot!.dy - position.dy).abs();

      setState(() {
        _scaleX = initialWidth > 0 ? currentWidth / initialWidth : 1.0;
        _scaleY = initialHeight > 0 ? currentHeight / initialHeight : 1.0;
        
        // Prevent negative scaling or flipping (keep min size)
        if (_scaleX < 0.1) _scaleX = 0.1;
        if (_scaleY < 0.1) _scaleY = 0.1;
      });
    } else if (_isMoving && _dragStart != null) {
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
    if (_isRotating) {
      if (_rotationAngle != 0.0) {
        widget.onStrokesRotated?.call(_selectedIndices, _rotationAngle, _rotationCenter!);
      }
      setState(() {
        _isRotating = false;
        _rotationAngle = 0.0;
        _rotationCenter = null;
        // Re-calculate selection rect after rotation
        _refreshSelectionRect();
      });
      _notifySelectionChanged();
    } else if (_activeHandleIndex != null) {
      if (_scaleX != 1.0 || _scaleY != 1.0) {
        widget.onStrokesScaled?.call(_selectedIndices, _scaleX, _scaleY, _scalePivot!);
      }
      setState(() {
        if (_selectionRect != null) {
          // Update selection rect based on scale
          final newWidth = _selectionRect!.width * _scaleX;
          final newHeight = _selectionRect!.height * _scaleY;
          
          Offset newTopLeft = _scalePivot!;
          if (_activeHandleIndex == 0) newTopLeft = _scalePivot! - Offset(newWidth, newHeight);
          if (_activeHandleIndex == 1) newTopLeft = Offset(_scalePivot!.dx, _scalePivot!.dy - newHeight);
          if (_activeHandleIndex == 2) newTopLeft = Offset(_scalePivot!.dx - newWidth, _scalePivot!.dy);
          if (_activeHandleIndex == 3) newTopLeft = _scalePivot!;

          _selectionRect = Rect.fromLTWH(newTopLeft.dx, newTopLeft.dy, newWidth, newHeight);
        }
        _activeHandleIndex = null;
        _scalePivot = null;
        _scaleX = 1.0;
        _scaleY = 1.0;
      });
      _notifySelectionChanged();
    } else if (_isMoving) {
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
      _notifySelectionChanged();
    } else if (_selectionRect != null) {
      if (_selectionRect!.width < 5 && _selectionRect!.height < 5) {
        _clearSelection();
      } else {
        _notifySelectionChanged();
      }
    }
  }

  void _notifySelectionChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSelectionChanged?.call(_selectionRect, _selectedIndices);
      }
    });
  }

  void _refreshSelectionRect() {
    if (_selectedIndices.isEmpty) {
      _selectionRect = null;
      return;
    }
    
    Rect? newRect;
    for (final index in _selectedIndices) {
      if (index < widget.strokes.length) {
        final box = widget.strokes[index].boundingBox;
        newRect = newRect == null ? box : newRect.expandToInclude(box);
      }
    }
    _selectionRect = newRect;
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
    // Don't call onSelectionChanged here to avoid too many rebuilds, end is enough for now
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
  final double scaleX;
  final double scaleY;
  final Offset? scalePivot;
  final double rotationAngle;
  final Offset? rotationCenter;
  final Size canvasSize;

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
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.scalePivot,
    this.rotationAngle = 0.0,
    this.rotationCenter,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (int i = 0; i < strokes.length; i++) {
      var stroke = strokes[i];
      // Scale stroke points to canvas pixels
      final scaledStroke = _scaleStrokeToPixels(stroke, canvasSize);

      if (selectedIndices.contains(i)) {
        if (dragOffset != null) {
          _drawStroke(canvas, scaledStroke.translate(dragOffset!));
        } else if (scaleX != 1.0 || scaleY != 1.0) {
          _drawStroke(canvas, scaledStroke.scale(scaleX, scaleY, scalePivot!));
        } else if (rotationAngle != 0.0) {
          _drawStroke(canvas, scaledStroke.rotate(rotationAngle, rotationCenter!));
        } else {
          _drawStroke(canvas, scaledStroke);
        }
      } else {
        _drawStroke(canvas, scaledStroke);
      }
    }

    if (currentStroke != null && currentStroke!.points.length > 1) {
      _drawStroke(canvas, _scaleStrokeToPixels(currentStroke!, canvasSize));
    }

    canvas.restore();

    // Draw Selection UI
    if (selectionRect != null) {
      if (rotationAngle != 0.0 && rotationCenter != null) {
        canvas.save();
        canvas.translate(rotationCenter!.dx, rotationCenter!.dy);
        canvas.rotate(rotationAngle);
        canvas.translate(-rotationCenter!.dx, -rotationCenter!.dy);
        _drawSelectionBox(canvas, selectionRect!);
        canvas.restore();
      } else {
        Rect rect;
        if (dragOffset != null) {
          rect = selectionRect!.shift(dragOffset!);
        } else if (scaleX != 1.0 || scaleY != 1.0) {
          final newWidth = selectionRect!.width * scaleX;
          final newHeight = selectionRect!.height * scaleY;
          
          double left = scalePivot!.dx < selectionRect!.center.dx ? scalePivot!.dx : scalePivot!.dx - newWidth;
          double top = scalePivot!.dy < selectionRect!.center.dy ? scalePivot!.dy : scalePivot!.dy - newHeight;
          
          rect = Rect.fromLTWH(left, top, newWidth, newHeight);
        } else {
          rect = selectionRect!;
        }
        _drawSelectionBox(canvas, rect);
      }
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
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Draw dashed rectangle
    _drawDashedRect(canvas, rect, paint, 4.0, 4.0);

    // 2. Draw light background
    canvas.drawRect(rect, Paint()..color = Colors.blue.withOpacity(0.02)..style = PaintingStyle.fill);

    // 3. Draw knobs (circular white knobs on sides)
    final knobPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final knobBorderPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final sideKnobs = [
      rect.topCenter,
      rect.bottomCenter,
      rect.centerLeft,
      rect.centerRight,
    ];

    for (var p in sideKnobs) {
      canvas.drawCircle(p, 5, knobPaint);
      canvas.drawCircle(p, 5, knobBorderPaint);
    }

    // 4. Draw L-shaped corner brackets
    final bracketPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const double bLen = 12.0;

    // Top Left
    canvas.drawPath(Path()..moveTo(rect.left, rect.top + bLen)..lineTo(rect.left, rect.top)..lineTo(rect.left + bLen, rect.top), bracketPaint);
    // Top Right
    canvas.drawPath(Path()..moveTo(rect.right - bLen, rect.top)..lineTo(rect.right, rect.top)..lineTo(rect.right, rect.top + bLen), bracketPaint);
    // Bottom Left
    canvas.drawPath(Path()..moveTo(rect.left, rect.bottom - bLen)..lineTo(rect.left, rect.bottom)..lineTo(rect.left + bLen, rect.bottom), bracketPaint);
    // Bottom Right
    canvas.drawPath(Path()..moveTo(rect.right - bLen, rect.bottom)..lineTo(rect.right, rect.bottom)..lineTo(rect.right, rect.bottom - bLen), bracketPaint);

    // 5. Draw Rotation handle
    final rotateCenter = rect.topCenter + const Offset(0, -35);
    canvas.drawCircle(rotateCenter, 15, knobPaint..color = Colors.white);
    canvas.drawCircle(rotateCenter, 15, knobBorderPaint..color = Colors.grey.shade300);
    
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.rotate_right.codePoint),
        style: TextStyle(
          fontSize: 20,
          fontFamily: Icons.rotate_right.fontFamily,
          package: Icons.rotate_right.fontPackage,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    canvas.drawCircle(rotateCenter - Offset(iconPainter.width/2, iconPainter.height/2), 0, Paint()); // Anchor
    iconPainter.paint(canvas, rotateCenter - Offset(iconPainter.width/2, iconPainter.height/2));
  }

  DrawingStroke _scaleStrokeToPixels(DrawingStroke stroke, Size size) {
    return DrawingStroke(
      points: stroke.points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList(),
      color: stroke.color,
      width: stroke.width,
      tool: stroke.tool,
      isLocked: stroke.isLocked,
    );
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