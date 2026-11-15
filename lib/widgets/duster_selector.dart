import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';

class RealDusterToolbar extends StatelessWidget {
  final DusterType selectedDusterType;
  final double dusterSize;
  final Function(DusterType) onDusterTypeChanged;
  final Function(double) onDusterSizeChanged;
  final VoidCallback onClearSlide;

  const RealDusterToolbar({
    Key? key,
    required this.selectedDusterType,
    required this.dusterSize,
    required this.onDusterTypeChanged,
    required this.onDusterSizeChanged,
    required this.onClearSlide,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 440,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  type: DusterType.precision,
                  title: 'Precision',
                  subtitle: 'Point eraser',
                  icon: Icons.center_focus_strong,
                  activeColor: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Row 2: Size Slider & Wipe Button
          Row(
            children: [
              Icon(Icons.aspect_ratio, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Size',
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
                    value: dusterSize,
                    min: 15.0,
                    max: 150.0,
                    activeColor: Colors.orange.shade700,
                    inactiveColor: Colors.grey.shade200,
                    onChanged: onDusterSizeChanged,
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
                  '${dusterSize.toInt()}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800,
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
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Wipe Slide',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
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
    required DusterType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = selectedDusterType == type;

    return InkWell(
      onTap: () => onDusterTypeChanged(type),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
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
    );
  }
}
