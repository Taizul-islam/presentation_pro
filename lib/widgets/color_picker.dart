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

  bool get _isLightColor => _selectedColor.computeLuminance() > 0.5;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 16,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Color Preview & Hex Chip
            Container(
              width: double.infinity,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.color_lens_outlined,
                        size: 18,
                        color: _isLightColor ? Colors.black87 : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hexString,
                        style: GoogleFonts.poppins(
                          color: _isLightColor ? Colors.black87 : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _hexString));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Color code $_hexString copied!'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: _isLightColor ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Preset Palette Swatches
            Text(
              'Presets',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetColors.map((color) {
                final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.indigo : Colors.grey.shade300,
                        width: isSelected ? 3.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.indigo.withOpacity(0.3),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : const [
                              BoxShadow(color: Colors.black12, blurRadius: 2)
                            ],
                    ),
                    child: isSelected
                        ? Center(
                            child: Icon(
                              Icons.check,
                              size: 14,
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
            const SizedBox(height: 16),

            // 2D Saturation / Value Gradient Canvas
            Text(
              'Saturation & Brightness',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            _buildSatValBox(),
            const SizedBox(height: 16),

            // Rainbow Hue Slider
            Text(
              'Hue',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            _buildHueSlider(),
            const SizedBox(height: 20),

            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => widget.onColorSelected(_selectedColor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Apply Color',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

  Widget _buildSatValBox() {
    final hsv = HSVColor.fromColor(_selectedColor);
    const height = 150.0;

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

        final cursorLeft = (hsv.saturation * width - 10.0).clamp(0.0, width - 20.0);
        final cursorTop = ((1.0 - hsv.value) * height - 10.0).clamp(0.0, height - 20.0);

        return GestureDetector(
          onPanDown: (details) => updateColor(details.localPosition),
          onPanUpdate: (details) => updateColor(details.localPosition),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  // Hue Base Color
                  Container(
                    color: HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor(),
                  ),
                  // Saturation White Gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.white, Colors.transparent],
                      ),
                    ),
                  ),
                  // Value Black Gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                  // Cursor Indicator
                  Positioned(
                    left: cursorLeft,
                    top: cursorTop,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedColor,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 4)
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

  Widget _buildHueSlider() {
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

        // Padded thumb offset so circle stays inside track
        final thumbLeft = ((currentHue / 360.0) * (width - 24.0)).clamp(0.0, width - 24.0);

        return GestureDetector(
          onPanDown: (details) => updateHue(details.localPosition),
          onPanUpdate: (details) => updateHue(details.localPosition),
          child: Container(
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.grey.shade300, width: 1),
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
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HSVColor.fromAHSV(1.0, currentHue, 1.0, 1.0).toColor(),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4)
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
