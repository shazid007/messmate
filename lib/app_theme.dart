import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AppThemePreset { light, dark, gray, forest, ocean }

class AppThemeController {
  AppThemeController._();

  static const _boxName = 'messmate_box';
  static const _themeKey = 'app_theme_preset';

  static final ValueNotifier<AppThemePreset> notifier =
      ValueNotifier<AppThemePreset>(AppThemePreset.forest);

  static Future<void> loadSavedTheme() async {
    final box = Hive.box(_boxName);
    final raw = box.get(_themeKey)?.toString();
    notifier.value = _parse(raw);
  }

  static Future<void> setTheme(AppThemePreset preset) async {
    notifier.value = preset;
    final box = Hive.box(_boxName);
    await box.put(_themeKey, preset.name);
  }

  static AppThemePreset _parse(String? raw) {
    for (final preset in AppThemePreset.values) {
      if (preset.name == raw) return preset;
    }
    return AppThemePreset.forest;
  }
}

ThemeData buildAppTheme(AppThemePreset preset) {
  switch (preset) {
    case AppThemePreset.light:
      return _buildTheme(
        seed: const Color(0xFF4F8BFF),
        scaffold: const Color(0xFFF7F9FC),
        card: Colors.white,
        brightness: Brightness.light,
      );
    case AppThemePreset.dark:
      return _buildTheme(
        seed: const Color(0xFF7CCB92),
        scaffold: const Color(0xFF111417),
        card: const Color(0xFF1B2127),
        brightness: Brightness.dark,
      );
    case AppThemePreset.gray:
      return _buildTheme(
        seed: const Color(0xFF7A7F87),
        scaffold: const Color(0xFFEEF0F3),
        card: const Color(0xFFF8F9FA),
        brightness: Brightness.light,
      );
    case AppThemePreset.forest:
      return _buildTheme(
        seed: const Color(0xFF5E8B68),
        scaffold: const Color(0xFFF5F7F2),
        card: Colors.white,
        brightness: Brightness.light,
      );
    case AppThemePreset.ocean:
      return _buildTheme(
        seed: const Color(0xFF2B7FFF),
        scaffold: const Color(0xFFF2F7FF),
        card: Colors.white,
        brightness: Brightness.light,
      );
  }
}

ThemeData _buildTheme({
  required Color seed,
  required Color scaffold,
  required Color card,
  required Brightness brightness,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: scaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF222931) : card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: seed, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: isDark ? const Color(0xFF1B2127) : card,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF171C22) : card,
      indicatorColor: seed.withValues(alpha: isDark ? 0.3 : 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? const Color(0xFF1B2127) : card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
