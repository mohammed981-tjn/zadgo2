// اختبار أجرة التوصيل المضبوطة من اللوحة (IncentiveSettings.deliveryFeeFor).
// الأجرة موحّدة لكل السائقين وتُحسب من إعدادات المدير لا من ثوابت الكود —
// خطؤها يظلم السائق أو العميل في كل طلب. الكسور تُجبر للأعلى (9.8كم → 10).
import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

void main() {
  group('الأجرة بالإعداد الافتراضي (٩ لأول ٧ كم + ١/كم)', () {
    const s = IncentiveSettings();
    test('ضمن المدى الأساسي = الأساس', () {
      expect(s.deliveryFeeFor(5), 9);
      expect(s.deliveryFeeFor(7), 9);
    });
    test('كسر كم زائد يُجبر للأعلى', () {
      expect(s.deliveryFeeFor(7.1), 10); // extra 0.1 → 1
      expect(s.deliveryFeeFor(9.8), 12); // extra 2.8 → 3
    });
    test('كم صحيحة زائدة', () {
      expect(s.deliveryFeeFor(10), 12); // 9 + 3×1
    });
  });

  group('إعداد مخصّص من اللوحة', () {
    const s = IncentiveSettings(
        deliveryBaseFee: 12, deliveryBaseKm: 5, deliveryPerKmFee: 2);
    test('أساس وكم مجانية ولكل كم مختلفة', () {
      expect(s.deliveryFeeFor(5), 12);
      expect(s.deliveryFeeFor(8), 18); // 12 + 3×2
    });
  });

  group('نطاق التوصيل', () {
    const s = IncentiveSettings(maxDeliveryDistanceKm: 25);
    test('داخل النطاق وخارجه', () {
      expect(s.isOutOfRange(20), isFalse);
      expect(s.isOutOfRange(25), isFalse);
      expect(s.isOutOfRange(25.1), isTrue);
    });
  });
}
