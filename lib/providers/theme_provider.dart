import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _kDarkModeKey = 'theme_is_dark';

  bool _isDarkMode = true;
  String? _currentTheme;
  String? _currentThemeColor;

  bool get isDarkMode => _isDarkMode;
  String? get currentTheme => _currentTheme;
  String? get currentThemeColor => _currentThemeColor;

  ThemeData get themeData => _generateThemeData(_isDarkMode, _currentTheme, _currentThemeColor);
  ThemeData get lightThemeData => _generateThemeData(false, _currentTheme, _currentThemeColor);
  ThemeData get darkThemeData => _generateThemeData(true, _currentTheme, _currentThemeColor);

  // Restore saved preference; fall back to dark mode
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kDarkModeKey);
      if (saved != null) {
        _isDarkMode = saved == 'true';
      } else {
        // No saved preference — default to dark mode
        _isDarkMode = true;
      }
      notifyListeners();
    } catch (_) {}
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDarkModeKey, _isDarkMode.toString());
    } catch (_) {}
  }

  void setTenant(String? themeName, {String? themeColor}) {
    if (_currentTheme != themeName || _currentThemeColor != themeColor) {
      _currentTheme = themeName;
      _currentThemeColor = themeColor;
      notifyListeners();
    }
  }

  static Color fromHSL(double h, double s, double l) {
    return HSLColor.fromAHSL(1.0, h, s / 100, l / 100).toColor();
  }

  static Color parseColorString(String? colorStr) {
    if (colorStr == null || colorStr.trim().isEmpty) return Colors.transparent;
    
    String clean = colorStr.trim().toLowerCase();

    // 1. Try HSL parsing (handles "hsl(150 60% 35%)", "hsl(150, 60%, 35%)", "150 60% 35%", etc.)
    try {
      final RegExp hslRegExp = RegExp(
        r'^(?:hsla?\s*\(?\s*)?(\d+(?:\.\d+)?)(?:deg)?[\s,]+(\d+(?:\.\d+)?)\s*%?[\s,]+(\d+(?:\.\d+)?)\s*%?(?:[\s,/]+(\d+(?:\.\d+)?))?\s*\)?$'
      );
      final match = hslRegExp.firstMatch(clean);
      if (match != null) {
        double h = double.parse(match.group(1)!);
        double s = double.parse(match.group(2)!);
        double l = double.parse(match.group(3)!);
        double a = match.group(4) != null ? double.parse(match.group(4)!) : 1.0;
        
        h = h % 360;
        if (h < 0) h += 360;
        s = s.clamp(0.0, 100.0);
        l = l.clamp(0.0, 100.0);
        a = a.clamp(0.0, 1.0);

        return HSLColor.fromAHSL(a, h, s / 100, l / 100).toColor();
      }
    } catch (e) {
      debugPrint('⚠️ HSL parse exception for "$colorStr": $e');
    }
    
    // 2. Try RGB/RGBA parsing
    if (clean.contains('rgb')) {
      try {
        final RegExp rgbRegExp = RegExp(
          r'rgba?\s*\(\s*(\d+)\s*[, ]\s*(\d+)\s*[, ]\s*(\d+)\s*(?:[,/]\s*(\d+(?:\.\d+)?)\s*)?\)'
        );
        final match = rgbRegExp.firstMatch(clean);
        if (match != null) {
          int r = int.parse(match.group(1)!);
          int g = int.parse(match.group(2)!);
          int b = int.parse(match.group(3)!);
          double a = match.group(4) != null ? double.parse(match.group(4)!) : 1.0;
          return Color.fromRGBO(r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), a.clamp(0.0, 1.0));
        }
      } catch (_) {}
    }
    
    return hexToColor(colorStr);
  }

  static Color hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.transparent;
    try {
      final buffer = StringBuffer();
      String clean = hex.replaceFirst('#', '');
      if (clean.length == 6) buffer.write('ff');
      buffer.write(clean);
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.transparent;
    }
  }

  static Color? _getPresetThemeColor(String? themeName) {
    if (themeName == null) return null;
    switch (themeName.toLowerCase().trim()) {
      case 'forest':
        return fromHSL(150, 60, 35);
      case 'emerald':
        return fromHSL(160, 70, 40);
      case 'ocean':
      case 'blue':
        return fromHSL(215, 85, 50);
      case 'purple':
      case 'violet':
        return fromHSL(265, 80, 55);
      case 'sunset':
      case 'orange':
        return fromHSL(25, 90, 50);
      case 'crimson':
      case 'red':
      case 'rose':
        return fromHSL(350, 80, 50);
      case 'amber':
      case 'gold':
        return fromHSL(40, 90, 45);
      case 'cyan':
      case 'teal':
        return fromHSL(180, 75, 40);
      default:
        return null;
    }
  }

  ThemeData _generateThemeData(bool isDark, String? themeName, String? themeColorHex) {
    Color primary;
    if (themeColorHex != null && themeColorHex.isNotEmpty) {
      Color parsed = parseColorString(themeColorHex);
      if (parsed != Colors.transparent) {
        primary = parsed;
      } else {
        primary = _getPresetThemeColor(themeName) ?? (isDark ? fromHSL(230, 85, 60) : fromHSL(225, 80, 55));
      }
    } else {
      primary = _getPresetThemeColor(themeName) ?? (isDark ? fromHSL(230, 85, 60) : fromHSL(225, 80, 55));
    }

    Color scaffoldBg = isDark ? const Color(0xFF0F172A) : Colors.white; // Slate 900
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white; // Slate 800
    Color divider = isDark ? const Color(0xFF334155) : fromHSL(214, 32, 91); // Slate 700

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardColor,
      dividerColor: divider,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primary,
              surface: cardColor,
              onSurface: Colors.white,
              onSurfaceVariant: Colors.white.withOpacity(0.6),
            )
          : ColorScheme.light(
              primary: primary,
              surface: cardColor,
              onSurface: Colors.black,
              onSurfaceVariant: const Color(0xFF475569),
            ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900),
        titleLarge: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
      ),
    );
  }
}
