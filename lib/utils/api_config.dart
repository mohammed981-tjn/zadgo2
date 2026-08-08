// lib/utils/api_config.dart
//
// عنوان «الخادم المرافق» (relay) الذي يرسل إشعارات FCM الفورية — صفحة PHP
// صغيرة تُستضاف على استضافة الدومين (راجع server/README-ar.md) وتقوم مقام
// Cloud Functions المؤجَّلة لعدم توفر خطة Blaze.
//
// يُمرَّر العنوان وقت البناء ولا يُكتب في الكود:
//   flutter build apk --dart-define=ZADGO_API_BASE=https://api.zadgo.co
//
// وإن لم يُضبط يعمل التطبيق كما كان تماماً: كل نداءات الإشعارات تُتجاهَل
// بصمت، فغياب الخادم لا يعطّل إنشاء الطلبات ولا أي تدفّق آخر.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment('ZADGO_API_BASE');

  static bool get isConfigured => baseUrl.trim().isNotEmpty;

  /// نقطة إرسال إشعار حدث طلب.
  static Uri get notifyEndpoint =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/notify.php');
}
