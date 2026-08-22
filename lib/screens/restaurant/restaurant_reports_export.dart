// lib/screens/restaurant/restaurant_reports_export.dart
//
// تصدير تقرير مبيعات المطعم (طلبات فرعه فقط) إلى ملفي Excel وPDF لمشاركتهما
// أو حفظهما — يقتصر التقرير على قيمة الوجبات المباعة دون سعر التوصيل، تماشياً
// مع نطاق اختصاص مدير المطعم في هذه المنصة.
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../utils/helpers.dart';
import '../../utils/app_lang.dart';

Future<void> exportRestaurantReportExcel({
  required String restaurantName,
  required List<Order> orders,
  required double totalMealsValue,
}) async {
  final workbook = xl.Excel.createExcel();
  // اسم الورقة محتوى مرئي في الملف المصدَّر — يُترجم كترويسات الأعمدة.
  final sheetName = tr('التقارير', 'Report');
  final sheet = workbook[sheetName];
  workbook.setDefaultSheet(sheetName);

  sheet.appendRow([
    xl.TextCellValue(tr('رقم الطلب', 'Order no.')),
    xl.TextCellValue(tr('الحالة', 'Status')),
    xl.TextCellValue(tr('قيمة الوجبات', 'Food value')),
    xl.TextCellValue(tr('التاريخ', 'Date')),
  ]);
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  for (final o in orders) {
    sheet.appendRow([
      xl.TextCellValue('#${o.orderNumber}'),
      xl.TextCellValue(o.status.label),
      xl.DoubleCellValue(o.itemsTotal),
      xl.TextCellValue(dateFmt.format(o.createdAt)),
    ]);
  }
  sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('')]);
  sheet.appendRow([
    xl.TextCellValue(tr('الإجمالي', 'Total')),
    xl.TextCellValue(''),
    xl.DoubleCellValue(totalMealsValue),
    xl.TextCellValue(''),
  ]);

  final bytes = workbook.save();
  if (bytes == null) return;
  await Share.shareXFiles(
    [
      XFile.fromData(
        Uint8List.fromList(bytes),
        name: tr('تقرير_$restaurantName.xlsx', 'report_$restaurantName.xlsx'),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ],
    subject: tr('تقرير مبيعات $restaurantName',
        'Sales report — $restaurantName'),
  );
}

Future<void> exportRestaurantReportPdf({
  required String restaurantName,
  required List<Order> orders,
  required double totalMealsValue,
}) async {
  final fontData = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
  final arabicFont = pw.Font.ttf(fontData);
  final doc = pw.Document();
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  doc.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
      textDirection: pw.TextDirection.rtl,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
              tr('تقرير مبيعات $restaurantName',
                  'Sales report — $restaurantName'),
              textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 20)),
        ),
        pw.Text(
            tr('إجمالي قيمة الوجبات المباعة: ${formatCurrency(totalMealsValue)}',
                'Total food sales: ${formatCurrency(totalMealsValue)}'),
            textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 14.5)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerDirection: pw.TextDirection.rtl,
          tableDirection: pw.TextDirection.rtl,
          headers: [
            tr('التاريخ', 'Date'),
            tr('قيمة الوجبات', 'Food value'),
            tr('الحالة', 'Status'),
            tr('رقم الطلب', 'Order no.'),
          ],
          data: orders
              .map((o) => [
                    dateFmt.format(o.createdAt),
                    formatCurrency(o.itemsTotal),
                    o.status.label,
                    '#${o.orderNumber}',
                  ])
              .toList(),
        ),
      ],
    ),
  );

  final bytes = await doc.save();
  await Printing.sharePdf(
      bytes: bytes,
      filename:
          tr('تقرير_$restaurantName.pdf', 'report_$restaurantName.pdf'));
}
