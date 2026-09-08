import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';

class TextFormattingDialog extends StatelessWidget {
  final DrawingText element;
  final Function(DrawingText) onChanged;
  final VoidCallback onClose;

  const TextFormattingDialog({
    Key? key,
    required this.element,
    required this.onChanged,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.title, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                Text('Text Styles', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(),
            _buildFontRow(),
            const SizedBox(height: 12),
            _buildStyleRow(),
            const SizedBox(height: 12),
            _buildAlignmentRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildFontRow() {
    final List<double> standardSizes = [12, 16, 24, 32, 48, 64, 72];
    final double currentSize = element.fontSize;
    
    // Use a Set to ensure unique values and that currentSize is definitely included
    final Set<double> dropdownSizes = standardSizes.toSet();
    dropdownSizes.add(currentSize);
    
    final List<double> sortedSizes = dropdownSizes.toList()..sort();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: element.fontFamily,
                isExpanded: true,
                items: ['Roboto', 'Poppins', 'Open Sans', 'Lato']
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) onChanged(element.copyWith(fontFamily: val));
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: currentSize,
                isExpanded: true,
                items: sortedSizes
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s.toInt()}', style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) onChanged(element.copyWith(fontSize: val));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildToggle(Icons.format_bold, element.isBold, (val) => onChanged(element.copyWith(isBold: val))),
        _buildToggle(Icons.format_italic, element.isItalic, (val) => onChanged(element.copyWith(isItalic: val))),
        _buildToggle(Icons.format_underlined, element.isUnderlined, (val) => onChanged(element.copyWith(isUnderlined: val))),
        const VerticalDivider(),
        _buildColorPicker(),
      ],
    );
  }

  Widget _buildAlignmentRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAlignOption(Icons.format_align_left, TextAlign.left),
        _buildAlignOption(Icons.format_align_center, TextAlign.center),
        _buildAlignOption(Icons.format_align_right, TextAlign.right),
        _buildAlignOption(Icons.format_align_justify, TextAlign.justify),
      ],
    );
  }

  Widget _buildToggle(IconData icon, bool active, Function(bool) onChanged) {
    return IconButton(
      icon: Icon(icon, color: active ? Colors.indigo : Colors.grey),
      onPressed: () => onChanged(!active),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _buildAlignOption(IconData icon, TextAlign align) {
    bool active = element.alignment == align;
    return IconButton(
      icon: Icon(icon, color: active ? Colors.indigo : Colors.grey),
      onPressed: () => onChanged(element.copyWith(alignment: align)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _buildColorPicker() {
    return GestureDetector(
      onTap: () {
        // Here we could open a full color picker, but for simplicity let's toggle between a few
        final colors = [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange];
        int current = colors.indexOf(element.color);
        onChanged(element.copyWith(color: colors[(current + 1) % colors.length]));
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: element.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
