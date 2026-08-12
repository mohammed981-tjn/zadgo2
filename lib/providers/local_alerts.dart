// lib/providers/local_alerts.dart
//
// الإشعار المحلي للعروض (دفعة و4) — لتطبيق الكابتن.
//
// قبلها كان تنبيه العرض `SystemSound.alert` مكرَّراً أربع مرات: صوتُ
// نظامٍ باهت، لا يظهر في لوحة الإشعارات، ولا أثر له إن كان الكابتن في
// تطبيقٍ آخر لحظتها — فالشريط الداخلي يعيش داخل شاشتنا وحدها. ومع
// الخدمة الأمامية (و2) صار التطبيق حيّاً في الخلفية يستقبل العروض،
// لكن صوته لا يخرج من الخلفية — هذه الحلقة الناقصة.
//
// الإشعار المحلي يظهر في اللوحة بصوت النظام الكامل واهتزاز، والنقر
// عليه يفتح التطبيق — سواء كان في المقدمة أو الخلفية.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalAlerts {
  LocalAlerts._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// قناة العروض — أهمية قصوى بصوت: هذا التنبيه الذي يُبنى عليه رزق
  /// الكابتن، عكس قناة «أنت متصل» (و2) الصامتة عمداً. قناتان منفصلتان
  /// كي يستطيع إسكات إحداهما دون الأخرى من إعدادات النظام.
  static const _offersChannel = AndroidNotificationDetails(
    'zadgo_offers',
    'عروض التوصيل',
    channelDescription: 'تنبيه بصوت عند وصول عرض توصيل جديد',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.call,
  );

  static Future<void> _ensureReady() async {
    if (_ready) return;
    // أيقونة المشغّل نفسها — لا مورد إشعار مخصص يُدار في أربع نكهات.
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// تنبيه عرض جديد. الفشل صامت عمداً: الشريط الداخلي والبطاقة الدائمة
  /// («عروض بانتظار قرارك») موجودان على كل حال — الإشعار طبقة ثالثة
  /// تزيد الوصول لا شرطَ عملٍ يُعطَّل التدفق لأجله.
  static Future<void> offerAlert({
    required String title,
    required String body,
  }) async {
    try {
      await _ensureReady();
      await _plugin.show(
        // معرّف ثابت: عرضٌ جديد يحلّ محل إشعار العرض السابق بدل أن
        // تتكدس إشعارات لعروض بعضها انقضى.
        7001,
        title,
        body,
        const NotificationDetails(android: _offersChannel),
      );
    } catch (e) {
      debugPrint('LocalAlerts: $e');
    }
  }

  /// يمسح إشعار العرض — يُنادى حين يقرّر الكابتن (قبولاً أو رفضاً) كي لا
  /// يبقى إشعارٌ يعلن عرضاً لم يعد قائماً.
  static Future<void> clearOfferAlert() async {
    try {
      await _plugin.cancel(7001);
    } catch (_) {}
  }
}
