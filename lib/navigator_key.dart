// مفتاح تنقّل عام (GlobalKey<NavigatorState>) في ملف مستقل عن lib/main.dart
// عمداً: شاشات أدوار محددة (مثل driver_home.dart) تحتاج الوصول إليه (مثلاً
// للتنقل من إشعار push دون سياق محلي)، ولو استوردته من main.dart لجرّت معها
// شجرة استيراد main.dart كاملة (كل شاشات الأدوار الأخرى)، فتنكسر الفصل على
// مستوى الحزمة بين نكهات التطبيق (عميل/سائق/مطعم/أدمن/كامل).
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// مفتاح مدير الرسائل الجذري — يتيح إغلاق الرسائل من خارج شجرة الواجهة
/// (من مراقب التنقّل أدناه)، وهو نفس المدير الذي تصل إليه الشاشات عبر
/// `ScaffoldMessenger.of(context)` ما دام مُمرَّراً إلى MaterialApp.
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// يمسح رسائل الشاشة السابقة عند **الدخول** إلى شاشة جديدة.
///
/// رسائل SnackBar في فلاتر يعرضها مديرٌ جذري واحد فوق الـ Navigator، فتبقى
/// ظاهرة عبر الانتقال بين الشاشات: أخطأ المدير كود كوبون فظهر «الكود ثلاثة
/// أحرف فأكثر»، ثم انتقل خلال ثوانٍ إلى تفاصيل شكوى — فبدت رسالة الخطأ
/// وكأنها تخصّ الشكوى (رصدها المالك في لقطة شاشة).
///
/// المسح عند الدخول فقط لا عند الرجوع: نمط «احفظ ثم ارجع» شائع في التطبيق
/// (استيراد المنيو، تعديل الملف الشخصي...) ورسالة النجاح فيه مقصود ظهورها
/// على الشاشة السابقة بعد الرجوع إليها.
class ClearMessagesOnPush extends NavigatorObserver {
  void _clear() => messengerKey.currentState?.clearSnackBars();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // لا مسح عند أول شاشة (لا سابقة لها أصلاً).
    if (previousRoute != null) _clear();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _clear();
}
