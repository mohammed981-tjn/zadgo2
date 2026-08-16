// lib/providers/app_check_service.dart
//
// حماية App Check (دفعة الحماية — 2026-08-16): فرضها على Firebase AI
// Logic **لا يُعطَّل من الكونسول إطلاقاً** (اكتشاف التشخيص الميداني:
// «App Check token is invalid» رغم أن كل شيء آخر مفعّل) — فتسجيل
// التطبيق فيها شرطُ تشغيل الذكاء، لا خياراً أمنياً مؤجلاً.
//
// لماذا مزوّد «التصحيح» (Debug) لا Play Integrity الآن؟ لأن أجهزتنا
// تُثبَّت بالتوزيع المباشر للـAPK (لا عبر متجر Play)، وPlay Integrity
// يرفض ما لم يأتِ من المتجر. رمز التصحيح يُسجَّل في الكونسول يدوياً
// لكل جهاز إداري — مقبول لأن الذكاء اليوم في تطبيق الإدارة وحده
// (أجهزة معدودة بيد المالك). عند النشر في المتاجر يُستبدل بمزوّد
// Play Integrity — مدوَّن في خارطة الذكاء بنداً صريحاً.
//
// عقبةٌ حُلَّت هنا: الحزمة تولّد رمز التصحيح وتطبعه في سجلات المطورين
// فقط — والمالك لا يملك أدوات قراءتها. لكن الرمز يُخزَّن في ملف
// تفضيلات داخل بيانات التطبيق نفسه، فنقرؤه من هناك ونعرضه في شاشة
// التشخيص بزر نسخ.
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckService {
  AppCheckService._();

  /// يفعّل App Check بمزوّد التصحيح — يُستدعى مرة عند إقلاع تطبيق
  /// الإدارة. الفشل هنا لا يُسقط التطبيق: كل ما عدا الذكاء يعمل بدونه.
  static Future<void> activateDebug() async {
    try {
      await FirebaseAppCheck.instance
          .activate(androidProvider: AndroidProvider.debug);
    } catch (e) {
      debugPrint('AppCheck activate error: $e');
    }
  }

  /// يقرأ رمز التصحيح المولَّد على هذا الجهاز ليُسجّله المالك في
  /// الكونسول (App Check ← Apps ← Admin ← Manage debug tokens).
  ///
  /// يطلب توكناً أولاً ليُجبر الحزمة على توليد الرمز وتخزينه (يفشل
  /// الطلب نفسه قبل التسجيل — متوقع ولا يهم)، ثم يلتقطه من ملف
  /// التفضيلات `com.google.firebase.appcheck.debug.store.*` في مجلد
  /// بيانات التطبيق (Directory.systemTemp على أندرويد = مجلد الكاش،
  /// وأبوه مجلد البيانات — بلا حزمة مسارات إضافية).
  static Future<String?> readDebugToken() async {
    try {
      await FirebaseAppCheck.instance.getToken(true);
    } catch (_) {
      // متوقع قبل تسجيل الرمز في الكونسول — الغرض توليده محلياً فقط.
    }
    try {
      final prefsDir =
          Directory('${Directory.systemTemp.parent.path}/shared_prefs');
      if (!prefsDir.existsSync()) return null;
      for (final f in prefsDir.listSync()) {
        final name = f.uri.pathSegments.last;
        if (f is File &&
            name.startsWith('com.google.firebase.appcheck.debug.store')) {
          final m = RegExp(
                  r'DEBUG_SECRET[^>]*>([0-9a-fA-F-]{8,})<')
              .firstMatch(f.readAsStringSync());
          if (m != null) return m.group(1);
        }
      }
    } catch (e) {
      debugPrint('AppCheck readDebugToken error: $e');
    }
    return null;
  }
}
