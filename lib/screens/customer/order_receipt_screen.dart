// lib/screens/customer/order_receipt_screen.dart
//
// فاتورة الطلب — شاشة تفاصيل بنمط الإيصال (نمط مأخوذ من قالب wasl ومُوسَّع):
// رقم الطلب بارزاً، الأصناف بكمياتها، تفصيل الرسوم كاملاً (وجبات/توصيل/رسم
// ثابت/خصم محفظة)، الضريبة المتضمَّنة (متطلب ZATCA)، طريقة الدفع، الأطراف
// والعناوين، وأزمنة الطلب.
//
// كانت فجوة موثّقة أمام المنافسين: العميل لا يرى بعد الطلب إلا بطاقة مختصرة
// بلا فاتورة تفصيلية يثق بها أو يرجع إليها عند نزاع.
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/app_lang.dart';
import '../../widgets/common_widgets.dart';

class OrderReceiptScreen extends StatelessWidget {
  final Order order;
  const OrderReceiptScreen({super.key, required this.order});

  String _fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Scaffold(
      appBar: AppBar(title: Text(tr('فاتورة الطلب', 'Order receipt'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // الترويسة: رقم الطلب والحالة
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('#${o.orderNumber}',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              StatusBadge(
                  label: o.status.label,
                  color: o.status.color,
                  icon: o.status.icon),
              const SizedBox(height: 6),
              Text(
                  tr('أُنشئ في ${_fmt(o.createdAt)}',
                      'Placed on ${_fmt(o.createdAt)}'),
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textGray)),
              // سلسلة العهدة موثّقة بطرفيها: وصول الكابتن للمطعم، وإقرار
              // المطعم بالتسليم (ختمٌ يضغطه صاحب المطعم بنفسه) — بهما يُفصل
              // في نزاع «متى خرج الطلب؟» بلا اجتهاد.
              if (o.arrivedAtRestaurantAt != null)
                Text(
                    tr('وصل الكابتن للمطعم ${_fmt(o.arrivedAtRestaurantAt!)}',
                        'Captain arrived at the restaurant ${_fmt(o.arrivedAtRestaurantAt!)}'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textGray)),
              if (o.restaurantHandoverAt != null)
                Text(
                    tr('أقرّ المطعم بالتسليم ${_fmt(o.restaurantHandoverAt!)}',
                        'Restaurant confirmed handover ${_fmt(o.restaurantHandoverAt!)}'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textGray)),
              if (o.status == OrderStatus.delivered && o.statusChangedAt != null)
                Text(
                    tr('سُلّم في ${_fmt(o.statusChangedAt!)}',
                        'Delivered on ${_fmt(o.statusChangedAt!)}'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.success)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // الأصناف
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('الأصناف', 'Items'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5)),
              const SizedBox(height: 8),
              ...o.items.map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Text('${i.quantity}×',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.name, style: const TextStyle(fontSize: 14.5)),
                              if ((i.extras ?? '').trim().isNotEmpty)
                                Text(i.extras!,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textGray)),
                            ]),
                      ),
                      Text(formatCurrency(i.subtotal),
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ]),
                  )),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // تفصيل الرسوم — بنفس أسماء ملخص الدفع حرفياً، فلا يفاجأ العميل
        // باسم رسم لم يره وقت الشراء.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              PriceRow(
                  label: tr('الوجبات', 'Food'),
                  value: formatCurrency(o.itemsTotal)),
              // التوصيل سطر واحد شامل (أجرة السائق + الرسم الثابت) — قاعدة
              // المالك، ومطابق حرفياً لسطر ملخص الدفع فلا مفاجأة في الفاتورة.
              PriceRow(
                  label: tr('التوصيل', 'Delivery'),
                  value: formatCurrency(o.deliveryFee)),
              if (o.driverTip > 0)
                PriceRow(
                    label: tr('إكرامية الكابتن (تصله كاملة)',
                        'Captain tip (goes to them in full)'),
                    value: formatCurrency(o.driverTip)),
              if (o.discountAmount > 0)
                PriceRow(
                    label: tr('خصم الكود ${o.couponCode ?? ''}',
                            'Promo code ${o.couponCode ?? ''}')
                        .trim(),
                    value: '- ${formatCurrency(o.discountAmount)}'),
              if (o.walletUsed > 0)
                PriceRow(
                    label: tr('خصم من المحفظة', 'Wallet credit'),
                    value: '- ${formatCurrency(o.walletUsed)}'),
              const Divider(),
              PriceRow(
                  label: tr('الإجمالي', 'Total'),
                  value: formatCurrency(o.payableTotal),
                  bold: true),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tr('شامل ضريبة القيمة المضافة (15٪)', 'Includes 15% VAT'),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                    Text(formatCurrency(Pricing.vatIncludedIn(o.payableTotal)),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(tr('طريقة الدفع', 'Payment method'),
                    style: const TextStyle(fontSize: 12.5)),
                Row(children: [
                  Icon(
                      o.paymentMethod == PaymentMethod.cash
                          ? Icons.payments_outlined
                          : Icons.credit_card,
                      size: 15,
                      color: AppColors.textGray),
                  const SizedBox(width: 4),
                  Text(o.paymentMethod.label,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  if (o.isPaid) ...[
                    const SizedBox(width: 6),
                    StatusChip(
                        label: tr('مدفوع', 'Paid'), color: AppColors.success),
                  ],
                ]),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // الأطراف والعنوان
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InfoRow(icon: Icons.storefront_outlined, text: o.restaurantName, bold: true),
              InfoRow(icon: Icons.location_on_outlined, text: o.deliveryAddress),
              if ((o.driverName ?? '').isNotEmpty)
                InfoRow(
                    icon: Icons.sports_motorsports_outlined,
                    text: tr('السائق: ${o.driverName}', 'Driver: ${o.driverName}')),
              if ((o.notes ?? '').trim().isNotEmpty)
                InfoRow(
                    icon: Icons.sticky_note_2_outlined,
                    text: tr('ملاحظاتك: ${o.notes}', 'Your notes: ${o.notes}')),
            ]),
          ),
        ),
      ]),
    );
  }
}
