import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/utils/app_version.dart';

void main() {
  group('المقارنة رقمية لا نصية', () {
    // الفخّ الذي يُفشل البوابة بصمت: نصّياً '1.10.0' < '1.9.0'.
    test('1.10.0 أحدث من 1.9.0 — لا تُحجب', () {
      expect(isVersionBelow('1.10.0', '1.9.0'), isFalse);
    });

    test('1.9.0 أقدم من 1.10.0 — تُحجب', () {
      expect(isVersionBelow('1.9.0', '1.10.0'), isTrue);
    });

    test('المقارنة تتوقف عند أول جزء مختلف', () {
      expect(isVersionBelow('2.0.0', '10.0.0'), isTrue);
      expect(isVersionBelow('10.0.0', '2.0.0'), isFalse);
      expect(isVersionBelow('4.2.9', '4.3.0'), isTrue);
      expect(isVersionBelow('4.3.0', '4.2.9'), isFalse);
    });
  });

  group('التساوي والأجزاء الناقصة', () {
    test('نسخة تساوي الحد لا تُحجب', () {
      expect(isVersionBelow('4.0.0', '4.0.0'), isFalse);
    });

    test('الجزء الناقص يساوي صفراً', () {
      expect(isVersionBelow('4.1', '4.1.0'), isFalse);
      expect(isVersionBelow('4.1.0', '4.1'), isFalse);
      expect(isVersionBelow('4.1', '4.1.1'), isTrue);
      expect(isVersionBelow('4', '4.0.1'), isTrue);
    });
  });

  group('الفشل المفتوح — لا يُحجب أحد بقيمة معطوبة', () {
    test('حدّ فارغ أو أصفار = لا بوابة', () {
      expect(isVersionBelow('1.0.0', ''), isFalse);
      expect(isVersionBelow('1.0.0', '   '), isFalse);
      expect(isVersionBelow('1.0.0', '0.0.0'), isFalse);
    });

    test('حدّ غير رقمي لا يحجب ولا يرمي استثناءً', () {
      expect(isVersionBelow('1.0.0', 'أحدث نسخة'), isFalse);
      expect(isVersionBelow('1.0.0', 'v2'), isFalse);
    });

    test('إصدار حالي مجهول لا يُحجب', () {
      expect(isVersionBelow('', '9.9.9'), isFalse);
    });
  });

  group('لواحق البناء لا تُقارَن نصّاً', () {
    test('رقم البناء بعد + يُتجاهل', () {
      expect(isVersionBelow('4.0.0+17', '4.0.0'), isFalse);
      expect(isVersionBelow('4.0.0+1', '4.0.1'), isTrue);
    });

    test('لاحقة beta تُتجاهل', () {
      expect(isVersionBelow('4.0.0-beta', '4.0.0'), isFalse);
    });
  });

  test('إصدار التطبيق المدمج قابل للتفكيك', () {
    expect(isVersionBelow(kAppVersion, kAppVersion), isFalse);
    expect(isVersionBelow(kAppVersion, '999.0.0'), isTrue);
  });
}
