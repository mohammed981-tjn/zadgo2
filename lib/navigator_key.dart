// مفتاح تنقّل عام (GlobalKey<NavigatorState>) في ملف مستقل عن lib/main.dart
// عمداً: شاشات أدوار محددة (مثل driver_home.dart) تحتاج الوصول إليه (مثلاً
// للتنقل من إشعار push دون سياق محلي)، ولو استوردته من main.dart لجرّت معها
// شجرة استيراد main.dart كاملة (كل شاشات الأدوار الأخرى)، فتنكسر الفصل على
// مستوى الحزمة بين نكهات التطبيق (عميل/سائق/مطعم/أدمن/كامل).
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
