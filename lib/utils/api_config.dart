// lib/utils/api_config.dart
//
// عنوان نقطة إشعارات «الخادم المرافق» — الخدمة التي تقوم مقام Cloud
// Functions المؤجَّلة (لا خطة Blaze) في إرسال إشعارات FCM الفورية.
//
// يُمرَّر **العنوان الكامل للنقطة** وقت البناء ولا يُكتب في الكود:
//   flutter build apk --dart-define=ZADGO_NOTIFY_URL=https://api.zadgo.co/notify.php
//
// العنوان كامل عمداً لا «قاعدة يُلحق بها مسار»: التطبيق بهذا محايد تماماً
// لبنية الاستضافة — استضافة PHP (…/notify.php) أو Cloudflare Workers
// (https://zadgo-notify.****.workers.dev) أو أي بديل لاحق، دون أي تغيير
// في الكود أو إعادة بناء منطق.
//
// وإن لم يُضبط يعمل التطبيق كما كان تماماً: كل نداءات الإشعارات تُتجاهَل
// بصمت، فغياب الخادم لا يعطّل إنشاء الطلبات ولا أي تدفّق آخر.
class ApiConfig {
  ApiConfig._();

  static const String notifyUrl = String.fromEnvironment('ZADGO_NOTIFY_URL');

  static bool get isConfigured => notifyUrl.trim().isNotEmpty;

  /// نقطة إرسال إشعار حدث طلب.
  static Uri get notifyEndpoint => Uri.parse(notifyUrl.trim());
}
