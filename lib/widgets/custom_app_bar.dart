import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';

class SimpleCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final bool isDrawingMode;
  final bool isToolbarVisible;
  final bool isFullscreen;
  final int currentPage;
  final int totalPages;
  final VoidCallback onDrawingModeToggle;
  final VoidCallback onToolbarToggle;
  final VoidCallback onFullscreenToggle;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  const SimpleCustomAppBar({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.isDrawingMode,
    required this.isToolbarVisible,
    required this.isFullscreen,
    required this.currentPage,
    required this.totalPages,
    required this.onDrawingModeToggle,
    required this.onToolbarToggle,
    required this.onFullscreenToggle,
    required this.onUndo,
    required this.onRedo,
    required this.onPreviousPage,
    required this.onNextPage,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(isFullscreen ? 0 : 56);

  @override
  Widget build(BuildContext context) {
    if (isFullscreen) {
      return SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              // Leading
              IconButton(
                icon: Icon(
                  isDrawingMode ? Icons.close : Icons.menu,
                  size: 22,
                  color: isDrawingMode ? Colors.red : Colors.grey.shade700,
                ),
                onPressed: isDrawingMode ? onDrawingModeToggle : () {
                  Scaffold.of(context).openDrawer();
                },
                tooltip: isDrawingMode ? 'Exit Drawing' : 'Menu',
                visualDensity: VisualDensity.compact,
              ),

              // Title
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Page navigation (compact)
              IconButton(
                icon: Icon(Icons.chevron_left, size: 20),
                onPressed: onPreviousPage,
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous',
              ),
              Text(
                '$currentPage/$totalPages',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, size: 20),
                onPressed: onNextPage,
                visualDensity: VisualDensity.compact,
                tooltip: 'Next',
              ),

              // Actions
              if (isDrawingMode) ...[
                IconButton(
                  icon: Icon(Icons.undo, size: 20),
                  onPressed: onUndo,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Undo',
                ),
                IconButton(
                  icon: Icon(Icons.redo, size: 20),
                  onPressed: onRedo,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Redo',
                ),
                IconButton(
                  icon: Icon(
                    isToolbarVisible ? Icons.keyboard_arrow_down : Icons.palette,
                    size: 20,
                    color: isToolbarVisible ? Colors.indigo : Colors.grey.shade700,
                  ),
                  onPressed: onToolbarToggle,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Toggle Toolbar',
                ),
              ] else ...[
                IconButton(
                  icon: Icon(Icons.fullscreen, size: 20),
                  onPressed: onFullscreenToggle,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Fullscreen',
                ),
                Container(
                  margin: EdgeInsets.only(left: 4),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.draw, size: 16),
                    label: Text('Annotate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: onDrawingModeToggle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}