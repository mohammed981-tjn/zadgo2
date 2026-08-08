import 'package:flutter/material.dart';

/// ألوان النكهة الكاملة (full) والافتراضية — تبقى كما كانت دون أي تغيير،
/// وهي أيضاً القيم الافتراضية المستخدمة إن لم تُحدَّد نكهة أخرى صراحة.
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

/// مجموعة ألوان هوية كاملة لنكهة واحدة (أساسي/أغمق/أفتح)، لبناء ثيم مخصص
/// عبرها بدل الاعتماد على ColorScheme.fromSeed التلقائي الذي قد ينتج ألواناً
/// باهتة أو غير متّسقة مع الهوية البصرية المقصودة لكل نكهة.
class FlavorPalette {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  const FlavorPalette({required this.primary, required this.primaryDark, required this.primaryLight});

  /// الهوية الافتراضية — مطابقة تماماً لألوان AppColors الأصلية (النكهة
  /// الكاملة، وأي نكهة أخرى لم تُخصَّص لها هوية بعد).
  static const defaultPalette = FlavorPalette(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
  );

  /// هوية نكهة المطعم: ذهبي فاخر أعمق قليلاً من الافتراضي، بطابع "استقبال
  /// ودافئ" يناسب واجهة تشغيل مطبخ.
  static const restaurant = FlavorPalette(
    primary: Color(0xFFC8960C),
    primaryDark: Color(0xFF9C7209),
    primaryLight: Color(0xFFE3B94A),
  );

  /// هوية نكهة المدير: بني دافئ يوحي بالثقة والإشراف، مختلف تماماً عن
  /// الذهبي حتى لا يُخلَط بصرياً بين لوحة الإدارة وتطبيق المطعم.
  static const admin = FlavorPalette(
    primary: Color(0xFF6D4C41),
    primaryDark: Color(0xFF4E342E),
    primaryLight: Color(0xFF8D6E63),
  );
}

class AppTheme {
  /// يبني الثيم لهوية لونية محدَّدة. المعامل اختياري بقيمة افتراضية مطابقة
  /// تماماً لسلوك AppTheme.light القديم (خاصية بلا معاملات)، لذلك أي كود
  /// موجود يستدعيها كـ `theme: AppTheme.light` (تعبيراً عن getter) يستمر
  /// بالعمل دون أي تعديل — فقط استدعاء `AppTheme.build()` الجديد يفتح إمكان
  /// تمرير هوية مختلفة.
  static ThemeData get light => build();

  static ThemeData build({FlavorPalette palette = FlavorPalette.defaultPalette}) {
    final primary = palette.primary;
    final primaryDark = palette.primaryDark;
    final primaryLight = palette.primaryLight;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: AppColors.success,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      // ═══════════════════════════════════════════════════════════════
      // خط Cairo مُعطَّل مؤقتاً في كل الثيم (لا fontFamily هنا إطلاقاً).
      //
      // السبب: Cairo-Variable.ttf خط متغيّر (Variable Font)، وتسجيله في
      // pubspec.yaml بثلاثة أوزان تشير كلها لنفس الملف تسبَّب بفشل صامت
      // في رسم النص على Android — لا خطأ ولا استثناء، فقط نص غير مرئي
      // بينما تُرسم الحاويات والألوان والحدود طبيعياً. هذا ظهر كبطاقات
      // أصناف فارغة وأزرار بلا عناوين في كل شاشات التطبيق.
      //
      // بترك fontFamily غير محدَّد، يستخدم النظام خطه الافتراضي (يدعم
      // العربية بالكامل على أي هاتف) وتظهر كل النصوص فوراً.
      //
      // الإصلاح الدائم لاحقاً: تنزيل ملفات Cairo ثابتة منفصلة من Google
      // Fonts (Regular/SemiBold/Bold each in its own file, not one
      // variable file repeated), تسجيلها في pubspec.yaml بأوزان مختلفة
      // فعلياً لا نفس الملف مكرَّراً، ثم إعادة fontFamily: 'Cairo' هنا.
      // ═══════════════════════════════════════════════════════════════
      textTheme: Typography.material2021().black.apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.dark,
          elevation: 2,
          shadowColor: primary.withOpacity(0.5),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dark,
          side: const BorderSide(color: AppColors.divider, width: 1.5),
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.dark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: const TextStyle(color: AppColors.textGray, fontSize: 14),
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
            states.contains(WidgetState.selected) ? primary : AppColors.divider),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
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
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
        contentTextStyle: const TextStyle(fontSize: 14, color: AppColors.textGray),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      scaffoldBackgroundColor: AppColors.surface,
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      extensions: [FlavorColorsExtension(primary: primary, primaryDark: primaryDark, primaryLight: primaryLight)],
    );
  }
}

/// امتداد ثيم يحمل الدرجات الثلاث الكاملة لهوية النكهة الحالية، بحيث يمكن
/// لأي widget الوصول إليها عبر `Theme.of(context).extension<FlavorColorsExtension>()`
/// بدل الاعتماد على AppColors الثابتة حين يحتاج تدرجاً بلون النكهة الفعلي.
class FlavorColorsExtension extends ThemeExtension<FlavorColorsExtension> {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  const FlavorColorsExtension({required this.primary, required this.primaryDark, required this.primaryLight});

  @override
  FlavorColorsExtension copyWith({Color? primary, Color? primaryDark, Color? primaryLight}) =>
      FlavorColorsExtension(
        primary: primary ?? this.primary,
        primaryDark: primaryDark ?? this.primaryDark,
        primaryLight: primaryLight ?? this.primaryLight,
      );

  @override
  FlavorColorsExtension lerp(FlavorColorsExtension? other, double t) {
    if (other is! FlavorColorsExtension) return this;
    return FlavorColorsExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
    );
  }
}