import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';

class DrawingTextWidget extends StatefulWidget {
  final DrawingText element;
  final bool isSelected;
  final Function(String) onTextChanged;
  final Function(Offset) onPositionChanged;
  final Function(double) onWidthChanged;
  final Function(double width, double fontSize)? onScaleChanged;
  final VoidCallback? onInteractionStart;
  final VoidCallback onTap;

  const DrawingTextWidget({
    Key? key,
    required this.element,
    required this.isSelected,
    required this.onTextChanged,
    required this.onPositionChanged,
    required this.onWidthChanged,
    this.onScaleChanged,
    this.onInteractionStart,
    required this.onTap,
  }) : super(key: key);

  @override
  _DrawingTextWidgetState createState() => _DrawingTextWidgetState();
}

class _DrawingTextWidgetState extends State<DrawingTextWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  // Interaction start state
  double _startWidth = 0.0;
  double _startFontSize = 0.0;
  Offset _startGlobalPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.element.text);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    if (widget.isSelected) {
      _focusNode.requestFocus();
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      widget.onTap();
    }
  }

  @override
  void didUpdateWidget(DrawingTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.element.text != _controller.text) {
      _controller.text = widget.element.text;
    }
    if (widget.isSelected && !oldWidget.isSelected) {
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double padding = 40.0;
    return Positioned(
      left: widget.element.position.dx - padding,
      top: widget.element.position.dy - padding,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: widget.element.width + (padding * 2),
          // We use a transparent background to ensure hit testing works across the entire area
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // This column naturally sizes itself to the text height
              Padding(
                padding: const EdgeInsets.all(padding),
                child: Container(
                  decoration: BoxDecoration(
                    border: widget.isSelected
                        ? Border.all(color: Colors.blue.withOpacity(0.5), width: 1)
                        : null,
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    style: _getTextStyle(),
                    textAlign: widget.element.alignment,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.all(4),
                    ),
                    onChanged: widget.onTextChanged,
                  ),
                ),
              ),
              if (widget.isSelected) ...[
                // Side handles - Placed relative to the edges of the box
                // Left circle
                Positioned(
                  left: padding - 12,
                  top: padding,
                  bottom: padding,
                  child: Center(
                    child: _buildHandle(
                      onStart: (details) {
                        _startWidth = widget.element.width;
                        _startGlobalPos = details.globalPosition;
                        widget.onInteractionStart?.call();
                      },
                      onUpdate: (details) {
                        double totalDeltaX = details.globalPosition.dx - _startGlobalPos.dx;
                        
                        // Width should be start width minus the total distance moved
                        double newWidth = (_startWidth - totalDeltaX).clamp(40.0, 2000.0);
                        
                        // To correctly resize from the left, we must move the box's position 
                        // by EXACTLY the amount the width changed.
                        // We use the frame-by-frame delta for the position change.
                        widget.onPositionChanged(Offset(details.delta.dx, 0)); 
                        widget.onWidthChanged(newWidth);
                      },
                    ),
                  ),
                ),
                // Right circle
                Positioned(
                  right: padding - 12,
                  top: padding,
                  bottom: padding,
                  child: Center(
                    child: _buildHandle(
                      onStart: (details) {
                        _startWidth = widget.element.width;
                        _startGlobalPos = details.globalPosition;
                        widget.onInteractionStart?.call();
                      },
                      onUpdate: (details) {
                        double totalDeltaX = details.globalPosition.dx - _startGlobalPos.dx;
                        double newWidth = (_startWidth + totalDeltaX).clamp(40.0, 2000.0);
                        widget.onWidthChanged(newWidth);
                      },
                    ),
                  ),
                ),
                // Bottom right scale handle (triangle)
                Positioned(
                  right: padding - 20,
                  bottom: padding - 20,
                  child: GestureDetector(
                    onPanStart: (details) {
                      _startWidth = widget.element.width;
                      _startFontSize = widget.element.fontSize;
                      _startGlobalPos = details.globalPosition;
                      widget.onInteractionStart?.call();
                    },
                    onPanUpdate: (details) {
                      if (widget.onScaleChanged != null) {
                        double deltaX = details.globalPosition.dx - _startGlobalPos.dx;
                        double deltaY = details.globalPosition.dy - _startGlobalPos.dy;
                        
                        // Combined delta for responsive growth
                        double totalDelta = (deltaX + deltaY);
                        
                        double newWidth = (_startWidth + totalDelta).clamp(40.0, 2000.0);
                        double scale = newWidth / _startWidth;
                        double newFontSize = (_startFontSize * scale).clamp(8.0, 500.0);
                        
                        widget.onScaleChanged!(newWidth, newFontSize);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: CustomPaint(
                        painter: TrianglePainter(),
                        size: const Size(20, 20),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle({
    required Function(DragStartDetails) onStart,
    required Function(DragUpdateDetails) onUpdate,
  }) {
    return GestureDetector(
      onPanStart: onStart,
      onPanUpdate: onUpdate,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        color: Colors.transparent, // Expansion for hit testing
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
          ),
        ),
      ),
    );
  }

  TextStyle _getTextStyle() {
    try {
      return GoogleFonts.getFont(
        widget.element.fontFamily,
        fontSize: widget.element.fontSize,
        fontWeight: widget.element.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: widget.element.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: widget.element.isUnderlined ? TextDecoration.underline : TextDecoration.none,
        color: widget.element.color,
      );
    } catch (e) {
      // Fallback to system default if Google Font fails
      return TextStyle(
        fontSize: widget.element.fontSize,
        fontWeight: widget.element.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: widget.element.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: widget.element.isUnderlined ? TextDecoration.underline : TextDecoration.none,
        color: widget.element.color,
      );
    }
  }
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
