// lib/utils/payment_config.dart
//
// إعدادات بوابة الدفع في مكان واحد، بدل نثر المفتاح داخل شاشة الدفع.
//
// ⚠️ قاعدة أمنية لا تُخالَف: المفتاح المنشور (publishable) وحده يُوضع في
// التطبيق. المفتاح السري (secret) يُستخدم على الخادم فقط — وضعه هنا يعني
// تسليمه لكل من يفكّ حزمة التطبيق، وبه يمكن استرداد المبالغ والاطّلاع على
// كل عمليات الحساب.
//
// المفتاح يُمرَّر عند البناء بلا وضعه في المستودع:
//   flutter build apk --dart-define=MOYASAR_PUBLISHABLE_KEY=pk_live_xxx
//
// وفي GitHub Actions يُحفظ كـ Secret ويُمرَّر بنفس الطريقة. هكذا لا يُدفع
// المفتاح مع الشيفرة، ويسهل التبديل بين مفتاح الاختبار والمفتاح الحقيقي دون
// تعديل الكود.
class PaymentConfig_ {
  PaymentConfig_._();

  /// مفتاح ميسر المنشور. يبقى فارغاً حتى يُمرَّر عند البناء.
  static const String moyasarPublishableKey =
      String.fromEnvironment('MOYASAR_PUBLISHABLE_KEY', defaultValue: '');

  /// هل الدفع بالبطاقة مهيّأ فعلاً؟ تُفحص قبل عرض شاشة الدفع وقبل إتاحة
  /// خيار البطاقة للعميل، فلا يصطدم بخيار لا يعمل.
  static bool get isConfigured => moyasarPublishableKey.trim().isNotEmpty;

  /// هل المفتاح المضبوط للاختبار (sandbox) لا للإنتاج؟ يُستخدم لعرض تنبيه
  /// واضح أثناء التجريب حتى لا يُظنّ أن مبلغاً حقيقياً سُحب.
  static bool get isTestKey => moyasarPublishableKey.startsWith('pk_test');
}
