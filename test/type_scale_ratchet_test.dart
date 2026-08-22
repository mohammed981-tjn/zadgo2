// ت١٥ (الفحص الشامل 2026-08-22): المقياس الطباعي السباعي كان مستعملاً
// صفر مرة من أصل مئات المواضع، بلا أي كاشفٍ يمنع النزيف الجديد.
//
// هذا «اختبار سقّاطة» (ratchet): يحصي مواضع fontSize الخارجة عن درجات
// AppText السبع، ويفشل إن **زادت** عن خط الأساس المجمَّد — فالكود الجديد
// لا يضيف مقاساً شاذاً، والقديم يُهاجَر شاشةً شاشة فينخفض خط الأساس
// (حدِّثه نزولاً مع كل هجرة — لا صعوداً أبداً).
//
// يقرأ الملفات من القرص لأنه فحصُ مصدرٍ لا فحصُ سلوك — يعمل في CI حيث
// مجلد العمل جذر المشروع.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// درجات AppText السبع (theme.dart) — المرجع الوحيد للمقاسات.
const _scale = {'10.5', '11.5', '12.5', '13.5', '14.5', '17', '22'};

/// خط الأساس يوم تجميده (2026-08-22): ١٢٣ موضعاً خارج المقياس (بعد
/// هجرة الودجت المشترك). لا يُرفع أبداً؛ يُخفَّض مع كل هجرة شاشة.
const _baseline = 123;

void main() {
  test('لا نزيف مقاسات جديد خارج المقياس السباعي', () {
    final pattern = RegExp(r'fontSize:\s*([0-9.]+)');
    var offenders = 0;
    final samples = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final m in pattern.allMatches(src)) {
        final v = m.group(1)!.replaceFirst(RegExp(r'\.0$'), '');
        if (!_scale.contains(v)) {
          offenders++;
          if (samples.length < 5) samples.add('${f.path}: $v');
        }
      }
    }
    expect(offenders, lessThanOrEqualTo(_baseline),
        reason: 'مقاسات جديدة خارج المقياس السباعي — استعمل درجات AppText '
            'بدل رقمٍ حرّ. أمثلة أول المخالفات:\n${samples.join('\n')}');
  });
}
