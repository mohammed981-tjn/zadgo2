// اختبارات دورة الشكوى (نفذ ٢) — مهلة الرد المعلنة ورقم العرض وتمييز
// التذكرة العامة: وعد «نردّ خلال ٢٤ ساعة» صار واجهةً عند الشاكي وعدّاداً
// أحمر عند المدير، فانزياحه سهواً يكذب على الطرفين معاً.
import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

Complaint _complaint({
  String id = 'abc123-def456',
  String orderId = 'o1',
  ComplaintStatus status = ComplaintStatus.open,
  required DateTime createdAt,
}) =>
    Complaint(
      id: id,
      orderId: orderId,
      orderNumber: '123456',
      customerId: 'u1',
      customerName: 'عميل',
      type: ComplaintType.other,
      description: 'وصف',
      status: status,
      createdAt: createdAt,
    );

void main() {
  final t0 = DateTime(2026, 8, 12, 10, 0);

  group('مهلة الرد', () {
    test('الموعد الموعود = التقديم + ٢٤ ساعة بالضبط', () {
      expect(_complaint(createdAt: t0).expectedResponseBy,
          t0.add(const Duration(hours: 24)));
    });
  });

  group('بانتظار المعالجة', () {
    test('المفتوحة و«قيد المعالجة» كلتاهما بانتظار الإدارة', () {
      // «قيد المعالجة» (نفذ ٢) ما تزال ديْناً على الإدارة — إسقاطها من
      // العدّ يُخفي شكاوى بدأ العمل عليها ثم نُسيت.
      expect(_complaint(createdAt: t0).isAwaitingAction, isTrue);
      expect(
          _complaint(createdAt: t0, status: ComplaintStatus.inProgress)
              .isAwaitingAction,
          isTrue);
      expect(
          _complaint(createdAt: t0, status: ComplaintStatus.resolved)
              .isAwaitingAction,
          isFalse);
      expect(
          _complaint(createdAt: t0, status: ComplaintStatus.closed)
              .isAwaitingAction,
          isFalse);
    });
  });

  group('رقم العرض', () {
    test('أول ٦ خانات بلا شُرط وبأحرف كبيرة — ثابت يُملى هاتفياً', () {
      expect(_complaint(createdAt: t0).displayNumber, 'ABC123');
    });
    test('معرّف قصير يُعرض كاملاً', () {
      expect(_complaint(id: 'ab-1', createdAt: t0).displayNumber, 'AB1');
    });
  });

  group('التذكرة العامة', () {
    test('بلا طلب = تذكرة، وبطلب = شكوى طلب', () {
      expect(_complaint(orderId: '', createdAt: t0).isGeneralTicket, isTrue);
      expect(_complaint(orderId: '  ', createdAt: t0).isGeneralTicket, isTrue);
      expect(_complaint(createdAt: t0).isGeneralTicket, isFalse);
    });
  });
}
