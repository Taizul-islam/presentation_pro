import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const String _prefKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeNotifier() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_prefKey);
      if (savedTheme != null) {
        if (savedTheme == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (savedTheme == 'light') {
          _themeMode = ThemeMode.light;
        } else if (savedTheme == 'system') {
          _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      if (mode == ThemeMode.system) val = 'system';
      await prefs.setString(_prefKey, val);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.indigo,
      colorScheme: ColorScheme.light(
        primary: Colors.indigo,
        secondary: Colors.indigoAccent,
        surface: Colors.white,
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      cardColor: Colors.white,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.indigo,
      colorScheme: ColorScheme.dark(
        primary: Colors.indigoAccent,
        secondary: Colors.indigo,
        surface: const Color(0xFF1E1E2E),
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E2E),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: const Color(0xFF1E1E2E),
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
