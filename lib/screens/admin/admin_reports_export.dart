// lib/screens/admin/admin_reports_export.dart
//
// تصدير تقارير الإدارة إلى PDF وExcel — بنفس نمط تصدير تقرير المطعم
// (خط Cairo العربي واتجاه RTL)، لكن بنطاق المنصّة كاملاً: الدورة المالية،
// العمولات، وتفصيل كل مطعم.
//
// وفاتورة مستحقّات مطعم واحد (PDF) — مستند رسمي يُسلَّم للمطعم عند التسوية.
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../utils/app_lang.dart';
import '../../utils/helpers.dart';

/// صف تجميعة مطعم في التقرير: (الاسم، عدد الطلبات، المبيعات، العمولة، الصافي).
typedef RestaurantRow = (String, int, double, double, double);

Future<pw.Font> _arabicFont() async =>
    pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Variable.ttf'));

/// إجماليات التقرير محسوبة من الطلبات نفسها — مصدر واحد يمنع اختلاف
/// أرقام الملف المُصدَّر عن أرقام الشاشة.
({
  double meals,
  double delivery,
  double commission,
  double fixedFee,
  double discounts,
  double revenue,
  double cash,
}) _totals(List<Order> orders) {
  double meals = 0, delivery = 0, commission = 0, fixedFee = 0;
  double discounts = 0, revenue = 0, cash = 0;
  for (final o in orders) {
    meals += o.itemsTotal;
    delivery += o.driverShare;
    commission += o.effectiveCommission;
    fixedFee += o.effectiveAppShare;
    discounts += o.discountAmount;
    revenue += o.payableTotal;
    if (o.paymentMethod == PaymentMethod.cash) {
      cash += o.payableTotal - o.walletUsed;
    }
  }
  return (
    meals: meals,
    delivery: delivery,
    commission: commission,
    fixedFee: fixedFee,
    discounts: discounts,
    revenue: revenue,
    cash: cash,
  );
}

// ---------------------------------------------------------------------------
// تقرير الإدارة العام
// ---------------------------------------------------------------------------

Future<void> exportAdminReportPdf({
  required String scopeLabel,
  required String periodLabel,
  required List<Order> orders,
  required List<RestaurantRow> restaurants,
}) async {
  final font = await _arabicFont();
  final t = _totals(orders);
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final doc = pw.Document();

  pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );

  doc.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(base: font, bold: font),
      textDirection: pw.TextDirection.rtl,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(tr('ZadGo — التقرير المالي', 'ZadGo — Financial report'),
                textDirection: pw.TextDirection.rtl,
                style: const pw.TextStyle(fontSize: 20)),
            pw.Text(
                tr('$scopeLabel • $periodLabel • ${orders.length} طلب مكتمل',
                    '$scopeLabel • $periodLabel • ${orders.length} completed orders'),
                textDirection: pw.TextDirection.rtl,
                style: const pw.TextStyle(fontSize: 11)),
            pw.Text(
                tr('صدر في ${dateFmt.format(DateTime.now())}',
                    'Issued ${dateFmt.format(DateTime.now())}'),
                textDirection: pw.TextDirection.rtl,
                style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.SizedBox(height: 8),
        pw.Text(tr('الدورة المالية', 'Money flow'),
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
        row(
            tr('دفعه العملاء (شامل التوصيل والرسوم)',
                'Paid by customers (incl. delivery & fees)'),
            formatCurrency(t.revenue),
            bold: true),
        row(tr('صافي مستحقّات المطاعم', 'Restaurants net due'),
            formatCurrency(t.meals - t.commission)),
        row(tr('أجرة السائقين', 'Driver fees'), formatCurrency(t.delivery)),
        row(
            tr('دخل المنصّة (عمولة + رسم ثابت)',
                'Platform income (commission + fixed fee)'),
            formatCurrency(t.commission + t.fixedFee)),
        if (t.discounts > 0) ...[
          row(
              tr('خصومات الكوبونات (تتحمّلها المنصّة)',
                  'Coupon discounts (borne by the platform)'),
              '- ${formatCurrency(t.discounts)}'),
          row(tr('صافي دخل المنصّة', 'Platform net income'),
              formatCurrency(t.commission + t.fixedFee - t.discounts),
              bold: true),
        ],
        pw.SizedBox(height: 6),
        row(tr('حصّله السائقون نقداً', 'Collected in cash by drivers'),
            formatCurrency(t.cash)),
        row(
            tr('قبضته المنصّة (بطاقات ومحافظ)',
                'Received by the platform (cards & wallets)'),
            formatCurrency(t.revenue - t.cash)),
        pw.SizedBox(height: 6),
        row(
            tr('ضريبة القيمة المضافة ضمن المبيعات (15%)',
                'VAT included in sales (15%)'),
            formatCurrency(Pricing.vatIncludedIn(t.meals))),
        pw.SizedBox(height: 16),
        pw.Text(tr('تفصيل المطاعم', 'Restaurant breakdown'),
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headerDirection: pw.TextDirection.rtl,
          tableDirection: pw.TextDirection.rtl,
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerStyle:
              pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          headers: [
            tr('الصافي', 'Net'),
            tr('العمولة', 'Commission'),
            tr('المبيعات', 'Sales'),
            tr('الطلبات', 'Orders'),
            tr('المطعم', 'Restaurant'),
          ],
          data: restaurants
              .map((r) => [
                    formatCurrency(r.$5),
                    formatCurrency(r.$4),
                    formatCurrency(r.$3),
                    '${r.$2}',
                    r.$1,
                  ])
              .toList(),
        ),
      ],
    ),
  );

  await Printing.sharePdf(
      bytes: await doc.save(),
      filename: tr('تقرير_ZadGo_$scopeLabel.pdf', 'ZadGo_report_$scopeLabel.pdf'));
}

