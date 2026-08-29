  import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';

class DrawingToolbar extends StatefulWidget {
  final Color selectedColor;
  final double strokeWidth;
  final DrawingTool selectedTool;
  final Function(Color) onColorChanged;
  final Function(double) onStrokeWidthChanged;
  final Function(DrawingTool) onToolChanged;
  final Function() onUndo;
  final Function() onRedo;
  final Function() onClear;
  final Function() onClose;

  const DrawingToolbar({
    Key? key,
    required this.selectedColor,
    required this.strokeWidth,
    required this.selectedTool,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onToolChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onClose,
  }) : super(key: key);

  @override
  State<DrawingToolbar> createState() => _DrawingToolbarState();
}

class _DrawingToolbarState extends State<DrawingToolbar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final bottomNavHeight = 120.0; // Increased for bottom slider
    final availableHeight = screenHeight - appBarHeight - bottomNavHeight - 20;

    return Container(
      width: 80,
      height: availableHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 4,
          radius: Radius.circular(2),
          scrollbarOrientation: ScrollbarOrientation.right,
          child: SingleChildScrollView(
            controller: _scrollController,
            primary: false,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    'Tools',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Tools
                  _buildToolButton(
                    icon: Icons.edit,
                    label: 'Pen',
                    tool: DrawingTool.pen,
                  ),
                  SizedBox(height: 6),
                  _buildToolButton(
                    icon: Icons.border_color,
                    label: 'Highlight',
                    tool: DrawingTool.highlighter,
                  ),
                  SizedBox(height: 6),
                  _buildToolButton(
                    icon: Icons.auto_fix_high,
                    label: 'Eraser',
                    tool: DrawingTool.eraser,
                  ),

                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 12),

                  // Colors section
                  Text(
                    'Colors',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(height: 8),
                  ..._getColors().map((color) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: GestureDetector(
                        onTap: () => widget.onColorChanged(color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.selectedColor == color
                                  ? Colors.indigo
                                  : Colors.grey.shade300,
                              width: widget.selectedColor == color ? 3 : 1,
                            ),
                            boxShadow: widget.selectedColor == color
                                ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 12),

                  // Actions section
                  Text(
                    'Actions',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.undo,
                    tooltip: 'Undo',
                    onTap: widget.onUndo,
                  ),
                  SizedBox(height: 6),
                  _buildActionButton(
                    icon: Icons.redo,
                    tooltip: 'Redo',
                    onTap: widget.onRedo,
                  ),
                  SizedBox(height: 6),
                  _buildActionButton(
                    icon: Icons.delete,
                    tooltip: 'Clear',
                    onTap: widget.onClear,
                  ),
                  SizedBox(height: 6),
                  _buildActionButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onTap: widget.onClose,
                    isClose: true,
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getColors() {
    return [
      Colors.black,
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.white,
    ];
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required DrawingTool tool,
  }) {
    final isSelected = widget.selectedTool == tool;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => widget.onToolChanged(tool),
        child: Container(
          width: 56,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: Colors.indigo.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isClose = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isClose ? Colors.red.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isClose ? Colors.red.shade200 : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isClose ? Colors.red : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
