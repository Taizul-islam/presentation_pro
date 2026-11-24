import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SmartColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;
  final IconData icon;
  final Function(Color) onColorSelected;

  const SmartColorPickerDialog({
    Key? key,
    required this.initialColor,
    required this.title,
    this.icon = Icons.palette_outlined,
    required this.onColorSelected,
  }) : super(key: key);

  static Future<Color?> show({
    required BuildContext context,
    required Color initialColor,
    required String title,
    IconData icon = Icons.palette_outlined,
  }) {
    return showDialog<Color>(
      context: context,
      builder: (dialogContext) => SmartColorPickerDialog(
        initialColor: initialColor,
        title: title,
        icon: icon,
        onColorSelected: (selectedColor) {
          Navigator.pop(dialogContext, selectedColor);
        },
      ),
    );
  }

  @override
  _SmartColorPickerDialogState createState() => _SmartColorPickerDialogState();
}

class _SmartColorPickerDialogState extends State<SmartColorPickerDialog> {
  late Color _selectedColor;

  static const List<Color> _presetColors = [
    Color(0xFFF44336), // Red
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF3F51B5), // Indigo
    Color(0xFF2196F3), // Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFFFFC107), // Amber
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF212121), // Charcoal
    Color(0xFFFFFFFF), // White
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  String get _hexString {
    final argb = _selectedColor.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${argb.substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey.shade800;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 16,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Swatch + Title + Hex Badge + Close
            Row(
              children: [
                // Live Color Swatch Indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildHexBadge(context, isDark),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            const SizedBox(height: 12),

            // Preset Swatches
            Text(
              'Presets',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _presetColors.map((color) {
                final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Colors.indigoAccent
                            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        width: isSelected ? 2.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.indigo.withOpacity(0.4),
                                blurRadius: 4,
                              )
                            ]
                          : const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                    ),
                    child: isSelected
                        ? Center(
                            child: Icon(
                              Icons.check,
                              size: 12,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black87
                                  : Colors.white,
                            ),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // 2D Saturation & Brightness Canvas
            Text(
              'Saturation & Brightness',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 6),
            _buildSatValBox(borderColor),
            const SizedBox(height: 12),

            // Rainbow Hue Slider
            Text(
              'Hue',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 6),
            _buildHueSlider(borderColor),
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => widget.onColorSelected(_selectedColor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Apply Color',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHexBadge(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: _hexString));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252536) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _hexString,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy_rounded,
              size: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSatValBox(Color borderColor) {
    final hsv = HSVColor.fromColor(_selectedColor);
    const height = 120.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void updateColor(Offset localPosition) {
          final dx = (localPosition.dx / width).clamp(0.0, 1.0);
          final dy = (localPosition.dy / height).clamp(0.0, 1.0);
          final newColor =
              HSVColor.fromAHSV(1.0, hsv.hue, dx, 1.0 - dy).toColor();
          setState(() => _selectedColor = newColor);
        }

        final cursorLeft = (hsv.saturation * width - 9.0).clamp(0.0, width - 18.0);
        final cursorTop = ((1.0 - hsv.value) * height - 9.0).clamp(0.0, height - 18.0);

        return GestureDetector(
          onPanDown: (details) => updateColor(details.localPosition),
          onPanUpdate: (details) => updateColor(details.localPosition),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  Container(
                    color: HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor(),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.white, Colors.transparent],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                  Positioned(
                    left: cursorLeft,
                    top: cursorTop,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedColor,
                        border: Border.all(color: Colors.white, width: 2.0),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 3)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHueSlider(Color borderColor) {
    final currentHue = HSVColor.fromColor(_selectedColor).hue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void updateHue(Offset localPosition) {
          final hue = (localPosition.dx / width * 360.0).clamp(0.0, 360.0);
          final hsv = HSVColor.fromColor(_selectedColor);
          final newColor =
              HSVColor.fromAHSV(1.0, hue, hsv.saturation, hsv.value).toColor();
          setState(() => _selectedColor = newColor);
        }

        final thumbLeft = ((currentHue / 360.0) * (width - 20.0)).clamp(0.0, width - 20.0);

        return GestureDetector(
          onPanDown: (details) => updateHue(details.localPosition),
          onPanUpdate: (details) => updateHue(details.localPosition),
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
              gradient: const LinearGradient(
                colors: [
                  Colors.red,
                  Colors.yellow,
                  Colors.green,
                  Colors.cyan,
                  Colors.blue,
                  Colors.purple,
                  Colors.red,
                ],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: thumbLeft,
                  top: -1,
                  bottom: -1,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HSVColor.fromAHSV(1.0, currentHue, 1.0, 1.0).toColor(),
                      border: Border.all(color: Colors.white, width: 2.0),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
