// اختبارات الحسابات المالية للطلب — المعادلة التي تتوزع بها كل ريالات
// المنصّة: قيمة الوجبات، العمولة، الأجرة، الخصم، وصافي المطعم. هذه
// الأرقام تظهر في فاتورة العميل ودفتر المطعم وتقرير الإدارة معاً —
// فانحرافها سهواً يكذب على ثلاثة أطراف دفعة واحدة.
import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

Order _order({
  List<OrderItem>? items,
  double driverShare = 7,
  double appShare = 3,
  double discountAmount = 0,
  double walletUsed = 0,
  double restaurantChargeback = 0,
}) =>
    Order(
      id: 'o1',
      restaurantId: 'r1',
      restaurantName: 'مطعم',
      customerId: 'c1',
      customerName: 'عميل',
      customerPhone: '05',
      deliveryAddress: 'عنوان',
      items: items ??
          const [
            OrderItem(menuItemId: 'm1', name: 'كبسة', price: 30, emoji: '🍛', quantity: 2),
            OrderItem(menuItemId: 'm2', name: 'سلطة', price: 8, emoji: '🥗'),
          ],
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime(2026, 8, 13),
      driverShare: driverShare,
      appShare: appShare,
      orderNumber: '123456',
      discountAmount: discountAmount,
      walletUsed: walletUsed,
      restaurantChargeback: restaurantChargeback,
    );

void main() {
  group('سلسلة القيم الأساسية', () {
    // الأصناف: 30×2 + 8 = 68، التوصيل: 7+3 = 10
    test('قيمة الوجبات = مجموع (سعر × كمية)', () {
      expect(_order().itemsTotal, 68);
    });
    test('أجرة التوصيل = أجرة الكابتن + رسم المنصّة', () {
      expect(_order().deliveryFee, 10);
    });
    test('الإجمالي = وجبات + توصيل', () {
      expect(_order().grandTotal, 78);
    });
  });

  group('الخصم والدفع', () {
    test('ما يدفعه العميل = الإجمالي − الخصم', () {
      expect(_order(discountAmount: 12).payableTotal, 66);
    });
    test('خصم المحفظة لا يغيّر القيمة المستحقة — دفعٌ من رصيده لا تخفيض', () {
      expect(_order(walletUsed: 20).payableTotal, 78);
    });
  });

  group('حصص الأطراف', () {
    test('عمولة الوجبات للتقارير = 15% محسوبة دائماً لا مخزَّنة', () {
      // طلب قديم بعمولة مخزَّنة خاطئة يجب أن يُقرأ بالقاعدة الثابتة.
      expect(_order().effectiveCommission, closeTo(68 * 0.15, 0.001));
    });
    test('صافي المطعم = الوجبات − العمولة', () {
      expect(_order().restaurantNet, closeTo(68 - 10.2, 0.001));
    });
    test('خصم شكوى الجودة يُقرأ من الحقل ولا يمسّ صافي الطلب المحسوب', () {
      // الطرح يقع في الدفاتر (المستحق التراكمي) لا في getter الطلب —
      // فبطاقة الطلب تعرض الصافي الأصلي وسطر الخصم منفصلاً تحته.
      final o = _order(restaurantChargeback: 15);
      expect(o.restaurantChargeback, 15);
      expect(o.restaurantNet, closeTo(57.8, 0.001));
    });
  });
}
