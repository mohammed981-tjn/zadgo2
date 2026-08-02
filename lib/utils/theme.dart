import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFD4A017);         // ذهبي/عنبري فاخر
  static const primaryDark = Color(0xFFB8860B);      // ذهبي أغمق للتدرجات والظلال
  static const primaryLight = Color(0xFFE8C547);     // ذهبي أفتح للمس الخفيفة
  static const dark = Color(0xFF0B3D2E);             // أخضر داكن (اللون الأساسي الجديد للهوية)
  static const secondary = Color(0xFF14523E);        // أخضر داكن أفتح قليلاً للتدرجات
  static const silver = Color(0xFFC7CFD6);           // فضي/سحابي للمس الثانوية والخلفيات الفاتحة
  static const success = Color(0xFF00D084);
  static const successLight = Color(0xFFE8F9F1);
  static const warning = Color(0xFFFFB020);
  static const error = Color(0xFFE53935);
  static const errorLight = Color(0xFFFDECEA);
  static const surface = Color(0xFFF3F5F4);
  static const textDark = Color(0xFF0B3D2E);
  static const textGray = Color(0xFF8A8A8E);
  static const divider = Color(0xFFEAEAEC);
  static const cardShadow = Color(0x14000000);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.success,
      surface: Colors.white,
      brightness: Brightness.light,
    ),
    fontFamily: 'Cairo',
    textTheme: Typography.material2021().black.apply(
      fontFamily: 'Cairo',
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontFamily: 'Cairo', 
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
      iconTheme: const IconThemeData(color: AppColors.textDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.dark,
        elevation: 2,
        shadowColor: AppColors.primary.withOpacity(0.5),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        textStyle: TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.dark,
        side: const BorderSide(color: AppColors.divider, width: 1.5),
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        textStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.dark,
        textStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textGray, fontSize: 14),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white,
      shadowColor: AppColors.cardShadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? Colors.white : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.primary : AppColors.divider),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: AppColors.primary.withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontFamily: 'Cairo', 
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.dark : AppColors.textGray,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.dark : AppColors.textGray,
            size: 24,
          )),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
      contentTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textGray),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    scaffoldBackgroundColor: AppColors.surface,
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
  );
}