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
      appBar: AppBar(title: const Text('فاتورة الطلب')),
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
              Text('أُنشئ في ${_fmt(o.createdAt)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textGray)),
              if (o.status == OrderStatus.delivered && o.statusChangedAt != null)
                Text('سُلّم في ${_fmt(o.statusChangedAt!)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.success)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // الأصناف
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('الأصناف',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                          child: Text(i.name,
                              style: const TextStyle(fontSize: 14))),
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
              PriceRow(label: 'الوجبات', value: formatCurrency(o.itemsTotal)),
              PriceRow(label: 'التوصيل', value: formatCurrency(o.driverShare)),
              PriceRow(
                  label: 'رسوم توصيل ثابتة',
                  value: formatCurrency(o.appShare)),
              if (o.walletUsed > 0)
                PriceRow(
                    label: 'خصم من المحفظة',
                    value: '- ${formatCurrency(o.walletUsed)}'),
              const Divider(),
              PriceRow(
                  label: 'الإجمالي',
                  value: formatCurrency(o.grandTotal),
                  bold: true),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('شامل ضريبة القيمة المضافة (15٪)',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                    Text(formatCurrency(Pricing.vatIncludedIn(o.grandTotal)),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('طريقة الدفع',
                    style: TextStyle(fontSize: 12.5)),
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
                    const StatusChip(label: 'مدفوع', color: AppColors.success),
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
                    text: 'السائق: ${o.driverName}'),
              if ((o.notes ?? '').trim().isNotEmpty)
                InfoRow(icon: Icons.sticky_note_2_outlined, text: 'ملاحظاتك: ${o.notes}'),
            ]),
          ),
        ),
      ]),
    );
  }
}
