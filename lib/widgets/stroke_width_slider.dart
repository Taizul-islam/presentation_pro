import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StrokeWidthSlider extends StatelessWidget {
  final double strokeWidth;
  final Color selectedColor;
  final Function(double) onStrokeWidthChanged;
  final double min;
  final double max;
  final String label;

  const StrokeWidthSlider({
    Key? key,
    required this.strokeWidth,
    required this.selectedColor,
    required this.onStrokeWidthChanged,
    this.min = 1.0,
    this.max = 15.0,
    this.label = 'Stroke Width',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Icon(
            label.contains('Duster') ? Icons.auto_fix_high : Icons.edit,
            size: 14,
            color: label.contains('Duster') ? Colors.orange : selectedColor,
          ),
          SizedBox(width: 8),

          // Label
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(width: 10),

          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: strokeWidth,
                min: min,
                max: max,
                activeColor: label.contains('Duster') ? Colors.orange.shade700 : Colors.indigo,
                inactiveColor: Colors.grey.shade200,
                onChanged: onStrokeWidthChanged,
              ),
            ),
          ),
          SizedBox(width: 8),

          // Width value
          Container(
            width: 40,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${strokeWidth.toInt()}',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: label.contains('Duster') ? Colors.orange.shade800 : Colors.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}