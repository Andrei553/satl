import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0B0F17);
  static const bg2 = Color(0xFF121826);
  static const card = Color(0xFF161D2B);
  static const card2 = Color(0xFF1D2637);
  static const text = Color(0xFFF2F5FA);
  static const muted = Color(0xFF8A94A6);
  static const accent = Color(0xFF5B8CFF);
  static const green = Color(0xFF38D39F);
  static const orange = Color(0xFFFFA24C);
  static const red = Color(0xFFFF5C7A);
  static const violet = Color(0xFFA77BFF);
  static const cyan = Color(0xFF43D6E8);
}

/// Пары цветов для карточек серверов. Выбираются по кругу.
const List<List<Color>> serverGradients = [
  [Color(0xFF5B8CFF), Color(0xFF8E5BFF)],
  [Color(0xFF38D39F), Color(0xFF2BB0C9)],
  [Color(0xFFFF8A5B), Color(0xFFFF5C7A)],
  [Color(0xFFA77BFF), Color(0xFF5B8CFF)],
  [Color(0xFF43D6E8), Color(0xFF38D39F)],
  [Color(0xFFFFB44C), Color(0xFFFF7A5B)],
];

Color colorFromHex(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.tryParse(h, radix: 16) ?? 0xFF5B8CFF);
}

Color domainColor(String domain) {
  switch (domain) {
    case 'light':
      return const Color(0xFFFFC65C);
    case 'switch':
    case 'input_boolean':
      return AppColors.green;
    case 'climate':
      return AppColors.orange;
    case 'sensor':
      return AppColors.cyan;
    case 'binary_sensor':
      return AppColors.violet;
    case 'cover':
      return const Color(0xFF7BD3FF);
    case 'media_player':
      return const Color(0xFFFF7AB6);
    default:
      return AppColors.accent;
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.bg,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.text,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.card2,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
