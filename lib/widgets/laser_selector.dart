import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';

class LaserPointerToolbar extends StatelessWidget {
  final LaserMode selectedMode;
  final Color laserColor;
  final double spotlightRadius;
  final Function(LaserMode) onModeChanged;
  final Function(Color) onColorChanged;
  final Function(double) onRadiusChanged;

  static const List<Color> laserColors = [
    Color(0xFFFF2D55), // Neon Red
    Color(0xFF00E676), // Neon Green
    Color(0xFF00E5FF), // Neon Cyan
    Color(0xFFFFD600), // Neon Amber
  ];

  const LaserPointerToolbar({
    Key? key,
    required this.selectedMode,
    required this.laserColor,
    required this.spotlightRadius,
    required this.onModeChanged,
    required this.onColorChanged,
    required this.onRadiusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSpotlight = selectedMode == LaserMode.spotlight;

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
        children: [
          // Row 1: Compact Segmented Mode Controls
          Row(
            children: [
              Expanded(
                child: _buildSegmentButton(
                  context: context,
                  mode: LaserMode.laserDot,
                  label: 'Laser Pointer',
                  icon: Icons.flare,
                  activeColor: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSegmentButton(
                  context: context,
                  mode: LaserMode.spotlight,
                  label: 'Torch Spotlight',
                  icon: Icons.wb_sunny_outlined,
                  activeColor: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Dynamic Mode Controls (Color or Spotlight Size)
          if (!isSpotlight) ...[
            Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  size: 14,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  'Laser Glow Color:',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: laserColors.map((color) {
                    final isSelected = laserColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => onColorChanged(color),
                      child: Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 5)]
                              : const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.center_focus_strong,
                  size: 14,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  'Spotlight Size',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    ),
                    child: Slider(
                      value: spotlightRadius,
                      min: 40.0,
                      max: 200.0,
                      activeColor: Colors.amber.shade800,
                      inactiveColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      onChanged: onRadiusChanged,
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252536) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '${spotlightRadius.toInt()}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required BuildContext context,
    required LaserMode mode,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = selectedMode == mode;

    final btnBg = isSelected
        ? activeColor.withOpacity(isDark ? 0.25 : 0.12)
        : (isDark ? const Color(0xFF252536) : Colors.grey.shade100);
    final borderColor = isSelected
        ? activeColor
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final textColor = isSelected
        ? activeColor
        : (isDark ? Colors.grey.shade300 : Colors.grey.shade800);

    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: textColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
