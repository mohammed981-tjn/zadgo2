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

  /// لون النص/الأيقونات فوق اللون الأساسي (أبيض للألوان الداكنة، أخضر داكن
  /// فوق الذهبي الفاتح) — يضمن تبايناً مقروءاً في أزرار كل نكهة.
  final Color onPrimary;

  /// درجتا الخلفية الداكنة لشاشتَي البداية وتسجيل الدخول — لكل نكهة "ليلها"
  /// الخاص المشتق من هويتها، فيعرف المستخدم من أول نظرة أي تطبيق فتح.
  final Color bgDark;
  final Color bgDarker;

  const FlavorPalette({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    this.onPrimary = Colors.white,
    this.bgDark = const Color(0xFF08211A),
    this.bgDarker = const Color(0xFF04120D),
  });

  /// الهوية الافتراضية — مطابقة تماماً لألوان AppColors الأصلية (النكهة
  /// الكاملة، وأي نكهة أخرى لم تُخصَّص لها هوية بعد).
  static const defaultPalette = FlavorPalette(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    onPrimary: AppColors.dark,
  );

  /// هوية تطبيق العميل: الذهبي الفاخر × الأخضر الملكي — هوية العلامة
  /// الأساسية التي يراها الجمهور.
  static const customer = FlavorPalette(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    onPrimary: AppColors.dark,
    bgDark: Color(0xFF08211A),
    bgDarker: Color(0xFF04120D),
  );

  /// هوية تطبيق السائق: أزرق "كابتن" — لون الطرق والحركة، مختلف تماماً عن
  /// ذهبي العميل حتى لا يلتبس التطبيقان.
  static const driver = FlavorPalette(
    primary: Color(0xFF1976D2),
    primaryDark: Color(0xFF0D47A1),
    primaryLight: Color(0xFF64B5F6),
    bgDark: Color(0xFF0A1E38),
    bgDarker: Color(0xFF050F1E),
  );

  /// هوية تطبيق المطعم: برتقالي ناري — حرارة المطبخ والاستعجال، بعيد عن
  /// ذهبي العميل الذي كان قريباً منه سابقاً فيسبّب الالتباس.
  static const restaurant = FlavorPalette(
    primary: Color(0xFFE8590C),
    primaryDark: Color(0xFFBF4506),
    primaryLight: Color(0xFFFF8F4C),
    bgDark: Color(0xFF2A1204),
    bgDarker: Color(0xFF160902),
  );

  /// هوية لوحة المدير: بنفسجي ملكي — طابع "غرفة التحكم"، متمايز بوضوح عن
  /// النكهات التشغيلية الثلاث.
  static const admin = FlavorPalette(
    primary: Color(0xFF5E35B1),
    primaryDark: Color(0xFF4527A0),
    primaryLight: Color(0xFF9575CD),
    bgDark: Color(0xFF1C1233),
    bgDarker: Color(0xFF0E081C),
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
    // لون النص التفاعلي (أزرار نصية/محددة): الهوية الذهبية تحتفظ بالأخضر
    // الداكن لأن الذهبي الغامق ضعيف التباين على الأبيض؛ بقية الهويات تستخدم
    // درجتها الداكنة المقروءة.
    final accentText = palette.onPrimary == AppColors.dark ? AppColors.dark : primaryDark;

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
          foregroundColor: palette.onPrimary,
          elevation: 3,
          shadowColor: primary.withOpacity(0.55),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentText,
          side: BorderSide(color: primary.withOpacity(0.45), width: 1.5),
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentText,
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
              color: states.contains(WidgetState.selected) ? accentText : AppColors.textGray,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? accentText : AppColors.textGray,
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
      extensions: [
        FlavorColorsExtension(
          primary: primary,
          primaryDark: primaryDark,
          primaryLight: primaryLight,
          onPrimary: palette.onPrimary,
          bgDark: palette.bgDark,
          bgDarker: palette.bgDarker,
        ),
      ],
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
  final Color onPrimary;
  final Color bgDark;
  final Color bgDarker;
  const FlavorColorsExtension({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    this.onPrimary = Colors.white,
    this.bgDark = const Color(0xFF08211A),
    this.bgDarker = const Color(0xFF04120D),
  });

  @override
  FlavorColorsExtension copyWith(
          {Color? primary, Color? primaryDark, Color? primaryLight, Color? onPrimary, Color? bgDark, Color? bgDarker}) =>
      FlavorColorsExtension(
        primary: primary ?? this.primary,
        primaryDark: primaryDark ?? this.primaryDark,
        primaryLight: primaryLight ?? this.primaryLight,
        onPrimary: onPrimary ?? this.onPrimary,
        bgDark: bgDark ?? this.bgDark,
        bgDarker: bgDarker ?? this.bgDarker,
      );

  @override
  FlavorColorsExtension lerp(FlavorColorsExtension? other, double t) {
    if (other is! FlavorColorsExtension) return this;
    return FlavorColorsExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      bgDark: Color.lerp(bgDark, other.bgDark, t)!,
      bgDarker: Color.lerp(bgDarker, other.bgDarker, t)!,
    );
  }
}

/// اختصار وصولي: `context.flavorColors` بدل السطر الطويل في كل شاشة.
extension FlavorColorsContextX on BuildContext {
  FlavorColorsExtension get flavorColors =>
      Theme.of(this).extension<FlavorColorsExtension>() ??
      const FlavorColorsExtension(
        primary: AppColors.primary,
        primaryDark: AppColors.primaryDark,
        primaryLight: AppColors.primaryLight,
        onPrimary: AppColors.dark,
      );
}