// اختبارات ساعات عمل المطعم المجدولة — منطق DaySchedule.isOpenAt الخالص.
// الحالة الأصعب: الدوام الذي يمتد بعد منتصف الليل (16:00→02:00) — خطؤه
// يُبقي المطعم «مفتوحاً» فجراً أو يغلقه ظهراً، فيطلب العميل من مطعم نائم
// أو يُحجب عن مطعمٍ يعمل. isOpenAt يأخذ الدقائق منذ منتصف الليل فيبقى
// حتمياً (بلا اعتماد على ساعة التشغيل) — لذا يُختبر مباشرةً.
import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

int _m(int h, int min) => h * 60 + min;

void main() {
  group('دوام نهاري عادي 09:00–23:00', () {
    const d = DaySchedule(open: '09:00', close: '23:00');
    test('مفتوح ظهراً', () => expect(d.isOpenAt(_m(12, 0)), isTrue));
    test('مغلق فجراً قبل الفتح', () => expect(d.isOpenAt(_m(8, 0)), isFalse));
    test('مغلق بعد الإغلاق', () => expect(d.isOpenAt(_m(23, 30)), isFalse));
    test('لحظة الفتح مفتوح', () => expect(d.isOpenAt(_m(9, 0)), isTrue));
    test('لحظة الإغلاق مغلق (النطاق نصف مفتوح)',
        () => expect(d.isOpenAt(_m(23, 0)), isFalse));
  });

  group('دوام يمتد بعد منتصف الليل 16:00–02:00', () {
    const d = DaySchedule(open: '16:00', close: '02:00');
    test('مفتوح مساءً', () => expect(d.isOpenAt(_m(20, 0)), isTrue));
    test('مفتوح بعد منتصف الليل قبل الإغلاق',
        () => expect(d.isOpenAt(_m(1, 0)), isTrue));
    test('مغلق بعد الإغلاق فجراً', () => expect(d.isOpenAt(_m(3, 0)), isFalse));
    test('مغلق نهاراً قبل الفتح', () => expect(d.isOpenAt(_m(15, 0)), isFalse));
  });

  group('حالات حدّية', () {
    test('اليوم المغلق مغلقٌ في كل لحظة', () {
      const d = DaySchedule(closed: true, open: '09:00', close: '23:00');
      expect(d.isOpenAt(_m(12, 0)), isFalse);
    });
    test('فتح = إغلاق ⇒ ٢٤ ساعة مفتوح', () {
      const d = DaySchedule(open: '00:00', close: '00:00');
      expect(d.isOpenAt(_m(3, 0)), isTrue);
      expect(d.isOpenAt(_m(18, 0)), isTrue);
    });
  });

  group('isOpenNow — التوافق الخلفي', () {
    test('مطعم بلا جدول: المفتاح اليدوي وحده يحكم', () {
      const open = Restaurant(
          id: 'r', name: 'م', description: '', emoji: '🍽️', phone: '',
          address: '', isOpen: true);
      const closed = Restaurant(
          id: 'r', name: 'م', description: '', emoji: '🍽️', phone: '',
          address: '', isOpen: false);
      expect(open.isOpenNow, isTrue); // بلا جدول + مفتوح يدوياً = مفتوح
      expect(closed.isOpenNow, isFalse); // المفتاح اليدوي سيّد
    });
  });
}