Future<void> exportAdminReportExcel({
  required String scopeLabel,
  required List<Order> orders,
  required List<RestaurantRow> restaurants,
}) async {
  final t = _totals(orders);
  final workbook = xl.Excel.createExcel();
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  // ورقة الملخص
  final summaryName = tr('الملخص', 'Summary');
  final summary = workbook[summaryName];
  workbook.setDefaultSheet(summaryName);
  void put(String label, double value) => summary.appendRow(
      [xl.TextCellValue(label), xl.DoubleCellValue(value)]);
  summary.appendRow(
      [xl.TextCellValue(tr('النطاق', 'Scope')), xl.TextCellValue(scopeLabel)]);
  summary.appendRow([
    xl.TextCellValue(tr('عدد الطلبات المكتملة', 'Completed orders')),
    xl.IntCellValue(orders.length)
  ]);
  put(tr('دفعه العملاء', 'Paid by customers'), t.revenue);
  put(tr('مبيعات الوجبات', 'Food sales'), t.meals);
  put(tr('صافي مستحقّات المطاعم', 'Restaurants net due'),
      t.meals - t.commission);
  put(tr('أجرة السائقين', 'Driver fees'), t.delivery);
  put(tr('عمولة الوجبات', 'Food commission'), t.commission);
  put(tr('رسم التوصيل الثابت', 'Fixed delivery fee'), t.fixedFee);
  put(tr('خصومات الكوبونات', 'Coupon discounts'), t.discounts);
  put(tr('صافي دخل المنصّة', 'Platform net income'),
      t.commission + t.fixedFee - t.discounts);
  put(tr('حصّله السائقون نقداً', 'Collected in cash by drivers'), t.cash);
  put(tr('قبضته المنصّة', 'Received by the platform'), t.revenue - t.cash);
  put(tr('ضريبة القيمة المضافة ضمن المبيعات', 'VAT included in sales'),
      Pricing.vatIncludedIn(t.meals));

  // ورقة المطاعم
  final rSheet = workbook[tr('المطاعم', 'Restaurants')];
  rSheet.appendRow([
    xl.TextCellValue(tr('المطعم', 'Restaurant')),
    xl.TextCellValue(tr('الطلبات', 'Orders')),
    xl.TextCellValue(tr('المبيعات', 'Sales')),
    xl.TextCellValue(tr('العمولة', 'Commission')),
    xl.TextCellValue(tr('الصافي', 'Net')),
  ]);
  for (final r in restaurants) {
    rSheet.appendRow([
      xl.TextCellValue(r.$1),
      xl.IntCellValue(r.$2),
      xl.DoubleCellValue(r.$3),
      xl.DoubleCellValue(r.$4),
      xl.DoubleCellValue(r.$5),
    ]);
  }

  // ورقة الطلبات التفصيلية — أساس أي مراجعة محاسبية.
  final oSheet = workbook[tr('الطلبات', 'Orders')];
  oSheet.appendRow([
    xl.TextCellValue(tr('رقم الطلب', 'Order no.')),
    xl.TextCellValue(tr('التاريخ', 'Date')),
    xl.TextCellValue(tr('المطعم', 'Restaurant')),
    xl.TextCellValue(tr('الوجبات', 'Food')),
    xl.TextCellValue(tr('التوصيل', 'Delivery')),
    xl.TextCellValue(tr('الرسم الثابت', 'Fixed fee')),
    xl.TextCellValue(tr('العمولة', 'Commission')),
    xl.TextCellValue(tr('الخصم', 'Discount')),
    xl.TextCellValue(tr('المدفوع', 'Paid')),
    xl.TextCellValue(tr('طريقة الدفع', 'Payment method')),
  ]);
  for (final o in orders) {
    oSheet.appendRow([
      xl.TextCellValue('#${o.orderNumber}'),
      xl.TextCellValue(dateFmt.format(o.createdAt)),
      xl.TextCellValue(o.restaurantName),
      xl.DoubleCellValue(o.itemsTotal),
      xl.DoubleCellValue(o.driverShare),
      xl.DoubleCellValue(o.effectiveAppShare),
      xl.DoubleCellValue(o.effectiveCommission),
      xl.DoubleCellValue(o.discountAmount),
      xl.DoubleCellValue(o.payableTotal),
      xl.TextCellValue(o.paymentMethod.label),
    ]);
  }

  final bytes = workbook.save();
  if (bytes == null) return;
  await Share.shareXFiles(
    [
      XFile.fromData(
        Uint8List.fromList(bytes),
        name: tr('تقرير_ZadGo_$scopeLabel.xlsx', 'ZadGo_report_$scopeLabel.xlsx'),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ],
    subject: tr('التقرير المالي — $scopeLabel', 'Financial report — $scopeLabel'),
  );
}

// ---------------------------------------------------------------------------
// فاتورة مستحقّات مطعم — مستند التسوية الرسمي
// ---------------------------------------------------------------------------

Future<void> exportRestaurantInvoicePdf({
  required String restaurantName,
  required String periodLabel,
  required List<Order> orders,
}) async {
  final font = await _arabicFont();
  final dateFmt = DateFormat('yyyy-MM-dd');
  final meals = orders.fold(0.0, (s, o) => s + o.itemsTotal);
  final commission = orders.fold(0.0, (s, o) => s + o.effectiveCommission);
  final net = meals - commission;
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(base: font, bold: font),
      textDirection: pw.TextDirection.rtl,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(
                tr('فاتورة مستحقّات — $restaurantName',
                    'Statement of dues — $restaurantName'),
                textDirection: pw.TextDirection.rtl,
                style: const pw.TextStyle(fontSize: 20)),
            pw.Text(
                tr('$periodLabel • ${orders.length} طلب مكتمل',
                    '$periodLabel • ${orders.length} completed orders'),
                textDirection: pw.TextDirection.rtl,
                style: const pw.TextStyle(fontSize: 11)),
            pw.Text(
                tr('صدرت عن منصّة ZadGo في ${dateFmt.format(DateTime.now())}',
                    'Issued by the ZadGo platform on ${dateFmt.format(DateTime.now())}'),
                textDirection: pw.TextDirection.rtl,
                style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headerDirection: pw.TextDirection.rtl,
          tableDirection: pw.TextDirection.rtl,
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerStyle:
              pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          headers: [
            tr('الصافي', 'Net'),
            tr('العمولة', 'Commission'),
            tr('قيمة الوجبات', 'Food value'),
            tr('التاريخ', 'Date'),
            tr('رقم الطلب', 'Order no.'),
          ],
          data: orders
              .map((o) => [
                    formatCurrency(o.itemsTotal - o.effectiveCommission),
                    formatCurrency(o.effectiveCommission),
                    formatCurrency(o.itemsTotal),
                    dateFmt.format(o.createdAt),
                    '#${o.orderNumber}',
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
          child: pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(tr('إجمالي مبيعات الوجبات', 'Total food sales'),
                  textDirection: pw.TextDirection.rtl,
                  style: const pw.TextStyle(fontSize: 11)),
              pw.Text(formatCurrency(meals),
                  style: const pw.TextStyle(fontSize: 11)),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(tr('عمولة المنصّة (15%)', 'Platform commission (15%)'),
                  textDirection: pw.TextDirection.rtl,
                  style: const pw.TextStyle(fontSize: 11)),
              pw.Text('- ${formatCurrency(commission)}',
                  style: const pw.TextStyle(fontSize: 11)),
            ]),
            pw.Divider(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(tr('صافي المستحق للمطعم', 'Net due to the restaurant'),
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(formatCurrency(net),
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
            tr('الأسعار شاملة ضريبة القيمة المضافة (15%)، وقيمتها ضمن المبيعات: '
                    '${formatCurrency(Pricing.vatIncludedIn(meals))}. '
                    'أجرة التوصيل ورسومها لا تخصّ المطعم فلا تظهر في هذه الفاتورة.',
                'Prices include VAT (15%); its value within sales: '
                    '${formatCurrency(Pricing.vatIncludedIn(meals))}. '
                    'Delivery fees do not concern the restaurant, so they do not '
                    'appear on this statement.'),
            textDirection: pw.TextDirection.rtl,
            style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );

  await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          tr('فاتورة_$restaurantName.pdf', 'invoice_$restaurantName.pdf'));
}
