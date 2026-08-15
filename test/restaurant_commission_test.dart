// اختبار العمولة التلقائية «مجاني حتى تاريخ» — effectiveCommissionPercent
// هي التي تُختم على الطلب، فخطؤها يجعل حملة «٣ شهور مجاناً» تجبي عمولةً
// في فترة الإعفاء، أو تُبقي الإعفاء بعد انتهائه. تُختبر بتواريخ نسبية
// للحظة التشغيل فتبقى حتمية.
import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

Restaurant _r({double percent = 15, DateTime? freeUntil}) => Restaurant(
      id: 'r', name: 'مطعم', description: '', emoji: '🍽️', phone: '',
      address: '', commissionPercent: percent, commissionFreeUntil: freeUntil);

void main() {
  group('العمولة الفعّالة', () {
    test('بلا تاريخ إعفاء: النسبة المضبوطة تسري فوراً', () {
      expect(_r(percent: 15).effectiveCommissionPercent, 15);
    });
    test('الإعفاء في المستقبل: العمولة صفرٌ فعلاً (وعد الحملة)', () {
      final future = DateTime.now().add(const Duration(days: 30));
      expect(_r(percent: 15, freeUntil: future).effectiveCommissionPercent, 0);
    });
    test('انتهى الإعفاء: النسبة المتفَّق عليها تعود تلقائياً', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(_r(percent: 15, freeUntil: past).effectiveCommissionPercent, 15);
    });
    test('نسبة صفر أصلاً تبقى صفراً (مطعم زادقو نفسه)', () {
      expect(_r(percent: 0).effectiveCommissionPercent, 0);
    });
  });
}
