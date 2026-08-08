// lib/providers/notify_relay.dart
//
// عميل «الخادم المرافق» للإشعارات: بعد كل حدث طلب (إنشاء/إسناد/تغيير حالة)
// يُبلَّغ الخادم بمعرّف الطلب ونوع الحدث فقط، والخادم هو من يقرأ الطلب من
// Firestore بحساب خدمة ويقرّر مَن يستحق الإشعار وما نصّه — فلا يستطيع عميل
// معدَّل تزوير نص إشعار أو توجيهه لغير أصحابه.
//
// النداء «أطلِق وانسَ» عمداً: الإشعار تحسين وليس شرطاً لصحّة العملية، ففشل
// الشبكة أو غياب الخادم لا يجوز أن يُفشل إنشاء طلب نجح فعلاً في Firestore.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

/// أنواع أحداث الطلب التي يفهمها الخادم المرافق (server/api/notify.php).
enum OrderEvent {
  /// طلب جديد أُنشئ — يُشعَر مديرو المطعم المعني.
  created,

  /// أُسند الطلب لسائق — يُشعَر السائق.
  assigned,

  /// تغيّرت حالة الطلب — يُشعَر العميل صاحبه.
  status,
}

class NotifyRelay {
  NotifyRelay._();

  /// مهلة قصيرة عمداً: النداء يعمل في الخلفية ولا ننتظره، لكن لا نُبقي
  /// اتصالات معلّقة تتراكم إن كان الخادم بطيئاً أو ساقطاً.
  static const Duration _timeout = Duration(seconds: 8);

  /// يبلّغ الخادم بحدث على طلب. لا يرمي استثناءً أبداً ولا يُنتظر إتمامه.
  static void orderEvent(String orderId, OrderEvent event) {
    if (!ApiConfig.isConfigured) return;
    // unawaited عن قصد — انظر تعليق أعلى الملف.
    unawaited(_send(orderId, event));
  }

  static Future<void> _send(String orderId, OrderEvent event) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      // توكن الهوية يُرفق ليتحقق الخادم من أن المُبلِّغ مستخدم حقيقي طرفٌ
      // في الطلب — لا مفاتيح سرّية في التطبيق إطلاقاً.
      final idToken = await user.getIdToken();
      await http
          .post(
            ApiConfig.notifyEndpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: '{"orderId":"$orderId","event":"${event.name}"}',
          )
          .timeout(_timeout);
    } catch (e) {
      // فشل الإشعار لا يمسّ العملية نفسها — يُسجَّل للتشخيص فقط.
      debugPrint('NotifyRelay: تعذّر إبلاغ الخادم ($e)');
    }
  }
}
