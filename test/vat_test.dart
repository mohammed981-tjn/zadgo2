import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/utils/helpers.dart';

// حساب الضريبة رقمٌ يُطبع للعميل والإدارة في ستة مواضع ولم يكن له اختبار —
// وقد عاش في السلة حاسمٌ ميت يجمعها **فوق** الإجمالي (احتساب مضاعف) حتى
// حُذف في دفعة «صدق الأرقام». هذا الملف يثبّت المعادلة الوحيدة المعتمدة:
// الأسعار شاملة الضريبة وتُستخرج منها (المبلغ × 15 ÷ 115)، فأي نكوصٍ
// مستقبلي لصيغة الجمع يكسر CI قبل أن يبلغ فاتورة.
void main() {
  group('الضريبة المتضمَّنة (vatIncludedIn)', () {
    test('115 شاملة الضريبة تحوي 15 ضريبةً بالضبط', () {
      expect(Pricing.vatIncludedIn(115), closeTo(15, 1e-9));
    });

    test('الصفر يعطي صفراً', () {
      expect(Pricing.vatIncludedIn(0), 0);
    });

    test('الاستخراج لا الجمع: قيمة الضريبة أقل من المبلغ × 15%', () {
      // صيغة الجمع الخاطئة كانت تعطي 100 × 0.15 = 15، والصحيحة تعطي
      // 100 × 15 ÷ 115 ≈ 13.04 — الفارق هو الاحتساب المضاعف بعينه.
      expect(Pricing.vatIncludedIn(100), closeTo(13.0434782609, 1e-6));
      expect(Pricing.vatIncludedIn(100), lessThan(100 * Pricing.vatRate));
    });

    test('الصافي + ضريبته المستخرَجة يعيدان المبلغ الشامل (تطابق ذهاباً وإياباً)', () {
      const gross = 237.5;
      final vat = Pricing.vatIncludedIn(gross);
      final net = gross - vat;
      expect(net * (1 + Pricing.vatRate), closeTo(gross, 1e-9));
    });
  });
}
