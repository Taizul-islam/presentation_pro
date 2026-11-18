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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.transparent,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Mode Selection Cards
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  mode: LaserMode.laserDot,
                  title: 'Laser Pointer',
                  subtitle: 'Fading laser trail',
                  icon: Icons.flare,
                  activeColor: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeCard(
                  mode: LaserMode.spotlight,
                  title: 'Torch Spotlight',
                  subtitle: 'Focus beam on slide',
                  icon: Icons.wb_sunny_outlined,
                  activeColor: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Row 2: Settings (Color or Spotlight Radius)
          if (!isSpotlight) ...[
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 15, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  'Laser Glow Color:',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: laserColors.map((color) {
                    final isSelected = laserColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => onColorChanged(color),
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.indigo : Colors.grey.shade300,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)]
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
                Icon(Icons.center_focus_strong, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  'Spotlight Size',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: spotlightRadius,
                      min: 40.0,
                      max: 200.0,
                      activeColor: Colors.amber.shade800,
                      inactiveColor: Colors.grey.shade200,
                      onChanged: onRadiusChanged,
                    ),
                  ),
                ),
                Container(
                  width: 38,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${spotlightRadius.toInt()}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
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

  Widget _buildModeCard({
    required LaserMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = selectedMode == mode;

    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? activeColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? activeColor : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
