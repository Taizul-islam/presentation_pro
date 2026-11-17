import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SamsungMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isHeader;
  final IconData? trailingIcon;

  const SamsungMenuItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isHeader = false,
    this.trailingIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isHeader) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181825) : Colors.black,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, color: Colors.white, size: 16),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.grey.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade400,
                  size: 14),
          ],
        ),
      ),
    );
  }
}
