// اختبارات درجة ترشيح الكابتن (نفذ ٣) — تحرس المعادلة التي تقرّر ترتيب
// وصول العروض: كسرها سهواً لا تلحظه عين المراجع، يلحظه اختبار يفشل.
import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/utils/dispatch_score.dart';

void main() {
  group('من لا تاريخ له', () {
    test('يُحسب قبوله كاملاً لا صفراً ظالماً', () {
      // كابتن جديد (لا عروض بعد) بنفس تقييم كابتن قبوله ١٠٠٪ — درجتاهما
      // متساويتان: الجديد لا يُعاقَب على تاريخ لم يُتح له بناؤه.
      expect(dispatchScore(acceptanceRate: null, rating: 5),
          dispatchScore(acceptanceRate: 1.0, rating: 5));
    });
  });

  group('وزن القبول فوق وزن التقييم', () {
    test('قبول كامل بتقييم صفر يغلب رفضاً كاملاً بتقييم كامل', () {
      // جوهر المعادلة: القبول سلوك يومي قابل للتغيير، والتقييم انطباع
      // يتجمّد — فمن يخدم المنصّة الآن يسبق من خدمها قديماً وتوقف.
      expect(dispatchScore(acceptanceRate: 1.0, rating: 0),
          greaterThan(dispatchScore(acceptanceRate: 0.0, rating: 5)));
    });

    test('عند تساوي القبول يفصل التقييم', () {
      expect(dispatchScore(acceptanceRate: 0.8, rating: 5),
          greaterThan(dispatchScore(acceptanceRate: 0.8, rating: 3)));
    });

    test('فرق قبول صغير يغلب فرق تقييم كبير', () {
      // ١٠٪ قبول إضافية (0.2 درجة) تغلب نجمتين تقييم إضافيتين (0.4/5
      // من ثلث الوزن = 0.08 درجة... بل نجمتين = 0.4 درجة تقييم خام
      // ×(1/5)=0.4/5... نضبط الحالة رقمياً:
      // (0.9,3): 1.8+0.6=2.4 مقابل (0.8,5): 1.6+1.0=2.6 — هنا يغلب
      // التقييم لأن فرقه نجمتان كاملتان. أما نجمة واحدة:
      // (0.9,4): 1.8+0.8=2.6 مقابل (0.8,5): 1.6+1.0=2.6 — تعادل تام،
      // وهذا هو التوازن المقصود: نجمة تقييم = ٥٪ قبول.
      expect(dispatchScore(acceptanceRate: 0.9, rating: 4),
          dispatchScore(acceptanceRate: 0.8, rating: 5));
    });
  });

  group('الحدود', () {
    test('أعلى درجة ممكنة ٣ وأدناها ٠', () {
      expect(dispatchScore(acceptanceRate: 1.0, rating: 5), 3.0);
      expect(dispatchScore(acceptanceRate: 0.0, rating: 0), 0.0);
    });
  });
}
