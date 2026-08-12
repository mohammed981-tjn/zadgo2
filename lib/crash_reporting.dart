// lib/crash_reporting.dart
//
// تسجيل الانهيارات (Crashlytics) — دفعة و1، ٢٠٢٦-٠٨-١٢.
//
// قبلها كنّا **عُمياناً تماماً**: ينهار تطبيق كابتن وهو يقود فلا نعلم به
// إلا إن اتصل صاحبه وشكا، ولا نعرف السطر ولا الجهاز ولا كم مرة تكرّر.
// وأخطر ما في ذلك أن الانهيار الصامت يُقرأ عند المستخدم «التطبيق خربان»
// لا «فيه عطل في شاشة كذا» — فيُحذف التطبيق ولا يصلنا سبب.
//
// موحَّدة في ملف واحد تناديه النكهات الأربع: الإعداد الصحيح ثمانية أسطر
// دقيقة، وتكرارها أربع مرات في ملفات الدخول يعني أن تصحيحاً في واحدة
// يُنسى في ثلاث.
//
// مجانية بالكامل على خطة Spark — لا علاقة لها بترقية Blaze.
import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// يوصّل مصائد الأخطاء الثلاث بـCrashlytics.
///
/// [flavor] يُختم على كل تقرير مفتاحاً مخصصاً، فتُقرأ لوحة Crashlytics
/// مقسَّمةً بالنكهة: انهيارٌ يصيب الكابتن وحده مسألة تشغيلية عاجلة،
/// وانهيارٌ يصيب النكهات الأربع معاً عطلٌ في الشيفرة المشتركة.
Future<void> initCrashReporting({required String flavor}) async {
  final crashlytics = FirebaseCrashlytics.instance;

  // لا نرسل من أجهزة التطوير: انهيارات جهاز المبرمج وهو يجرّب تُغرق
  // اللوحة وتُخفي انهيارات الميدان الحقيقية تحتها.
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  await crashlytics.setCustomKey('flavor', flavor);

  // ١) أخطاء إطار Flutter (بناء ودجت، تخطيط، رسم).
  //    السلوك السابق يُستدعى أولاً فيبقى الخطأ ظاهراً في سجلّ التطوير —
  //    الاستبدال الأعمى كان سيُسكت الطباعة على المبرمج نفسه.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousOnError?.call(details);
    crashlytics.recordFlutterFatalError(details);
  };

  // ٢) أخطاء غير متزامنة خارج منطقة Flutter (Future بلا catch مثلاً) —
  //    وهي مصدر أكثر الانهيارات الصامتة عندنا لأن أغلب الشيفرة نداءات
  //    Firestore غير متزامنة.
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}
