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

Future<void> exportRestaurantReportExcel({
  required String restaurantName,
  required List<Order> orders,
  required double totalMealsValue,
}) async {
  final workbook = xl.Excel.createExcel();
  final sheet = workbook['التقارير'];
  workbook.setDefaultSheet('التقارير');

  sheet.appendRow([
    xl.TextCellValue('رقم الطلب'),
    xl.TextCellValue('الحالة'),
    xl.TextCellValue('قيمة الوجبات'),
    xl.TextCellValue('التاريخ'),
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
    xl.TextCellValue('الإجمالي'),
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
        name: 'تقرير_$restaurantName.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ],
    subject: 'تقرير مبيعات $restaurantName',
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
          child: pw.Text('تقرير مبيعات $restaurantName',
              textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 20)),
        ),
        pw.Text('إجمالي قيمة الوجبات المباعة: ${formatCurrency(totalMealsValue)}',
            textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerDirection: pw.TextDirection.rtl,
          tableDirection: pw.TextDirection.rtl,
          headers: ['التاريخ', 'قيمة الوجبات', 'الحالة', 'رقم الطلب'],
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
  await Printing.sharePdf(bytes: bytes, filename: 'تقرير_$restaurantName.pdf');
}
