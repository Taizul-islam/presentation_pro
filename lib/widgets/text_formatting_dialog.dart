import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';
import 'color_picker.dart';

class TextFormattingDialog extends StatelessWidget {
  final DrawingText element;
  final Function(DrawingText) onChanged;
  final VoidCallback onClose;
  final VoidCallback? onDelete;

  const TextFormattingDialog({
    Key? key,
    required this.element,
    required this.onChanged,
    required this.onClose,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white70 : Colors.grey.shade700;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(23),
      color: Colors.transparent,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Icon
            const Icon(Icons.title, size: 18, color: Colors.indigoAccent),
            const SizedBox(width: 8),

            // Font Family Dropdown
            _buildFontDropdown(context, isDark),
            const SizedBox(width: 6),

            // Font Size Dropdown
            _buildFontSizeDropdown(context, isDark),
            VerticalDivider(width: 16, color: dividerColor),

            // Style Toggles (B, I, U)
            _buildToggle(Icons.format_bold, element.isBold,
                (val) => onChanged(element.copyWith(isBold: val)), isDark),
            _buildToggle(Icons.format_italic, element.isItalic,
                (val) => onChanged(element.copyWith(isItalic: val)), isDark),
            _buildToggle(Icons.format_underlined, element.isUnderlined,
                (val) => onChanged(element.copyWith(isUnderlined: val)), isDark),
            VerticalDivider(width: 16, color: dividerColor),

            // Text Color Swatch Circle
            _buildColorPicker(context),
            VerticalDivider(width: 16, color: dividerColor),

            // Alignment Controls
            _buildAlignOption(Icons.format_align_left, TextAlign.left, isDark),
            _buildAlignOption(Icons.format_align_center, TextAlign.center, isDark),
            _buildAlignOption(Icons.format_align_right, TextAlign.right, isDark),
            _buildAlignOption(Icons.format_align_justify, TextAlign.justify, isDark),
            VerticalDivider(width: 16, color: dividerColor),

            // Delete Action Button
            if (onDelete != null) ...[
              Tooltip(
                message: 'Delete Text Box',
                child: IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ),
              const SizedBox(width: 4),
            ],

            // Close Button
            Tooltip(
              message: 'Close Text Styles',
              child: IconButton(
                icon: Icon(Icons.close, size: 16, color: iconColor),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontDropdown(BuildContext context, bool isDark) {
    return Container(
      width: 105,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252536) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ['Roboto', 'Poppins', 'Open Sans', 'Lato'].contains(element.fontFamily)
              ? element.fontFamily
              : 'Roboto',
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: isDark ? Colors.white : Colors.grey.shade800,
          ),
          items: ['Roboto', 'Poppins', 'Open Sans', 'Lato']
              .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(
                      f,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(element.copyWith(fontFamily: val));
          },
        ),
      ),
    );
  }

  Widget _buildFontSizeDropdown(BuildContext context, bool isDark) {
    final List<double> standardSizes = [12, 16, 24, 32, 48, 64, 72];
    final double currentSize = element.fontSize;

    final Set<double> dropdownSizes = standardSizes.toSet();
    dropdownSizes.add(currentSize);
    final List<double> sortedSizes = dropdownSizes.toList()..sort();

    return Container(
      width: 58,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252536) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: currentSize,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.indigoAccent : Colors.indigo,
          ),
          items: sortedSizes
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      '${s.toInt()}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(element.copyWith(fontSize: val));
          },
        ),
      ),
    );
  }

  Widget _buildToggle(IconData icon, bool active, Function(bool) onChanged, bool isDark) {
    return IconButton(
      icon: Icon(
        icon,
        size: 16,
        color: active
            ? (isDark ? Colors.indigoAccent : Colors.indigo)
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
      ),
      onPressed: () => onChanged(!active),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildAlignOption(IconData icon, TextAlign align, bool isDark) {
    bool active = element.alignment == align;
    return IconButton(
      icon: Icon(
        icon,
        size: 16,
        color: active
            ? (isDark ? Colors.indigoAccent : Colors.indigo)
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
      ),
      onPressed: () => onChanged(element.copyWith(alignment: align)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildColorPicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final newColor = await SmartColorPickerDialog.show(
          context: context,
          initialColor: element.color,
          title: 'Text Color',
          icon: Icons.format_color_fill,
        );
        if (newColor != null) {
          onChanged(element.copyWith(color: newColor));
        }
      },
      child: Tooltip(
        message: 'Text Color',
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: element.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
          ),
        ),
      ),
    );
  }
}
