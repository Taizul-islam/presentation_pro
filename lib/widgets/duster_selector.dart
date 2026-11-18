import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';

class RealDusterToolbar extends StatelessWidget {
  final DusterType selectedDusterType;
  final DusterOrientation selectedOrientation;
  final double dusterSize;
  final Function(DusterType) onDusterTypeChanged;
  final Function(DusterOrientation) onOrientationChanged;
  final Function(double) onDusterSizeChanged;
  final VoidCallback onClearSlide;

  const RealDusterToolbar({
    Key? key,
    required this.selectedDusterType,
    required this.selectedOrientation,
    required this.dusterSize,
    required this.onDusterTypeChanged,
    required this.onOrientationChanged,
    required this.onDusterSizeChanged,
    required this.onClearSlide,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showOrientationOptions =
        selectedDusterType == DusterType.feltBlock ||
            selectedDusterType == DusterType.sponge;

    return Container(
      width: 480,
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
          // Row 1: Duster Type Cards
          Row(
            children: [
              Expanded(
                child: _buildDusterTypeCard(
                  context: context,
                  type: DusterType.feltBlock,
                  title: 'Felt Duster',
                  subtitle: 'Classroom felt block',
                  icon: Icons.rectangle_outlined,
                  activeColor: Colors.amber.shade800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDusterTypeCard(
                  context: context,
                  type: DusterType.sponge,
                  title: 'Sponge',
                  subtitle: 'Soft microfiber',
                  icon: Icons.blur_circular,
                  activeColor: Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDusterTypeCard(
                  context: context,
                  type: DusterType.precision,
                  title: 'Precision',
                  subtitle: 'Point eraser',
                  icon: Icons.center_focus_strong,
                  activeColor: Colors.indigo,
                ),
              ),
            ],
          ),

          if (showOrientationOptions) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Row 2: Ergonomic Grip Angle Selector
            Row(
              children: [
                Icon(Icons.pan_tool_outlined, size: 15, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  'Grip Angle:',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildOrientationChip(
                          context: context,
                          orientation: DusterOrientation.rightHand,
                          label: 'Right Hand (15°)',
                          icon: Icons.front_hand,
                        ),
                        const SizedBox(width: 6),
                        _buildOrientationChip(
                          context: context,
                          orientation: DusterOrientation.horizontal,
                          label: 'Horizontal (0°)',
                          icon: Icons.horizontal_rule,
                        ),
                        const SizedBox(width: 6),
                        _buildOrientationChip(
                          context: context,
                          orientation: DusterOrientation.leftHand,
                          label: 'Left Hand (-15°)',
                          icon: Icons.back_hand,
                        ),
                        const SizedBox(width: 6),
                        _buildOrientationChip(
                          context: context,
                          orientation: DusterOrientation.vertical,
                          label: 'Vertical (90°)',
                          icon: Icons.height,
                        ),
                        const SizedBox(width: 6),
                        _buildOrientationChip(
                          context: context,
                          orientation: DusterOrientation.auto,
                          label: 'Auto Motion',
                          icon: Icons.autorenew,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Row 3: Size Slider & Wipe Button
          Row(
            children: [
              Icon(Icons.aspect_ratio, size: 16, color: isDark ? Colors.grey.shade300 : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Size',
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
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: dusterSize,
                    min: 15.0,
                    max: 150.0,
                    activeColor: Colors.orange.shade700,
                    inactiveColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    onChanged: onDusterSizeChanged,
                  ),
                ),
              ),
              Container(
                width: 38,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252536) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.transparent,
                  ),
                ),
                child: Text(
                  '${dusterSize.toInt()}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Clear Slide Button
              InkWell(
                onTap: onClearSlide,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red.shade900.withOpacity(0.35) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.red.shade800 : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_sweep_outlined,
                        size: 16,
                        color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Wipe Slide',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDusterTypeCard({
    required BuildContext context,
    required DusterType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = selectedDusterType == type;

    final cardBg = isSelected
        ? activeColor.withOpacity(isDark ? 0.25 : 0.08)
        : (isDark ? const Color(0xFF252536) : Colors.grey.shade50);
    final borderColor = isSelected
        ? activeColor
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final titleColor = isSelected
        ? activeColor
        : (isDark ? Colors.grey.shade300 : Colors.grey.shade800);
    final iconColor = isSelected
        ? activeColor
        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600);

    return InkWell(
      onTap: () => onDusterTypeChanged(type),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: titleColor,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 8,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrientationChip({
    required BuildContext context,
    required DusterOrientation orientation,
    required String label,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = selectedOrientation == orientation;

    final chipBg = isSelected
        ? (isDark ? Colors.orange.shade900.withOpacity(0.35) : Colors.orange.shade50)
        : (isDark ? const Color(0xFF252536) : Colors.grey.shade100);
    final borderColor = isSelected
        ? Colors.orange.shade700
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final labelColor = isSelected
        ? Colors.orange.shade700
        : (isDark ? Colors.grey.shade300 : Colors.grey.shade800);
    final iconColor = isSelected
        ? Colors.orange.shade700
        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700);

    return InkWell(
      onTap: () => onOrientationChanged(orientation),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
