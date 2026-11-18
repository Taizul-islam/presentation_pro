import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';

class HandwritingControlPanel extends StatelessWidget {
  final HandwritingLanguage selectedLanguage;
  final String recognizedText;
  final Function(HandwritingLanguage) onLanguageChanged;
  final VoidCallback onConvert;
  final VoidCallback onClearInk;

  const HandwritingControlPanel({
    Key? key,
    required this.selectedLanguage,
    required this.recognizedText,
    required this.onLanguageChanged,
    required this.onConvert,
    required this.onClearInk,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBangla = selectedLanguage == HandwritingLanguage.bangla;

    return Container(
      width: 460,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header & Language Switcher
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.spellcheck, color: Colors.teal, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Handwriting Recognition (OCR)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              // Language Selector Chips
              _buildLangChip(
                lang: HandwritingLanguage.english,
                label: 'English (EN)',
              ),
              const SizedBox(width: 6),
              _buildLangChip(
                lang: HandwritingLanguage.bangla,
                label: 'বাংলা (BN)',
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Row 2: Live Recognized Text Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.gesture,
                  size: 16,
                  color: recognizedText.isNotEmpty ? Colors.teal.shade700 : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recognizedText.isNotEmpty
                        ? recognizedText
                        : (isBangla
                            ? 'স্লাইডে বাংলা লিখুন...'
                            : 'Write handwriting on slide...'),
                    style: isBangla
                        ? GoogleFonts.tiroBangla(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: recognizedText.isNotEmpty
                                ? Colors.teal.shade900
                                : Colors.grey.shade500,
                          )
                        : GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: recognizedText.isNotEmpty
                                ? Colors.teal.shade900
                                : Colors.grey.shade500,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Row 3: Actions (Convert to Text & Clear Ink)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                label: const Text('Clear Ink'),
                onPressed: onClearInk,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.text_fields, size: 16),
                label: Text(
                  'Convert to Slide Text',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: recognizedText.isNotEmpty ? onConvert : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip({
    required HandwritingLanguage lang,
    required String label,
  }) {
    final isSelected = selectedLanguage == lang;

    return InkWell(
      onTap: () => onLanguageChanged(lang),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.teal.shade900 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
