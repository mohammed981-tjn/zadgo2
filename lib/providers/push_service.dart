// lib/providers/push_service.dart
//
// تسجيل الجهاز لاستقبال إشعارات FCM وعرضها داخل التطبيق وهو مفتوح.
//
// كانت البنية ناقصة نصفها: حقل fcmToken موجود في نموذج المستخدم ودالة حفظه
// موجودة في FirebaseService، لكن لا أحد كان يطلب إذن الإشعارات ولا يجلب
// التوكن ولا يحفظه — فحتى لو وُجد مَن يُرسل، لا عناوين تصله. هذا الملف
// يكمل الحلقة من جهة التطبيق، والإرسال يتولاه الخادم المرافق
// (server/api/notify.php).
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType;
import '../navigator_key.dart';
import '../utils/theme.dart';

class PushService {
  PushService._();

  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _messageSub;

  /// يسجّل جهاز المستخدم الحالي: يطلب الإذن (يشمل حوار Android 13+)، يجلب
  /// التوكن ويحفظه عبر [saveToken]، ويتابع تجدّده — التوكن يتغيّر عند إعادة
  /// تثبيت التطبيق أو مسح بياناته، والتوكن القديم يصبح عنواناً ميتاً.
  ///
  /// يُستدعى بعد كل تسجيل دخول ناجح. الفشل هنا لا يمسّ الدخول نفسه:
  /// رفض الإذن يعني ببساطة ألّا إشعارات لهذا الجهاز.
  static Future<void> registerDevice(
    String uid,
    Future<void> Function(String uid, String token) saveToken,
  ) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await saveToken(uid, token);
      }

      await _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen((fresh) {
        saveToken(uid, fresh).catchError((_) {});
      });

      _listenForeground();
    } catch (e) {
      debugPrint('PushService: تعذّر تسجيل الجهاز ($e)');
    }
  }

  /// عند الخروج يُلغى تتبّع التوكن حتى لا يُحفظ توكن هذا الجهاز باسم
  /// المستخدم التالي. (مسح التوكن من مستند المستخدم يتولاه AuthProvider.)
  static Future<void> unregisterDevice() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
  }

  /// أثناء عمل التطبيق في المقدمة لا يعرض النظام إشعار FCM بنفسه، فيُعرض
  /// شريط داخل التطبيق مع نغمة — وإلا ضاع الإشعار بصمت في أهم لحظة
  /// (المستخدم فاتح التطبيق فعلاً).
  static void _listenForeground() {
    if (_messageSub != null) return;
    _messageSub = FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      if (title.isEmpty && body.isEmpty) return;

      SystemSound.play(SystemSoundType.alert);

      final context = navigatorKey.currentContext;
      if (context == null) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 6),
        content: Row(children: [
          const Icon(Icons.notifications_active_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5)),
                if (body.isNotEmpty)
                  Text(body,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
        ]),
      ));
    });
  }
}
