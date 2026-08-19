import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

void main() {
  const s = IncentiveSettings();

  group('الافتراضيات المعتمدة', () {
    test('مبالغ الإحالة وشرطها', () {
      expect(s.referrerBonus, 50);
      expect(s.refereeBonus, 30);
      expect(s.referralDeliveries, 30);
      expect(s.referralWindowDays, 30);
    });

    test('التحدي: الخميس والجمعة بمستويين', () {
      expect(s.challengeWeekdays, [DateTime.thursday, DateTime.friday]);
      expect(s.tiers.length, 2);
      expect(s.weekdaysLabel, 'الخميس والجمعة');
    });
  });

  group('مستويات التحدي', () {
    test('يُصرف أعلى مستوى بلغه لا مجموعها', () {
      expect(s.tierFor(9), isNull);
      expect(s.tierFor(10)!.bonus, 20);
      expect(s.tierFor(19)!.bonus, 20);
      expect(s.tierFor(20)!.bonus, 50);
      expect(s.tierFor(100)!.bonus, 50);
    });

    test('المستوى التالي يوجّه السائق', () {
      expect(s.nextTierFor(0)!.deliveries, 10);
      expect(s.nextTierFor(10)!.deliveries, 20);
      expect(s.nextTierFor(20), isNull);
    });
  });

  group('نافذة التحدي', () {
    test('الخميس والجمعة نافذة واحدة ممتدة لا يومان منفصلان', () {
      // 2026-08-13 خميس، 2026-08-14 جمعة.
      final thu = DateTime(2026, 8, 13, 20);
      final fri = DateTime(2026, 8, 14, 2);
      final wThu = s.currentWindow(thu)!;
      final wFri = s.currentWindow(fri)!;
      expect(wThu.$1, DateTime(2026, 8, 13));
      expect(wThu.$2.day, 14);
      expect(wFri.$1, wThu.$1, reason: 'نفس النافذة لليومين');
      expect(wFri.$2, wThu.$2);
    });

    test('خارج أيام التحدي لا نافذة', () {
      expect(s.currentWindow(DateTime(2026, 8, 11)), isNull); // ثلاثاء
    });

    test('التحدي الموقوف أو بلا مستويات لا نافذة له', () {
      expect(
          s.copyWith(challengeEnabled: false).currentWindow(DateTime(2026, 8, 13)),
          isNull);
      expect(s.copyWith(tiers: const []).currentWindow(DateTime(2026, 8, 13)),
          isNull);
    });
  });

  group('الحفظ والقراءة', () {
    test('دورة كاملة تحفظ كل الحقول', () {
      final custom = s.copyWith(
        referrerBonus: 80,
        referralDeliveries: 15,
        challengeWeekdays: [DateTime.friday],
        tiers: const [ChallengeTier(deliveries: 5, bonus: 15)],
      );
      final back = IncentiveSettings.fromMap(custom.toMap());
      expect(back.referrerBonus, 80);
      expect(back.referralDeliveries, 15);
      expect(back.challengeWeekdays, [DateTime.friday]);
      expect(back.tiers.single.bonus, 15);
    });

    test('مستند فارغ يعطي الافتراضيات — يعمل من أول تشغيل', () {
      final d = IncentiveSettings.fromMap(const {});
      expect(d.referrerBonus, 50);
      expect(d.tiers.length, 2);
    });

    test('المستويات تُرتَّب تصاعدياً مهما كان ترتيب الإدخال', () {
      final m = s.toMap();
      m['tiers'] = [
        {'deliveries': 30, 'bonus': 90},
        {'deliveries': 10, 'bonus': 20},
      ];
      final back = IncentiveSettings.fromMap(m);
      expect(back.tiers.map((t) => t.deliveries), [10, 30]);
      expect(back.tierFor(30)!.bonus, 90);
    });
  });

  group('رابط الدعوة', () {
    test('يُلحق ref بالرابط', () {
      expect(const IncentiveSettings().inviteLinkFor('A1B2C3'),
          'https://zadgo.co/join?ref=A1B2C3');
    });

    test('رابط فيه معاملات مسبقة يستخدم & لا ?', () {
      expect(
          const IncentiveSettings(joinUrl: 'https://x.co/j?src=app')
              .inviteLinkFor('ZZ99'),
          'https://x.co/j?src=app&ref=ZZ99');
    });

    test('رابط فارغ يعطي نصاً فارغاً فتُعرض رسالة الكود بدله', () {
      expect(const IncentiveSettings(joinUrl: '  ').inviteLinkFor('A1'), '');
    });
  });

  test('مفتاح النافذة بصيغة موحّدة قابلة للمقارنة', () {
    expect(IncentiveSettings.windowKey(DateTime(2026, 8, 13)), '2026-08-13');
    expect(IncentiveSettings.windowKey(DateTime(2026, 12, 3)), '2026-12-03');
  });

  test('كود الإحالة مشتقّ من المعرّف وثابت', () {
    const d = Driver(
        id: 'aB3xY9zQwErT', name: 'سعد', phone: '05', vehicleType: 'دراجة');
    expect(d.referralCode, 'AB3XY9');
    expect(d.referralCode, d.referralCode);
  });

  group('نقطة التعادل اليومية', () {
    test('الافتراضي صفر = البطاقة مخفية (لا رقم مبرمَج — ج١)', () {
      expect(s.dailyOrdersTarget, 0);
    });

    test('تذهب وتعود عبر toMap/fromMap', () {
      final restored = IncentiveSettings.fromMap(
          const IncentiveSettings(dailyOrdersTarget: 64).toMap());
      expect(restored.dailyOrdersTarget, 64);
    });

    test('مستند قديم بلا الحقل يعود للافتراضي لا يكسر القراءة', () {
      expect(IncentiveSettings.fromMap(const {}).dailyOrdersTarget, 0);
    });
  });
}
