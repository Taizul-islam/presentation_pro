import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/drawing_stroke.dart';

class DrawingCanvas extends StatefulWidget {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final Color selectedColor;
  final double strokeWidth;
  final double eraserWidth;
  final DrawingTool selectedTool;
  final DusterType selectedDusterType;
  final DusterOrientation selectedDusterOrientation;
  final LaserMode selectedLaserMode;
  final Color laserColor;
  final double spotlightRadius;
  final Offset? hoverPosition;
  final Function(Offset, {DrawingTool? toolForThisStroke}) onStrokeStart;
  final Function(Offset) onStrokeUpdate;
  final Function() onStrokeEnd;
  final Function(Offset?) onHoverUpdate;
  final Function(List<int>, Offset)? onStrokesMoved;
  final Function(List<int>, double, double, Offset)? onStrokesScaled;
  final Function(List<int>, double, Offset)? onStrokesRotated;
  final Function(Rect?, List<int>)? onSelectionChanged;
  final Function(Offset)? onTextCreated;
  final Function(bool isHand, double size)? onHandTouchDetected;
  final VoidCallback? onInteraction;

  const DrawingCanvas({
    Key? key,
    required this.strokes,
    required this.currentStroke,
    required this.selectedColor,
    required this.strokeWidth,
    required this.eraserWidth,
    required this.selectedTool,
    this.selectedDusterType = DusterType.feltBlock,
    this.selectedDusterOrientation = DusterOrientation.rightHand,
    this.selectedLaserMode = LaserMode.laserDot,
    this.laserColor = Colors.redAccent,
    this.spotlightRadius = 100.0,
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
    this.onHandTouchDetected,
    this.onInteraction,
  }) : super(key: key);

  @override
  _DrawingCanvasState createState() => _DrawingCanvasState();
}

class _LaserPoint {
  final Offset position;
  final DateTime timestamp;
  _LaserPoint(this.position, this.timestamp);
}

