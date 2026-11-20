import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';

class ShapesToolbar extends StatelessWidget {
  final ShapeType selectedShape;
  final Color? fillColor;
  final Function(ShapeType) onShapeChanged;
  final Function(Color?) onFillColorChanged;

  const ShapesToolbar({
    Key? key,
    required this.selectedShape,
    this.fillColor,
    required this.onShapeChanged,
    required this.onFillColorChanged,
  }) : super(key: key);

  static const List<_ShapeOption> _shapeOptions = [
    _ShapeOption(ShapeType.rectangle, 'Rectangle', Icons.rectangle_outlined),
    _ShapeOption(ShapeType.circle, 'Circle', Icons.circle_outlined),
    _ShapeOption(ShapeType.triangle, 'Triangle', Icons.change_history),
    _ShapeOption(ShapeType.diamond, 'Diamond', Icons.diamond_outlined),
    _ShapeOption(ShapeType.star, 'Star', Icons.star_outline),
    _ShapeOption(ShapeType.line, 'Line', Icons.horizontal_rule),
    _ShapeOption(ShapeType.arrow, 'Vector Arrow', Icons.east),
    _ShapeOption(ShapeType.coordinateAxes, 'X-Y Graph', Icons.grid_3x3),
    _ShapeOption(ShapeType.cube, '3D Cube', Icons.view_in_ar),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 440,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Label
          Row(
            children: [
              Icon(
                Icons.shapes_outlined,
                size: 14,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Geometric Shapes & Vectors',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Shape Choice Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _shapeOptions.map((opt) {
              final isSelected = selectedShape == opt.type;
              final chipBg = isSelected
                  ? Colors.indigo.withOpacity(isDark ? 0.25 : 0.12)
                  : (isDark ? const Color(0xFF252536) : Colors.grey.shade100);
              final borderColor = isSelected
                  ? Colors.indigoAccent
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
              final textColor = isSelected
                  ? (isDark ? Colors.indigoAccent : Colors.indigo)
                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade800);

              return InkWell(
                onTap: () => onShapeChanged(opt.type),
                borderRadius: BorderRadius.circular(8),
                child: Tooltip(
                  message: opt.label,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(opt.icon, size: 14, color: textColor),
                        const SizedBox(width: 4),
                        Text(
                          opt.label,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ShapeOption {
  final ShapeType type;
  final String label;
  final IconData icon;

  const _ShapeOption(this.type, this.label, this.icon);
}
