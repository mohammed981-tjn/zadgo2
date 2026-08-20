import 'package:flutter/material.dart';

/// ألوان النكهة الكاملة (full) والافتراضية — تبقى كما كانت دون أي تغيير،
/// وهي أيضاً القيم الافتراضية المستخدمة إن لم تُحدَّد نكهة أخرى صراحة.
class AppColors {
  static const primary = Color(0xFFFFB903);         // ذهبي العلامة — مقيس من حرفَي «Go» في الشعار نفسه
  static const primaryDark = Color(0xFFD99400);      // ذهبي أغمق للتدرجات والظلال
  static const primaryLight = Color(0xFFFFD24A);     // ذهبي أفتح للمس الخفيفة
  static const dark = Color(0xFF0B1E3D);             // كحلي العلامة (عودة الهوية الأصلية 2026-08-20)
  static const secondary = Color(0xFF132C56);        // كحلي أفتح قليلاً للتدرجات
  static const silver = Color(0xFFC7CFD6);           // فضي/سحابي للمس الثانوية والخلفيات الفاتحة
  static const success = Color(0xFF00D084);
  static const successLight = Color(0xFFE8F9F1);
  static const warning = Color(0xFFFFB020);
  static const error = Color(0xFFE53935);
  static const errorLight = Color(0xFFFDECEA);
  static const surface = Color(0xFFF4F7FC);
  static const textDark = Color(0xFF0A1A33);
  static const textGray = Color(0xFF8A8A8E);
  static const divider = Color(0xFFE3E9F3);
  static const cardShadow = Color(0x14000000);
}

/// المقياس الطباعي المعتمد (دفعة ز4) — سبع درجات لا تسعٌ وعشرون.
///
/// جرد ٢٠٢٦-٠٨-١٢ وجد ٢٩ قيمة fontSize مختلفة في الشاشات: كل شاشة
/// اجتهدت وحدها فلا إيقاع واحد يقع عليه النظر. هذه الدرجات السبع هي
/// المرجع لكل نصٍّ جديد، والقديم يُهاجَر إليها شاشةً شاشة لا دفعةً واحدة.
///
/// الارتفاعات مضبوطة للعربية: الحرف العربي متصل وله نقاط فوق السطر
/// وتحته، فيحتاج ارتفاع سطر ~1.6 للمتن (مقابل 1.4 للاتينية) وإلا
/// تلاصقت الأسطر. العناوين أقصر لأنها نادراً ما تتعدد أسطرها.
class AppText {
  AppText._();

