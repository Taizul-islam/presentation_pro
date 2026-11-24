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
            selectedDusterType == DusterType.sponge ||
            selectedDusterType == DusterType.handDuster;

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
          // Row 1: Compact Segmented Duster Type Buttons
          Row(
            children: [
              Expanded(
                child: _buildSegmentButton(
                  context: context,
                  type: DusterType.handDuster,
                  label: 'Hand Duster',
                  icon: Icons.back_hand_outlined,
                  activeColor: Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSegmentButton(
                  context: context,
                  type: DusterType.feltBlock,
                  label: 'Felt Duster',
                  icon: Icons.rectangle_outlined,
                  activeColor: Colors.amber.shade800,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSegmentButton(
                  context: context,
                  type: DusterType.sponge,
                  label: 'Sponge',
                  icon: Icons.blur_circular,
                  activeColor: Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSegmentButton(
                  context: context,
                  type: DusterType.precision,
                  label: 'Precision',
                  icon: Icons.center_focus_strong,
                  activeColor: Colors.indigoAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Ergonomic Grip Angle Menu, Size Slider & Wipe Button
          Row(
            children: [
              // Size Icon & Label
              Icon(
                Icons.aspect_ratio,
                size: 14,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              const SizedBox(width: 4),

              // Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
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

              // Value Badge
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
                  '${dusterSize.toInt()}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Ergonomic Grip Angle Dropdown Menu
              if (showOrientationOptions) ...[
                _buildGripAngleMenu(context, isDark),
                const SizedBox(width: 8),
              ],

              // Wipe Slide Button
              Tooltip(
                message: 'Clear All Drawings from Slide',
                child: InkWell(
                  onTap: onClearSlide,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.shade900.withOpacity(0.35) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.red.shade800 : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_sweep_outlined,
                          size: 14,
                          color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Wipe',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required BuildContext context,
    required DusterType type,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = selectedDusterType == type;

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
      onTap: () => onDusterTypeChanged(type),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 6),
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
              size: 13,
              color: textColor,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGripAngleMenu(BuildContext context, bool isDark) {
    String currentLabel = '15°';
    IconData currentIcon = Icons.front_hand;

    switch (selectedOrientation) {
      case DusterOrientation.rightHand:
        currentLabel = '15°';
        currentIcon = Icons.front_hand;
        break;
      case DusterOrientation.horizontal:
        currentLabel = '0°';
        currentIcon = Icons.horizontal_rule;
        break;
      case DusterOrientation.leftHand:
        currentLabel = '-15°';
        currentIcon = Icons.back_hand;
        break;
      case DusterOrientation.vertical:
        currentLabel = '90°';
        currentIcon = Icons.height;
        break;
      case DusterOrientation.auto:
        currentLabel = 'Auto';
        currentIcon = Icons.autorenew;
        break;
    }

    return PopupMenuButton<DusterOrientation>(
      onSelected: onOrientationChanged,
      tooltip: 'Select Ergonomic Grip Angle',
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252536) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(currentIcon, size: 12, color: Colors.orange.shade700),
            const SizedBox(width: 3),
            Text(
              currentLabel,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        _buildPopupMenuItem(DusterOrientation.rightHand, 'Right Hand (15°)', Icons.front_hand, isDark),
        _buildPopupMenuItem(DusterOrientation.horizontal, 'Horizontal (0°)', Icons.horizontal_rule, isDark),
        _buildPopupMenuItem(DusterOrientation.leftHand, 'Left Hand (-15°)', Icons.back_hand, isDark),
        _buildPopupMenuItem(DusterOrientation.vertical, 'Vertical (90°)', Icons.height, isDark),
        _buildPopupMenuItem(DusterOrientation.auto, 'Auto Motion', Icons.autorenew, isDark),
      ],
    );
  }

  PopupMenuItem<DusterOrientation> _buildPopupMenuItem(
    DusterOrientation value,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = selectedOrientation == value;
    return PopupMenuItem<DusterOrientation>(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.orange.shade700 : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.orange.shade700
                  : (isDark ? Colors.white : Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
