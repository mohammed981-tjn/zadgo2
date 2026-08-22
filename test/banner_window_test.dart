// ت٢٦ (الفحص الشامل 2026-08-22): نافذة عرض البنر منطقٌ خالص كان بلا
// اختبار خلافاً لقاعدة المشروع — وحدّاها الدقيقان (آخر لحظة من يوم
// الانتهاء، ولحظة البدء نفسها) بلا كاشف. الدلالة المعتمدة في `isLiveAt`:
// البدء **شامل** (يظهر من لحظته) والانتهاء **حصري** (يختفي من لحظته) —
// فمن أراد «حتى نهاية اليوم» يضبط endsAt على منتصف ليل اليوم التالي.
import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

PromoBanner _banner({DateTime? startsAt, DateTime? endsAt}) => PromoBanner(
      id: 'b1',
      imageUrl: 'https://x/y.png',
      createdAt: DateTime(2026, 1, 1),
      startsAt: startsAt,
      endsAt: endsAt,
    );

void main() {
  final start = DateTime(2026, 8, 20);
  final end = DateTime(2026, 8, 25);

  group('بلا نافذة — يظهر دائماً', () {
    test('لا بداية ولا نهاية', () {
      expect(_banner().isLiveAt(DateTime(2026, 8, 22)), isTrue);
    });
  });

  group('حدّ البداية شامل', () {
    test('قبل البداية بثانية — مخفي', () {
      expect(
          _banner(startsAt: start)
              .isLiveAt(start.subtract(const Duration(seconds: 1))),
          isFalse);
    });
    test('لحظة البداية نفسها — ظاهر', () {
      expect(_banner(startsAt: start).isLiveAt(start), isTrue);
    });
  });

  group('حدّ النهاية حصري', () {
    test('قبل النهاية بثانية (آخر ثانية من الحملة) — ظاهر', () {
      expect(
          _banner(endsAt: end)
              .isLiveAt(end.subtract(const Duration(seconds: 1))),
          isTrue);
    });
    test('لحظة النهاية نفسها — مخفي', () {
      expect(_banner(endsAt: end).isLiveAt(end), isFalse);
    });
    test('بعد النهاية — مخفي (لا إعلان خالد)', () {
      expect(
          _banner(endsAt: end).isLiveAt(end.add(const Duration(days: 1))),
          isFalse);
    });
  });

  group('نافذة كاملة', () {
    final b = _banner(startsAt: start, endsAt: end);
    test('داخلها — ظاهر', () {
      expect(b.isLiveAt(DateTime(2026, 8, 22, 13)), isTrue);
    });
    test('نافذة مقلوبة (نهاية قبل بداية) — لا يظهر أبداً', () {
      final inverted = _banner(startsAt: end, endsAt: start);
      expect(inverted.isLiveAt(DateTime(2026, 8, 22)), isFalse);
    });
  });
}
