// lib/utils/battery_advice.dart
//
// نافذة العتاد الصيني — تُعرض مرة واحدة في عمر التثبيت عند أول اتصال
// (غنيمة جولة تاكسي طيبة 2026-08-20، وهي علاج شكوى المالك الفعلية:
// «التطبيق يختفي ثم يطلب تسجيل دخول» على شاومي).
//
// لماذا نافذة لا كوداً؟ خدمة المقدّمة عقد مع أندرويد الأصلي، وMIUI
// وEMUI وColorOS تنقضه: تقتل العملية ما لم يكن التطبيق في قائمة
// البطارية البيضاء. ومفتاح «التشغيل التلقائي» في شاومي **لا يقرؤه ولا
// يضبطه أي واجهة برمجية في أندرويد** — لا من التطبيق ولا من أي حزمة.
// فالطريق الوحيد أن يفعلها الكابتن بيده، ويُقال له ذلك بوضوح مرة واحدة.
//
// ولا نعلن REQUEST_IGNORE_BATTERY_OPTIMIZATIONS في البيان عمداً: يجرّ
// مراجعة إجبارية في Play لكل النكهات، والنصيحة لا تحتاجه. ولا نفحص
// حالة الاستثناء الحالية (يلزمها حزمة إذن جديدة): الفحص أعمى أصلاً عن
// مفتاح التشغيل التلقائي، فسائق مستثنى من قيود البطارية يُقتل مع ذلك —
// النص يُعرض كاملاً للجميع مرة واحدة.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _batteryAdviceKey = 'captain_battery_advice_shown';

/// حارس تزامن: نقرتا اتصال متسارعتان قبل أول ختم تكدّسان حوارين.
bool _showing = false;

/// تُستدعى عند تحوّل الكابتن إلى «متصل» — تعرض النصيحة في المرة الأولى
/// فقط ثم تصمت للأبد.
Future<void> showBatteryAdviceOnce(BuildContext context) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  if (_showing) return;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_batteryAdviceKey) ?? false) return;

  // الختم **بعد** الإغلاق لا قبل العرض (خلافاً لأصل الغنيمة — كشفه فاحص
  // الموثوقية): ختمٌ قبل العرض يعني أن فكّ الشاشة في الفجوة يحرق النصيحة
  // الوحيدة-في-عمر-التثبيت دون أن تُرى. أسوأ حالات الختم المتأخر أنها
  // تُعرض مرتين — وأسوأ حالات المبكر أنها لا تُعرض أبداً.
  if (!context.mounted) return;
  _showing = true;
  await showDialog<void>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('كي تبقى متصلاً والشاشة مقفلة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '١) إعدادات الهاتف ← التطبيقات ← تطبيق الكابتن ← البطارية — '
              'اختر «بلا قيود».',
            ),
            const SizedBox(height: 12),
            const Text(
              '٢) مع أجهزة شاومي وهواوي وأوبو فعّل أيضاً «التشغيل التلقائي» '
              '(Autostart) من إعدادات التطبيق.',
            ),
            const SizedBox(height: 12),
            const Text(
              '٣) ثبّت التطبيق في قائمة المهام الأخيرة (القفل الصغير) — '
              'إزالته من القائمة توقف عملك مهما كانت الإعدادات.',
            ),
            const SizedBox(height: 14),
            Text(
              'بدون ذلك قد يُغلق النظام التطبيق وأنت تعمل، فلا تصلك عروض '
              'ويختفي موقعك عن الإدارة والعملاء.',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx),
          child: const Text('فهمت'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dCtx);
            Geolocator.openAppSettings();
          },
          child: const Text('افتح الإعدادات'),
        ),
      ],
    ),
  );
  _showing = false;
  await prefs.setBool(_batteryAdviceKey, true);
}
