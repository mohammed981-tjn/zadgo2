import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/utils/helpers.dart';

// تطبيع البحث العربي (لمسات العميل 2026-08-20): أكثر مستخدمينا لا يضبط
// الهمزات ولا التاء المربوطة، فالبحث الحرفي يعاقبهم بنتائج صفرية على
// مطعمٍ موجود. هذه الاختبارات تثبّت أن المتغيّرات الإملائية الشائعة
// تلتقي بعد التطبيع — وأن التطبيع لا يمحو تمييزاً حقيقياً (حرفان
// مختلفان لا يُدمجان بلا داعٍ).
void main() {
  group('normalizeArabic — توحيد المتغيّرات الإملائية', () {
    test('الألفات بأنواعها تصير ألفاً واحدة', () {
      expect(normalizeArabic('أحمد'), normalizeArabic('احمد'));
      expect(normalizeArabic('إبراهيم'), normalizeArabic('ابراهيم'));
      expect(normalizeArabic('آدم'), normalizeArabic('ادم'));
    });

    test('التاء المربوطة والهاء تلتقيان', () {
      expect(normalizeArabic('شاورمة'), normalizeArabic('شاورمه'));
    });

    test('الألف المقصورة والياء تلتقيان', () {
      expect(normalizeArabic('مقهى'), normalizeArabic('مقهي'));
    });

    test('التشكيل والتطويل يُحذفان', () {
      expect(normalizeArabic('مَطْعَم'), normalizeArabic('مطعم'));
      expect(normalizeArabic('بـــيك'), normalizeArabic('بيك'));
    });

    test('المسافات الزائدة تُوحَّد والحالة اللاتينية تُصغَّر', () {
      expect(normalizeArabic('  Pizza   Hut '), 'pizza hut');
    });
  });

  group('normalizedContains — بحث متسامح', () {
    test('«البيك» تجد «مطعم البيك» بالهمزة', () {
      expect(normalizedContains('مطعم البيك', 'البيك'), isTrue);
    });

    test('«شاورمه» تجد صنف «شاورمة دجاج»', () {
      expect(normalizedContains('شاورمة دجاج', 'شاورمه'), isTrue);
    });

    test('نصٌّ غير موجود لا يُطابَق زوراً', () {
      expect(normalizedContains('مطعم البيك', 'كنتاكي'), isFalse);
    });

    test('لا يدمج كلمتين مختلفتين فعلاً', () {
      // «برجر» و«بقر» يختلفان في أكثر من حرف — التطبيع لا يقرّبهما.
      expect(normalizedContains('برجر', 'بقر'), isFalse);
    });
  });
}