  /// عنوان شاشة/بطاقة بارز.
  static const display = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w800, height: 1.35);

  /// عنوان قسم.
  static const title = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w700, height: 1.4);

  /// عنوان بطاقة/سطر بارز.
  static const heading = TextStyle(
      fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.5);

  /// متن أساسي.
  static const body = TextStyle(fontSize: 13.5, height: 1.6);

  /// متن ثانوي (شروح، ملاحظات).
  static const secondary =
      TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.textGray);

  /// تسمية صغيرة (شارات، أوسمة، أعمدة).
  static const label = TextStyle(fontSize: 11.5, height: 1.45);

  /// أصغر المسموح — لا شيء دونه مهما ضاق المكان.
  static const caption =
      TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.textGray);
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
    this.bgDark = const Color(0xFF08152C),
    this.bgDarker = const Color(0xFF050D1C),
  });

  /// الهوية الافتراضية — مطابقة تماماً لألوان AppColors الأصلية (النكهة
  /// الكاملة، وأي نكهة أخرى لم تُخصَّص لها هوية بعد).
  static const defaultPalette = FlavorPalette(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    onPrimary: AppColors.dark,
  );

  /// هوية تطبيق العميل: الذهبي × الكحلي — هوية العلامة الأصلية (عادت
  /// بأمر المالك 2026-08-20 بعد فترة خضراء)، مطابقةً للموقع والشعار
  /// وسبلاش العميل الذي بقي كحلياً طوال الوقت.
  static const customer = FlavorPalette(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    onPrimary: AppColors.dark,
    bgDark: Color(0xFF08152C),
    bgDarker: Color(0xFF050D1C),
  );

  /// هوية تطبيق السائق: أزرق "كابتن" — لون الطرق والحركة، مختلف تماماً عن
  /// ذهبي العميل حتى لا يلتبس التطبيقان. الدرجة #12559E بدل أزرق Material
  /// الافتراضي السابق (#1976D2): ذاك لون آلاف التطبيقات، وهذا مشتقّ من
  /// كحلي العلامة فينتمي لعائلتها (قرار المالك ٢٠٢٦-٠٨-١٠ مع الأيقونات).
  static const driver = FlavorPalette(
    primary: Color(0xFF12559E),
    primaryDark: Color(0xFF0B3C73),
    primaryLight: Color(0xFF5C90D2),
    bgDark: Color(0xFF0A1F3A),
    bgDarker: Color(0xFF050F1D),
  );

  /// هوية تطبيق المطعم: قرميدي — لون فئة المطاعم الأصيل. البرتقالي السابق
  /// (#E8590C) من نفس العائلة الدافئة لذهبي العميل فكانا يُقرآن شقيقين في
  /// شبكة المشغّل عند 48dp. ورُفض الأخضر عمداً: يشتبه بلون النجاح
  /// (AppColors.success) داخل شاشات التطبيق نفسه.
  static const restaurant = FlavorPalette(
    primary: Color(0xFFC92A2A),
    primaryDark: Color(0xFF9C1F1F),
    primaryLight: Color(0xFFE76A6A),
    bgDark: Color(0xFF2E0B0B),
    bgDarker: Color(0xFF170404),
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
      // خط Cairo — أُعيد تفعيله ٢٠٢٦-٠٨-١٢ بعد إصلاح سببِ تعطيله.
      //
      // العطل الأصلي: `Cairo-Variable.ttf` خط متغيّر، وكان مسجَّلاً في
      // pubspec بثلاثة أوزان **تشير كلها لنفس الملف**. أندرويد يفشل في
      // رسم النص حينها فشلاً صامتاً — لا خطأ ولا استثناء، فقط نصٌّ غير
      // مرئي بينما تُرسم الحاويات والألوان طبيعياً (بطاقات أصناف فارغة
      // وأزرار بلا عناوين). فعُطِّل الخط كلّه إسعافاً، وبقي التطبيق على
      // خط النظام: نصٌّ مختلف من هاتف لهاتف، ولا هوية طباعية للعلامة.
      //
      // الإصلاح الآن جذريّ لا إسعافيّ: استُخرجت **أربعة ملفات ثابتة** من
      // الملف المتغيّر نفسه (`instantiateVariableFont` بـwght ٤٠٠/٦٠٠/
      // ٧٠٠/٨٠٠ وslnt=0)، فلكل وزن ملفٌ حقيقي مستقل — وهو ما كان ينقص.
      // ورخصة الخط SIL OFL 1.1 تُجيز الاشتقاق وإعادة التوزيع، وملف
      // `OFL.txt` مرافقٌ في `assets/fonts/`.
      //
      // والملف المتغيّر باقٍ أصلاً عادياً في pubspec: حزمة pdf تقرؤه
      // مباشرة بـrootBundle للتصدير العربي ولا تمرّ بنظام خطوط Flutter.
      // ═══════════════════════════════════════════════════════════════
      fontFamily: 'Cairo',
      // ارتفاع السطر العربي (ز4): مقاسات ماتيريال مضبوطة للاتينية،
      // والعربي يحتاج ~1.6 للمتن وإلا تلاصقت نقاط الأسطر المتتالية.
      // يُضبط على أنماط المتن الثلاثة وحدها — العناوين نادراً ما تتعدد
      // أسطرها ورفعُها يبعثر تمركزها في الأشرطة والأزرار.
      textTheme: Typography.material2021()
          .black
          .apply(
            fontFamily: 'Cairo',
            bodyColor: AppColors.textDark,
            displayColor: AppColors.textDark,
          )
          .copyWith(
            bodyLarge: Typography.material2021().black.bodyLarge?.copyWith(
                fontFamily: 'Cairo', color: AppColors.textDark, height: 1.6),
            bodyMedium: Typography.material2021().black.bodyMedium?.copyWith(
                fontFamily: 'Cairo', color: AppColors.textDark, height: 1.6),
            bodySmall: Typography.material2021().black.bodySmall?.copyWith(
                fontFamily: 'Cairo', color: AppColors.textDark, height: 1.55),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        // زر الرجوع الافتراضي (سهم أعلى الشاشة) كان بحجمه الافتراضي 24
        // نحيلاً خافت الحضور — يبدو زخرفة لا زراً قابلاً للضغط، خاصة على
        // شاشات التفاصيل التي يفتحها المستخدم متكرراً (كتفاصيل الشكوى).
        // التكبير هنا يشمل كل زر رجوع تلقائي في النكهات الأربع دفعة واحدة.
        iconTheme: const IconThemeData(color: AppColors.textDark, size: 27),
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
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentText,
          side: BorderSide(color: primary.withOpacity(0.45), width: 1.5),
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentText,
          textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
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
        labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textGray, fontSize: 14),
      ),
      // دفعة ز4 (جزئياً، ٢٠٢٦-٠٨-١٢): البطاقة كانت بيضاء بلا ظل ولا حدّ
      // على خلفية #F3F5F4 — والفرق بينهما ٣٪ إضاءة فقط، فتُقرأ الشاشة
      // «غير مكتملة» ولا يُعرف سببها. ماتيريال ٣ حين يُصفّر الارتفاع
      // يفترض بديلاً (حدّاً أو ظلاً) ولم يكن عندنا أيّهما. الحدّ الرفيع
      // أرخص الاثنين: لا يكلّف رسماً إضافياً كالظل، ويعمل في كثافة
      // البطاقات العالية عندنا (قوائم طلبات) حيث تتراكب الظلال فتتوسّخ.
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white,
        shadowColor: AppColors.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
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
          fontFamily: 'Cairo',
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
        titleTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
        contentTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textGray),
      ),
      // بلاغ المالك ٢٠٢٦-٠٨-١٢ («الألوان متطابقة وغير واضح»): رقائق نافذة
      // «حل الشكوى» كان نصّها شبه غير مرئي — رماديٌّ فاتح على رمادي
      // `surface` الفاتح. والعلّة أن `labelStyle` هنا كان **بلا لون**،
      // فيرتدّ الحرف للون ماتيريال الافتراضي وهو محسوبٌ لخلفية بيضاء لا
      // لخلفيتنا الرمادية.
      //
      // ولم تظهر إلا هناك لأن كل شاشات العميل تضبط لون الرقاقة محلياً —
      // وهذا بالضبط ما يجعل الخطأ خبيثاً: يبدو النظام سليماً لأن أربعة
      // مواضع رقّعت نفسها، ويظهر العطل في الموضع الوحيد الذي وثق بالثيم.
      // فالإصلاح هنا لا هناك، ليشمل كل رقاقة تُكتب بعد اليوم.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: primary,
        checkmarkColor: palette.onPrimary,
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        // نمط المحدَّد يُقرأ من `secondaryLabelStyle` لا من `labelStyle` —
        // ولولا ضبطه لبقي الحرف داكناً على خلفية النكهة الداكنة فانقلب
        // العطل ولم يزُل.
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: palette.onPrimary,
        ),
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
    this.bgDark = const Color(0xFF08152C),
    this.bgDarker = const Color(0xFF050D1C),
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