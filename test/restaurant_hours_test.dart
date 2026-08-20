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

  group('وردية أمس الممتدة بعد منتصف الليل (مراجعة 2026-08-15)', () {
    // الخميس (4) دوام 16:00→02:00 والجمعة (5) إجازة كاملة: فجر الجمعة
    // 01:00 وردية الخميس ما زالت قائمة — كان جدول «اليوم الجديد» وحده
    // يحكم فيغلق المطعم قبل موعده بساعتين.
    final hours = {
      DateTime.thursday: const DaySchedule(open: '16:00', close: '02:00'),
      DateTime.friday: const DaySchedule(closed: true),
    };
    test('فجر الجمعة 01:00 = وردية الخميس مفتوحة', () {
      expect(Restaurant.scheduleOpenAt(hours, DateTime.friday, _m(1, 0)),
          isTrue);
    });
    test('فجر الجمعة 03:00 = انتهت الوردية والجمعة إجازة', () {
      expect(Restaurant.scheduleOpenAt(hours, DateTime.friday, _m(3, 0)),
          isFalse);
    });
    test('ظهر الجمعة = إجازة فعلاً', () {
      expect(Restaurant.scheduleOpenAt(hours, DateTime.friday, _m(12, 0)),
          isFalse);
    });
    test('الأحد (7) يمتد لفجر الاثنين (1) — لفّة نهاية الأسبوع', () {
      final h = {
        DateTime.sunday: const DaySchedule(open: '16:00', close: '01:00'),
        DateTime.monday: const DaySchedule(closed: true),
      };
      expect(Restaurant.scheduleOpenAt(h, DateTime.monday, _m(0, 30)),
          isTrue);
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

  group('الإيقاف المؤقت pausedUntil (يوم المطعم 2026-08-20)', () {
    // الموعد يُبنى بعيداً عن «الآن» بيوم كامل فتبقى النتيجة حتمية مهما
    // كانت لحظة تشغيل الاختبار — من دون حقن ساعة وهمية.
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    Restaurant r({bool isOpen = true, DateTime? pausedUntil}) => Restaurant(
        id: 'r', name: 'م', description: '', emoji: '🍽️', phone: '',
        address: '', isOpen: isOpen, pausedUntil: pausedUntil);

    test('موعد الاستئناف في المستقبل = موقوف الآن', () {
      expect(r(pausedUntil: tomorrow).isPausedNow, isTrue);
      expect(r(pausedUntil: tomorrow).isOpenNow, isFalse);
    });

    test('الاستئناف تلقائي: موعدٌ مضى لا يوقف شيئاً', () {
      expect(r(pausedUntil: yesterday).isPausedNow, isFalse);
      expect(r(pausedUntil: yesterday).isOpenNow, isTrue);
    });

    test('بلا موعد = لا إيقاف', () {
      expect(r().isPausedNow, isFalse);
    });

    test('التسمية الصادقة: «مشغول مؤقتاً» بموعد الاستئناف لا «مغلق»', () {
      final hh = tomorrow.hour.toString().padLeft(2, '0');
      final mm = tomorrow.minute.toString().padLeft(2, '0');
      expect(r(pausedUntil: tomorrow).openStatusLabel,
          'مشغول مؤقتاً — يستأنف $hh:$mm');
    });

    test('المفتاح اليدوي أشد من الإيقاف: مغلقٌ يدوياً يبقى «مغلق»', () {
      expect(r(isOpen: false, pausedUntil: tomorrow).openStatusLabel, 'مغلق');
    });
  });
}