class _DrawingCanvasState extends State<DrawingCanvas> with WidgetsBindingObserver {
  bool _isDrawing = false;
  Rect? _selectionRect;
  List<int> _selectedIndices = [];
  final Set<int> _previouslyMovedIndices = {};
  final Set<int> _activePointers = {};
  bool _stylusIsDown = false;
  final Set<int> _stylusPointers = {};
  Offset? _dragStart;
  Offset? _currentDragOffset;
  bool _isMoving = false;
  Size? _lastCanvasSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_isDrawing) {
        _isDrawing = false;
        widget.onStrokeEnd();
      }
      _activePointers.clear();
      _stylusPointers.clear();
      _stylusIsDown = false;
      widget.onHandTouchDetected?.call(false, 0.0);
    }
  }

  // Laser pointer state
  final List<_LaserPoint> _laserPoints = [];

  // Duster direction state
  double _dusterAngle = 0.0;
  Offset? _lastPointerPos;

  void _addLaserPoint(Offset pos) {
    if (widget.selectedTool == DrawingTool.laserPointer &&
        widget.selectedLaserMode == LaserMode.laserDot) {
      final now = DateTime.now();
      _laserPoints.add(_LaserPoint(pos, now));
      _laserPoints.removeWhere(
          (p) => now.difference(p.timestamp).inMilliseconds > 1200);
      setState(() {});
    }
  }

  // Scaling state
  int? _activeHandleIndex; // 0: TL, 1: TR, 2: BL, 3: BR
  Offset? _scalePivot;
  double _scaleX = 1.0;
  double _scaleY = 1.0;

  // Rotation state
  bool _isRotating = false;
  double _rotationAngle = 0.0;
  Offset? _rotationCenter;

  double get _currentDusterAngle {
    switch (widget.selectedDusterOrientation) {
      case DusterOrientation.rightHand:
        return 15.0 * math.pi / 180.0; // 15° Right-hand grip angle
      case DusterOrientation.leftHand:
        return -15.0 * math.pi / 180.0; // -15° Left-hand grip angle
      case DusterOrientation.vertical:
        return math.pi / 2.0; // 90° Vertical
      case DusterOrientation.horizontal:
        return 0.0; // 0° Horizontal
      case DusterOrientation.auto:
        return _dusterAngle;
    }
  }

  void _updateDusterAngle(Offset pos) {
    if (widget.selectedDusterOrientation != DusterOrientation.auto) return;
    if (_lastPointerPos != null) {
      final delta = pos - _lastPointerPos!;
      if (delta.distance > 15.0) { // High-pass distance filter to eliminate hand jitters
        final targetAngle = math.atan2(delta.dy, delta.dx);
        double diff = (targetAngle - _dusterAngle) % (2 * math.pi);
        if (diff > math.pi) diff -= 2 * math.pi;
        if (diff < -math.pi) diff += 2 * math.pi;
        _dusterAngle += diff * 0.25;
      }
    }
    _lastPointerPos = pos;
  }

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

    // Refresh selection rect if strokes changed during selection mode
    if (widget.selectedTool == DrawingTool.selector && widget.strokes != oldWidget.strokes) {
      _refreshSelectionRect();
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

  bool _checkHandTouch(PointerEvent event) {
    final bool isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    if (isStylus) {
      return false;
    }

    if (_stylusIsDown) {
      widget.onHandTouchDetected?.call(true, 130.0);
      return true;
    }

    if (event.kind == PointerDeviceKind.touch) {
      final double radius = math.max(event.radiusMajor, event.radiusMinor);
      if (radius >= 18.0) {
        final double handSize = (radius * 2.8).clamp(110.0, 160.0);
        widget.onHandTouchDetected?.call(true, handSize);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        _lastCanvasSize = canvasSize; // Store for normalization later
        
        return MouseRegion(
          onHover: (event) {
            _updateDusterAngle(event.localPosition);
            _addLaserPoint(event.localPosition);
            if (!_isDrawing && !_isMoving) {
              widget.onHoverUpdate(event.localPosition);
            }
          },
          onExit: (_) {
            _lastPointerPos = null;
            widget.onHoverUpdate(null);
          },
          child: Listener(
            onPointerDown: (PointerDownEvent event) {
              if (widget.selectedTool == DrawingTool.hand) return;
              widget.onInteraction?.call();
              _activePointers.add(event.pointer);

              final isStylus = event.kind == PointerDeviceKind.stylus ||
                  event.kind == PointerDeviceKind.invertedStylus;
              if (isStylus) {
                _stylusPointers.add(event.pointer);
                _stylusIsDown = true;
                if (_stylusPointers.length == 1) {
                  widget.onHandTouchDetected?.call(false, 0.0);
                }
              }

              final isHand = _checkHandTouch(event);
              final pos = event.localPosition;
              _lastPointerPos = pos;
              _addLaserPoint(pos);

              final effectiveTool = (isHand || widget.selectedTool == DrawingTool.eraser)
                  ? DrawingTool.eraser
                  : widget.selectedTool;

              if (effectiveTool == DrawingTool.laserPointer) {
                widget.onHoverUpdate(pos);
                return;
              } else if (effectiveTool == DrawingTool.selector) {
                _handleSelectionStart(pos);
              } else if (effectiveTool == DrawingTool.shape &&
                  _tryHandleExistingShapeInteraction(pos)) {
                return;
              } else if (effectiveTool == DrawingTool.text) {
                // Pass normalized position to parent
                widget.onTextCreated?.call(Offset(pos.dx / canvasSize.width, pos.dy / canvasSize.height));
              } else {
                _clearSelection();
                _isDrawing = true;
                widget.onHoverUpdate(pos);
                // Pass normalized position and effective tool to parent
                widget.onStrokeStart(
                  Offset(pos.dx / canvasSize.width, pos.dy / canvasSize.height),
                  toolForThisStroke: effectiveTool,
                );
              }
            },
            onPointerMove: (PointerMoveEvent event) {
              if (widget.selectedTool == DrawingTool.hand) return;
              final isStylus = event.kind == PointerDeviceKind.stylus ||
                  event.kind == PointerDeviceKind.invertedStylus;
              if (!isStylus) {
                _checkHandTouch(event);
              }
              final pos = event.localPosition;
              _updateDusterAngle(pos);
              _addLaserPoint(pos);
              widget.onHoverUpdate(pos);
              if (widget.selectedTool == DrawingTool.selector ||
                  (widget.selectedTool == DrawingTool.shape && !_isDrawing)) {
                _handleSelectionUpdate(pos);
              } else if (_isDrawing) {
                // Pass normalized position to parent
                widget.onStrokeUpdate(Offset(pos.dx / canvasSize.width, pos.dy / canvasSize.height));
              }
            },
            onPointerUp: (PointerUpEvent event) {
              if (widget.selectedTool == DrawingTool.hand) return;
              _activePointers.remove(event.pointer);
              _stylusPointers.remove(event.pointer);
              _stylusIsDown = _stylusPointers.isNotEmpty;
              _lastPointerPos = null;
              if (_activePointers.isEmpty) {
                widget.onHandTouchDetected?.call(false, 0.0);
              }
              if (widget.selectedTool == DrawingTool.selector ||
                  (widget.selectedTool == DrawingTool.shape && !_isDrawing)) {
                _handleSelectionEnd();
              } else if (_isDrawing) {
                _isDrawing = false;
                widget.onStrokeEnd();
                widget.onHoverUpdate(event.localPosition);
              }
            },
            onPointerCancel: (PointerCancelEvent event) {
              if (widget.selectedTool == DrawingTool.hand) return;
              _activePointers.remove(event.pointer);
              _stylusPointers.remove(event.pointer);
              _stylusIsDown = _stylusPointers.isNotEmpty;
              _lastPointerPos = null;
              if (_activePointers.isEmpty) {
                widget.onHandTouchDetected?.call(false, 0.0);
              }
              if (_isDrawing) {
                _isDrawing = false;
                widget.onStrokeEnd();
              }
            },
            behavior: widget.selectedTool == DrawingTool.hand
                ? HitTestBehavior.translucent
                : HitTestBehavior.opaque,
            child: CustomPaint(
              size: Size.infinite,
              painter: DrawingPainter(
                strokes: widget.strokes,
                currentStroke: widget.currentStroke,
                color: widget.selectedColor,
                strokeWidth: widget.strokeWidth,
                eraserWidth: widget.eraserWidth,
                tool: widget.selectedTool,
                dusterType: widget.selectedDusterType,
                dusterAngle: _currentDusterAngle,
                selectedLaserMode: widget.selectedLaserMode,
                laserColor: widget.laserColor,
                spotlightRadius: widget.spotlightRadius,
                laserPoints: _laserPoints,
                hoverPosition: widget.hoverPosition,
                selectionRect: _selectionRect,
                selectedIndices: _selectedIndices,
                dragOffset: _currentDragOffset,
                scaleX: _scaleX,
                scaleY: _scaleY,
                scalePivot: _scalePivot,
                rotationAngle: _rotationAngle,
                rotationCenter: _rotationCenter,
                canvasSize: canvasSize,
                isSelectionLocked: _isSelectionLocked(),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _tryHandleExistingShapeInteraction(Offset pos) {
    if (_selectionRect != null) {
      final handles = [
        _selectionRect!.topLeft,
        _selectionRect!.topRight,
        _selectionRect!.bottomLeft,
        _selectionRect!.bottomRight,
      ];
      for (int i = 0; i < handles.length; i++) {
        if ((pos - handles[i]).distance < 20) {
          setState(() {
            _activeHandleIndex = i;
            if (i == 0) _scalePivot = _selectionRect!.bottomRight;
            if (i == 1) _scalePivot = _selectionRect!.bottomLeft;
            if (i == 2) _scalePivot = _selectionRect!.topRight;
            if (i == 3) _scalePivot = _selectionRect!.topLeft;
            _dragStart = pos;
            _scaleX = 1.0;
            _scaleY = 1.0;
          });
          return true;
        }
      }

      final rotateHandle = _selectionRect!.topCenter + const Offset(0, -35);
      if ((pos - rotateHandle).distance < 20) {
        setState(() {
          _isRotating = true;
          _rotationCenter = _selectionRect!.center;
          _rotationAngle = 0.0;
          _dragStart = pos;
        });
        return true;
      }

      if (_selectionRect!.contains(pos)) {
        setState(() {
          _isMoving = true;
          _dragStart = pos;
          _currentDragOffset = Offset.zero;
        });
        return true;
      }
    }

    if (_lastCanvasSize != null) {
      final size = _lastCanvasSize!;
      for (int i = widget.strokes.length - 1; i >= 0; i--) {
        final stroke = widget.strokes[i];
        final scaledStroke = _scaleStrokeToPixels(stroke, size);
        if (_isPointNearStroke(pos, scaledStroke, 18.0)) {
          setState(() {
            _selectedIndices = [i];
            _isMoving = true;
            _dragStart = pos;
            _currentDragOffset = Offset.zero;
            _activeHandleIndex = null;
            _isRotating = false;
            _refreshSelectionRect();
          });
          _notifySelectionChanged();
          return true;
        }
      }
    }

    return false;
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

    // 1-Tap Direct Selection on any Stroke or Shape (Top-most to Bottom-most)
    if (_lastCanvasSize != null) {
      final size = _lastCanvasSize!;
      for (int i = widget.strokes.length - 1; i >= 0; i--) {
        final stroke = widget.strokes[i];
        final scaledStroke = _scaleStrokeToPixels(stroke, size);
        if (_isPointNearStroke(position, scaledStroke, 18.0)) {
          setState(() {
            _selectedIndices = [i];
            _isMoving = true;
            _dragStart = position;
            _currentDragOffset = Offset.zero;
            _activeHandleIndex = null;
            _isRotating = false;
            _refreshSelectionRect();
          });
          _notifySelectionChanged();
          return;
        }
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
    // Block interaction if selection contains locked items
    if (_isSelectionLocked()) return;

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
    if (_lastCanvasSize == null) return;
    final size = _lastCanvasSize!;

    if (_isRotating) {
      if (_rotationAngle != 0.0) {
        // Normalize rotation center
        final normalizedCenter = Offset(
          _rotationCenter!.dx / size.width,
          _rotationCenter!.dy / size.height,
        );
        widget.onStrokesRotated?.call(_selectedIndices, _rotationAngle, normalizedCenter);
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
        // Normalize scale pivot
        final normalizedPivot = Offset(
          _scalePivot!.dx / size.width,
          _scalePivot!.dy / size.height,
        );
        widget.onStrokesScaled?.call(_selectedIndices, _scaleX, _scaleY, normalizedPivot);
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
        // Normalize drag offset
        final normalizedOffset = Offset(
          _currentDragOffset!.dx / size.width,
          _currentDragOffset!.dy / size.height,
        );
        widget.onStrokesMoved?.call(_selectedIndices, normalizedOffset);
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
      if (_selectedIndices.isEmpty || (_selectionRect!.width < 5 && _selectionRect!.height < 5)) {
        _clearSelection();
      } else {
        _notifySelectionChanged();
      }
    }
  }

  void _notifySelectionChanged() {
    if (_selectedIndices.isNotEmpty) {
      _previouslyMovedIndices.addAll(_selectedIndices);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSelectionChanged?.call(_selectionRect, _selectedIndices);
      }
    });
  }

  bool _isSelectionLocked() {
    if (_selectedIndices.isEmpty) return false;
    return _selectedIndices.any((idx) => idx < widget.strokes.length && widget.strokes[idx].isLocked);
  }

  void _refreshSelectionRect() {
    if (_selectedIndices.isEmpty || _lastCanvasSize == null) {
      _selectionRect = null;
      return;
    }
    
    final size = _lastCanvasSize!;
    Rect? newRect;
    for (final index in _selectedIndices) {
      if (index < widget.strokes.length) {
        final normBox = widget.strokes[index].boundingBox;
        final pixelBox = Rect.fromLTRB(
          normBox.left * size.width,
          normBox.top * size.height,
          normBox.right * size.width,
          normBox.bottom * size.height,
        );
        newRect = newRect == null ? pixelBox : newRect.expandToInclude(pixelBox);
      }
    }

    // Ignore 0-size / micro selection boxes (less than 6px width or height)
    if (newRect != null && (newRect.width < 6.0 && newRect.height < 6.0)) {
      _selectionRect = null;
      _selectedIndices = [];
    } else {
      _selectionRect = newRect;
    }
  }

  bool _isPointNearStroke(Offset point, DrawingStroke stroke, double maxDistance) {
    if (stroke.points.isEmpty) return false;

    // Vector Shapes Bounding Box & Border Hit Test
    if (stroke.tool == DrawingTool.shape || stroke.shapeType != null) {
      if (stroke.points.length >= 2) {
        final shapeRect = Rect.fromPoints(stroke.points.first, stroke.points.last).inflate(maxDistance);
        if (shapeRect.contains(point)) return true;
      }
    }

    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p1 = stroke.points[i];
      final p2 = stroke.points[i + 1];
      if (_distanceToSegment(point, p1, p2) <= maxDistance) {
        return true;
      }
    }
    if (stroke.points.length == 1) {
      return (point - stroke.points.first).distance <= maxDistance;
    }
    return false;
  }

  double _distanceToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v - w).distanceSquared;
    if (l2 == 0) return (p - v).distance;
    final t = (((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2)
        .clamp(0.0, 1.0);
    final projection = Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
    return (p - projection).distance;
  }

  void _updateSelectedIndices() {
    if (_selectionRect == null || _lastCanvasSize == null) return;
    final size = _lastCanvasSize!;
    List<int> indices = [];
    for (int i = 0; i < widget.strokes.length; i++) {
      final normBox = widget.strokes[i].boundingBox;
      final pixelBox = Rect.fromLTRB(
        normBox.left * size.width,
        normBox.top * size.height,
        normBox.right * size.width,
        normBox.bottom * size.height,
      );
      if (_selectionRect!.overlaps(pixelBox)) {
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
  final DusterType dusterType;
  final double dusterAngle;
  final LaserMode selectedLaserMode;
  final Color laserColor;
  final double spotlightRadius;
  final List<_LaserPoint> laserPoints;
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
  final bool isSelectionLocked;

  DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
    required this.eraserWidth,
    required this.tool,
    this.dusterType = DusterType.feltBlock,
    this.dusterAngle = 0.0,
    this.selectedLaserMode = LaserMode.laserDot,
    this.laserColor = Colors.redAccent,
    this.spotlightRadius = 100.0,
    this.laserPoints = const [],
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
    this.isSelectionLocked = false,
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

    // Draw Realistic Duster Cursor Preview
    if (tool == DrawingTool.eraser && hoverPosition != null) {
      _drawDusterCursor(canvas, hoverPosition!, eraserWidth, dusterType, dusterAngle);
    }

    // Draw Laser Pointer or Torch Spotlight
    if (tool == DrawingTool.laserPointer) {
      if (selectedLaserMode == LaserMode.laserDot) {
        _drawLaserPointerTrail(canvas, size);
      } else if (selectedLaserMode == LaserMode.spotlight) {
        _drawTorchSpotlight(canvas, size);
      }
    }
  }

  void _drawLaserPointerTrail(Canvas canvas, Size size) {
    final now = DateTime.now();

    final validPoints = laserPoints.where((p) {
      return now.difference(p.timestamp).inMilliseconds <= 700;
    }).toList();

    if (validPoints.length >= 2) {
      final path = Path()..moveTo(validPoints.first.position.dx, validPoints.first.position.dy);
      for (int i = 1; i < validPoints.length; i++) {
        final p = validPoints[i].position;
        final prev = validPoints[i - 1].position;
        final mid = Offset((prev.dx + p.dx) / 2, (prev.dy + p.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }

      // 1. Soft Outer Neon Glow Stroke
      final outerGlowPaint = Paint()
        ..color = laserColor.withOpacity(0.4)
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(path, outerGlowPaint);

      // 2. Solid Laser Main Color Stroke
      final mainStrokePaint = Paint()
        ..color = laserColor
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, mainStrokePaint);

      // 3. Crisp Inner White Core Beam Line
      final coreLinePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, coreLinePaint);
    }

    // Sleek Laser Pointer Tip Cursor
    if (hoverPosition != null) {
      final outerGlow = Paint()
        ..color = laserColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(hoverPosition!, 10.0, outerGlow);

      final mainColorDot = Paint()..color = laserColor;
      canvas.drawCircle(hoverPosition!, 6.0, mainColorDot);

      final centerWhiteCore = Paint()..color = Colors.white;
      canvas.drawCircle(hoverPosition!, 2.5, centerWhiteCore);
    }
  }

  void _drawTorchSpotlight(Canvas canvas, Size size) {
    if (hoverPosition == null) return;
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Dark ambient overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withOpacity(0.68),
    );

    // Clear aperture
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(hoverPosition!, spotlightRadius, clearPaint);

    canvas.restore();

    // Glowing border ring
    final ringPaint = Paint()
      ..color = Colors.amber.shade600.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(hoverPosition!, spotlightRadius, ringPaint);
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

    if (isSelectionLocked) {
      // Draw lock icon in top-left
      final lockCenter = rect.topLeft;
      final knobPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
      final knobBorderPaint = Paint()..color = Colors.red.shade400..style = PaintingStyle.stroke..strokeWidth = 1.5;
      
      canvas.drawCircle(lockCenter, 12, knobPaint);
      canvas.drawCircle(lockCenter, 12, knobBorderPaint);

      final lockIconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.lock.codePoint),
          style: TextStyle(
            fontSize: 16,
            fontFamily: Icons.lock.fontFamily,
            package: Icons.lock.fontPackage,
            color: Colors.red.shade700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      lockIconPainter.paint(canvas, lockCenter - Offset(lockIconPainter.width/2, lockIconPainter.height/2));
      return; // Stop drawing other handles
    }

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

    if (stroke.tool == DrawingTool.shape || stroke.shapeType != null) {
      _drawShape(canvas, stroke);
      return;
    }

    if (stroke.tool == DrawingTool.eraser &&
        (stroke.dusterType == DusterType.feltBlock ||
         stroke.dusterType == DusterType.sponge ||
         stroke.dusterType == DusterType.handDuster)) {
      _drawDirectionalBlockEraser(canvas, stroke);
      return;
    }

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

  void _drawShape(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.length < 2) return;
    final p1 = stroke.points.first;
    final p2 = stroke.points.last;
    final rect = Rect.fromPoints(p1, p2);

    final strokePaint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
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
        final path = _createStarPath(rect);
        if (fillPaint != null) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case ShapeType.line:
        canvas.drawLine(p1, p2, strokePaint);
        break;

      case ShapeType.arrow:
        _drawArrowLine(canvas, p1, p2, strokePaint);
        break;

      case ShapeType.coordinateAxes:
        _drawCoordinateAxes(canvas, rect, strokePaint);
        break;

      case ShapeType.cube:
        _draw3DCube(canvas, rect, strokePaint, fillPaint);
        break;
    }
  }

  Path _createStarPath(Rect rect) {
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

  void _drawArrowLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
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

  void _drawCoordinateAxes(Canvas canvas, Rect rect, Paint paint) {
    final origin = Offset(rect.left, rect.bottom);
    // X-Axis
    _drawArrowLine(canvas, origin, Offset(rect.right, origin.dy), paint);
    // Y-Axis
    _drawArrowLine(canvas, origin, Offset(origin.dx, rect.top), paint);
  }

  void _draw3DCube(Canvas canvas, Rect rect, Paint strokePaint, Paint? fillPaint) {
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

  void _drawDirectionalBlockEraser(Canvas canvas, DrawingStroke stroke) {
    double blockW = stroke.width * 1.5;
    double blockH = stroke.width * 1.0;
    if (stroke.dusterType == DusterType.feltBlock) {
      blockW = stroke.width * 1.8;
      blockH = stroke.width * 0.9;
    } else if (stroke.dusterType == DusterType.handDuster) {
      blockW = stroke.width * 1.6;
      blockH = stroke.width * 1.2;
    }

    final paint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p1 = stroke.points[i];
      final p2 = stroke.points[i + 1];
      final delta = p2 - p1;
      final dist = delta.distance;
      if (dist < 0.1) continue;

      final angle = math.atan2(delta.dy, delta.dx);
      final step = math.max(2.0, blockH * 0.2);
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

  void _drawDusterCursor(Canvas canvas, Offset center, double size, DusterType type, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (type == DusterType.feltBlock || type == DusterType.sponge || type == DusterType.handDuster) {
      canvas.rotate(angle);
    }

    switch (type) {
      case DusterType.feltBlock:
        // 2:1 Rectangular Felt Duster Block
        final double width = size * 1.8;
        final double height = size * 0.9;
        final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);

        // Drop shadow
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.shift(const Offset(2, 3)), const Radius.circular(6)),
          Paint()
            ..color = Colors.black26
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );

        // Felt Layer (dark felt bottom)
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = const Color(0xFF3E2723),
        );

        // Wooden Handle Top Layer
        final topRect = Rect.fromLTWH(-width / 2, -height / 2, width, height * 0.7);
        canvas.drawRRect(
          RRect.fromRectAndRadius(topRect, const Radius.circular(5)),
          Paint()..color = const Color(0xFFD7CCC8),
        );

        // Wooden Grain Accent Line
        final accentRect = Rect.fromLTWH(-width * 0.3, -height * 0.35, width * 0.6, height * 0.25);
        canvas.drawRRect(
          RRect.fromRectAndRadius(accentRect, const Radius.circular(3)),
          Paint()..color = const Color(0xFFA1887F),
        );

        // Outer Border
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()
            ..color = Colors.amber.shade900
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        break;

      case DusterType.sponge:
        // Rounded Microfiber / Sponge Block
        final double width = size * 1.5;
        final double height = size * 1.0;
        final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);

        // Shadow
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.shift(const Offset(2, 3)), const Radius.circular(12)),
          Paint()
            ..color = Colors.black26
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );

        // Sponge Base (Teal/Cyan Sponge)
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)),
          Paint()..color = Colors.teal.shade300,
        );

        // Sponge Top Layer
        final innerRect = rect.deflate(3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(innerRect, const Radius.circular(9)),
          Paint()..color = Colors.teal.shade100,
        );

        // Texture Dots
        final dotPaint = Paint()..color = Colors.teal.shade600;
        canvas.drawCircle(const Offset(-10, -5), 2.5, dotPaint);
        canvas.drawCircle(const Offset(8, -8), 2.0, dotPaint);
        canvas.drawCircle(const Offset(-4, 6), 3.0, dotPaint);
        canvas.drawCircle(const Offset(12, 4), 2.2, dotPaint);

        // Outer Border
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)),
          Paint()
            ..color = Colors.teal.shade800
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        break;

      case DusterType.handDuster:
        // No graphic cursor drawn for real physical hand/palm
        break;

      case DusterType.precision:
        // Precision Circular Tip Eraser
        final radius = size / 2;
        // Outer Shadow Circle
        canvas.drawCircle(
          const Offset(1, 2),
          radius,
          Paint()
            ..color = Colors.black26
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        // Circle Fill
        canvas.drawCircle(
          Offset.zero,
          radius,
          Paint()..color = Colors.indigo.withOpacity(0.2),
        );
        // Circle Border
        canvas.drawCircle(
          Offset.zero,
          radius,
          Paint()
            ..color = Colors.indigo
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        // Center Dot
        canvas.drawCircle(Offset.zero, 2.0, Paint()..color = Colors.indigo);
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return true;
  }
}

DrawingStroke _scaleStrokeToPixels(DrawingStroke stroke, Size size) {
  // Scale width relative to a 1920px standard for consistent boldness
  final double widthScale = size.width / 1920.0;
  return DrawingStroke(
    points: stroke.points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList(),
    color: stroke.color,
    width: stroke.width * widthScale,
    tool: stroke.tool,
    dusterType: stroke.dusterType,
    strokeAngle: stroke.strokeAngle,
    isLocked: stroke.isLocked,
    shapeType: stroke.shapeType,
    fillColor: stroke.fillColor,
  );
}