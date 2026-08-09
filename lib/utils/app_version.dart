// lib/utils/app_version.dart
//
// إصدار التطبيق الحالي ومقارنته بالحدّ الأدنى الذي تفرضه الإدارة.
//
// لماذا ثابتٌ من البيئة لا حزمة package_info_plus: إضافة حزمة جديدة تعني
// «دفعة حزم» معزولة بإصدار مثبَّت (بند أ٦)، وهذه البوابة أعجل من ذلك.
// الإصدار يُحقن وقت البناء من pubspec نفسه، فلا رقم مكرّر يدوياً يتخلّف.
const String kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '4.0.0');

/// هل [current] أقدم من [minimum]؟
///
/// **المقارنة رقمية لا نصية** — وهذا بيت القصيد: نصّياً `'1.10.0'` أصغر
/// من `'1.9.0'` (لأن '1' < '9')، فبوابةٌ تقارن النصوص تسمح لنسخة أقدم
/// بالمرور وتحجب أحدث منها، وتفشل بصمت لا برسالة.
///
/// الأجزاء الناقصة تُعدّ أصفاراً (`4.1` == `4.1.0`)، وأي جزء غير رقمي
/// يُعدّ صفراً فلا ترمي الدالة استثناءً على قيمة أدخلها المدير بالخطأ.
bool isVersionBelow(String current, String minimum) {
  final min = _parts(minimum);
  // حدّ فارغ أو بلا أي رقم = لا بوابة.
  if (min.isEmpty || min.every((p) => p == 0)) return false;
  final cur = _parts(current);
  if (cur.isEmpty) return false; // إصدار مجهول: لا يُحجب (فشل مفتوح).

  final length = cur.length > min.length ? cur.length : min.length;
  for (var i = 0; i < length; i++) {
    final c = i < cur.length ? cur[i] : 0;
    final m = i < min.length ? min[i] : 0;
    if (c != m) return c < m;
  }
  return false; // متساويان
}

/// يفكّك «4.1.2» إلى [4, 1, 2]، ويتجاهل ما بعد `+` (رقم البناء) و`-`
/// (لواحق مثل beta) فلا تُقارَن نصوصٌ ليست أرقاماً.
List<int> _parts(String raw) {
  final cleaned = raw.trim().split('+').first.split('-').first;
  if (cleaned.isEmpty) return const [];
  return cleaned
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList(growable: false);
}
