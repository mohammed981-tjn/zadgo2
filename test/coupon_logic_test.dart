// اختبارات منطق الكوبون — discountFor هي التي تحسم كم تدفع المنصّة من
// جيبها لكل استخدام، وسقوفها الثلاثة (سقف الكوبون، سقف maxDiscount،
// سقف المبلغ نفسه) هي ما يمنع «20% على طلب 500» من ابتلاع دخل يوم كامل.
import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

Coupon _coupon({
  CouponType type = CouponType.percentage,
  double value = 20,
  double maxDiscount = 0,
  int usageLimit = 0,
  int usedCount = 0,
  DateTime? expiresAt,
}) =>
    Coupon(
      code: 'TEST',
      type: type,
      value: value,
      maxDiscount: maxDiscount,
      usageLimit: usageLimit,
      usedCount: usedCount,
      expiresAt: expiresAt,
      createdAt: DateTime(2026, 8, 1),
    );

void main() {
  group('حساب الخصم', () {
    test('النسبة: 20% من 100 = 20', () {
      expect(_coupon().discountFor(100), 20);
    });
    test('السقف يوقف النسبة الجامحة: 20% من 500 بسقف 15 = 15', () {
      expect(_coupon(maxDiscount: 15).discountFor(500), 15);
    });
    test('الثابت: 10 ر.س مهما كبر الطلب', () {
      expect(_coupon(type: CouponType.fixed, value: 10).discountFor(300), 10);
    });
    test('الخصم لا يتجاوز المبلغ نفسه أبداً — لا إجمالي سالب', () {
      // كوبون ثابت 50 على طلب 30: الخصم 30 لا 50، فلا تدفع المنصّة للعميل.
      expect(_coupon(type: CouponType.fixed, value: 50).discountFor(30), 30);
    });
  });

  group('الصلاحية', () {
    test('الاستنفاد: بلا حد (0) لا يستنفد أبداً، وبحدٍّ يستنفد عند بلوغه', () {
      expect(_coupon(usedCount: 9999).isExhausted, isFalse);
      expect(_coupon(usageLimit: 10, usedCount: 9).isExhausted, isFalse);
      expect(_coupon(usageLimit: 10, usedCount: 10).isExhausted, isTrue);
    });
    test('الانتهاء: بلا تاريخ لا ينتهي، وبتاريخٍ ماضٍ ينتهي', () {
      expect(_coupon().isExpired, isFalse);
      expect(_coupon(expiresAt: DateTime(2020)).isExpired, isTrue);
      expect(
          _coupon(expiresAt: DateTime.now().add(const Duration(days: 1)))
              .isExpired,
          isFalse);
    });
    test('إرجاع الكوبون بعد الإلغاء يعيده صالحاً: مستنفَد ناقصُه ١ يصلح', () {
      // جوهر «إرجاع كوبون الطلب الملغى» (نفذ ٢): إنقاص العدّاد يجب أن
      // يعيد الكود قابلاً للاستخدام فعلاً، وإلا كان الإرجاع شكلياً.
      expect(_coupon(usageLimit: 10, usedCount: 10).isExhausted, isTrue);
      expect(_coupon(usageLimit: 10, usedCount: 9).isExhausted, isFalse);
    });
  });
}
