// نقطة ربط عامة بين الشاشات المشتركة (البداية/تسجيل الدخول/التسجيل) وشاشات
// كل نكهة الرئيسية (عميل/سائق/مطعم/أدمن/كامل) دون أن تستورد الشاشات
// المشتركة أي شاشة دور مباشرة.
//
// لماذا هذا مهم أمنياً: مترجم Dart (tree shaking) يُبقي في الحزمة النهائية
// كل شيفرة يمكن الوصول إليها سكونياً (static reachability) من `main()`، بصرف
// النظر عن أي قيمة شرطية وقت التشغيل. فإن استوردت شاشة "تسجيل الدخول"
// المشتركة مثلاً شاشات AdminHome/DriverHome/RestaurantHome مباشرة (حتى لو
// خلف `if` لا يتحقق إلا لدور واحد وقت التشغيل)، فستُشحن شيفرة تلك الشاشات
// كاملة ضمن تطبيق أي نكهة تستورد شاشة تسجيل الدخول — بما يخالف متطلب أن
// يكون الفصل بين النكهات على مستوى ما يُشحن في الحزمة، لا مجرد إخفاء واجهة.
//
// الحل: كل `main_X.dart` يضبط القيم أدناه مرة واحدة عند الإقلاع (قبل
// runApp)، مستورداً فقط شاشات دوره الخاصة. الشاشات المشتركة (splash_screen،
// login_screen، register_screen، register_with_code_screen) تستورد هذا
// الملف فقط (الذي لا يستورد أي شاشة دور)، وتستدعي هذه الدوال دون أن "تعرف"
// فعلياً أي الشاشات الفعلية خلفها.
import 'package:flutter/widgets.dart';
import 'models/models.dart';

/// نكهة التطبيق الحالية، لأغراض تشخيصية/تحليلية فقط (لا تُستخدم في منطق
/// الصلاحيات نفسه — ذاك مبني على [AppFlavorConfig.restrictToRole]).
enum AppFlavor { full, customer, driver, restaurant, admin }

class AppFlavorConfig {
  AppFlavorConfig._();

  static AppFlavor flavor = AppFlavor.full;

  /// الدور الوحيد المسموح بتسجيل الدخول به في هذه النكهة؛ `null` يعني بلا
  /// قيد (النكهة الكاملة فقط تسمح بكل الأدوار).
  static UserRole? restrictToRole;

  /// رسالة الرفض حين يحاول حساب من دور آخر الدخول على نكهة مقيّدة بدور واحد.
  static String restrictedMessage = 'هذا التطبيق غير مخصص لهذا الحساب';

  /// يسمح بتصفح الضيف (بلا تسجيل دخول) مباشرة كعميل — نكهة العميل فقط.
  static bool allowGuestBrowsing = false;

  /// يبني الشاشة الرئيسية المناسبة لدور مُصادَق عليه بالفعل ومطابق للقيد.
  static Widget Function(UserRole role) buildHomeForRole =
      (role) => throw StateError('AppFlavorConfig.buildHomeForRole لم يُضبط بعد');

  /// يبني شاشة "تسجيل الدخول" المهيّأة لهذه النكهة تحديداً.
  static Widget Function({bool fromCheckout}) buildLoginScreen =
      ({bool fromCheckout = false}) =>
          throw StateError('AppFlavorConfig.buildLoginScreen لم يُضبط بعد');

  /// يبني شاشة "حساب جديد" المفتوحة (عميل فقط)؛ `null` يعني إخفاء الزر
  /// تماماً (نكهات سائق/مطعم/أدمن لا تسمح بالتسجيل المفتوح).
  static Widget Function({bool fromCheckout})? buildRegisterScreen;

  /// يبني شاشة "التفعيل برمز تسجيل"؛ `null` يعني إخفاء الزر تماماً (نكهة
  /// العميل لا تستخدم أكواد التسجيل).
  static Widget Function()? buildRegisterWithCodeScreen;
}
