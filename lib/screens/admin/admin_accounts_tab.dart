import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

class AdminAccountsTab extends StatefulWidget {
  const AdminAccountsTab({super.key});

  @override
  State<AdminAccountsTab> createState() => _AdminAccountsTabState();
}

class _AdminAccountsTabState extends State<AdminAccountsTab> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _exportingPdf = false;
  bool _exportingExcel = false;

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Order>>(
      stream: service.streamAllOrders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const AppLoading();

        final deliveredOrders = snapshot.data!
            .where((order) => order.status == OrderStatus.delivered)
            .where(_matchesSelectedRange)
            .toList()
          ..sort((a, b) => _deliveryDateOf(b).compareTo(_deliveryDateOf(a)));
        final summary = _AccountsSummary.fromOrders(deliveredOrders);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'الحسابات والتقارير المالية'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _DateFilterChip(
                          label: 'من',
                          value: _startDate,
                          onTap: () => _pickDate(isStart: true),
                        ),
                        _DateFilterChip(
                          label: 'إلى',
                          value: _endDate,
                          onTap: () => _pickDate(isStart: false),
                        ),
                        if (_startDate != null || _endDate != null)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('مسح الفلترة'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 180,
                          child: ElevatedButton.icon(
                            onPressed: deliveredOrders.isEmpty || _exportingPdf
                                ? null
                                : () => _exportPdf(deliveredOrders, summary),
                            icon: _exportingPdf
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('تصدير PDF'),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: OutlinedButton.icon(
                            onPressed: deliveredOrders.isEmpty || _exportingExcel
                                ? null
                                : () => _exportExcel(deliveredOrders, summary),
                            icon: _exportingExcel
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.table_view_outlined),
                            label: const Text('تصدير Excel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _SummaryCard(
                  title: 'إجمالي المبيعات',
                  value: formatCurrency(summary.totalSales),
                  icon: Icons.payments_outlined,
                  color: AppColors.primary,
                ),
                _SummaryCard(
                  title: 'عمولة الطلبات 15%',
                  value: formatCurrency(summary.itemCommission),
                  icon: Icons.percent_outlined,
                  color: AppColors.success,
                ),
                _SummaryCard(
                  title: 'عمولة التوصيل الثابتة للتطبيق',
                  value: formatCurrency(summary.platformDeliveryFee),
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.warning,
                ),
                _SummaryCard(
                  title: 'مستحقات السائقين',
                  value: formatCurrency(summary.driverEarnings),
                  icon: Icons.delivery_dining_outlined,
                  color: AppColors.dark,
                ),
                _SummaryCard(
                  title: 'إجمالي الطلبات المُسلَّمة',
                  value: '${summary.deliveredCount}',
                  icon: Icons.done_all_outlined,
                  color: AppColors.primaryDark,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'الطلبات المُسلَّمة'),
            const SizedBox(height: 8),
            if (deliveredOrders.isEmpty)
              const AppEmpty(
                emoji: '📊',
                title: 'لا توجد طلبات مُسلَّمة ضمن النطاق المحدد',
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.primary.withOpacity(0.08),
                      ),
                      columns: const [
                        DataColumn(label: Text('رقم الطلب')),
                        DataColumn(label: Text('المطعم')),
                        DataColumn(label: Text('تاريخ التسليم')),
                        DataColumn(label: Text('قيمة الطلب')),
                        DataColumn(label: Text('عمولة الطلب')),
                        DataColumn(label: Text('أجرة التوصيل')),
                        DataColumn(label: Text('نصيب السائق')),
                        DataColumn(label: Text('عمولة التوصيل للتطبيق')),
                      ],
                      rows: deliveredOrders
                          .map(
                            (order) => DataRow(
                              cells: [
                                DataCell(Text('#${order.orderNumber}')),
                                DataCell(Text(order.restaurantName)),
                                DataCell(Text(_formatDate(_deliveryDateOf(order)))),
                                DataCell(Text(formatCurrency(order.itemsTotal))),
                                DataCell(
                                  Text(formatCurrency(order.calculatedCommission)),
                                ),
                                DataCell(Text(formatCurrency(order.deliveryFee))),
                                DataCell(
                                  Text(formatCurrency(_driverEarningOf(order))),
                                ),
                                DataCell(
                                  Text(
                                    formatCurrency(_platformDeliveryFeeOf(order)),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _matchesSelectedRange(Order order) {
    final deliveryDate = _deliveryDateOf(order);
    if (_startDate != null) {
      final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      if (deliveryDate.isBefore(start)) return false;
    }
    if (_endDate != null) {
      final end = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      );
      if (deliveryDate.isAfter(end)) return false;
    }
    return true;
  }

  DateTime _deliveryDateOf(Order order) => order.updatedAt ?? order.createdAt;

  String _formatDate(DateTime date) =>
      DateFormat('yyyy/MM/dd - hh:mm a').format(date);

  String _formatDay(DateTime date) => DateFormat('yyyy/MM/dd').format(date);

  double _driverEarningOf(Order order) =>
      order.driverEarning > 0 ? order.driverEarning : order.deliveryFee;

  double _platformDeliveryFeeOf(Order order) => order.platformDeliveryFee;

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate =
        (isStart ? _startDate : _endDate) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (pickedDate == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = pickedDate;
        if (_endDate != null && pickedDate.isAfter(_endDate!)) {
          _endDate = pickedDate;
        }
      } else {
        _endDate = pickedDate;
        if (_startDate != null && pickedDate.isBefore(_startDate!)) {
          _startDate = pickedDate;
        }
      }
    });
  }

  Future<void> _exportPdf(
    List<Order> orders,
    _AccountsSummary summary,
  ) async {
    setState(() => _exportingPdf = true);
    try {
      pw.Font? baseFont;
      try {
        baseFont = await PdfGoogleFonts.notoNaskhArabicRegular();
      } catch (_) {
        // Fallback keeps export working even if the font cannot be fetched.
        baseFont = null;
      }

      final theme = baseFont == null
          ? null
          : pw.ThemeData.withFont(base: baseFont, bold: baseFont);
      final pdf = theme == null ? pw.Document() : pw.Document(theme: theme);

      pdf.addPage(
        pw.MultiPage(
          textDirection: pw.TextDirection.rtl,
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
          ),
          build: (_) => [
            pw.Text(
              'تقرير الحسابات',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'الفترة: ${_buildDateRangeLabel()}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: const ['البيان', 'القيمة'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.amber700,
              ),
              data: [
                ['إجمالي المبيعات', _currencyValue(summary.totalSales)],
                ['عمولة الطلبات 15%', _currencyValue(summary.itemCommission)],
                [
                  'عمولة التوصيل الثابتة للتطبيق',
                  _currencyValue(summary.platformDeliveryFee),
                ],
                ['مستحقات السائقين', _currencyValue(summary.driverEarnings)],
                ['إجمالي الطلبات المُسلَّمة', '${summary.deliveredCount}'],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'تفاصيل الطلبات',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: const [
                'رقم الطلب',
                'المطعم',
                'تاريخ التسليم',
                'قيمة الطلب',
                'عمولة الطلب',
                'أجرة التوصيل',
                'نصيب السائق',
                'عمولة التوصيل',
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey700,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: orders
                  .map(
                    (order) => [
                      '#${order.orderNumber}',
                      order.restaurantName,
                      _formatDate(_deliveryDateOf(order)),
                      _currencyValue(order.itemsTotal),
                      _currencyValue(order.calculatedCommission),
                      _currencyValue(order.deliveryFee),
                      _currencyValue(_driverEarningOf(order)),
                      _currencyValue(_platformDeliveryFeeOf(order)),
                    ],
                  )
                  .toList(),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: _buildFileName(prefix: 'accounts_report', extension: 'pdf'),
      );
      if (mounted) showSuccess(context, 'تم تجهيز ملف PDF للمشاركة');
    } catch (error) {
      if (mounted) showError(context, 'تعذر تصدير PDF: $error');
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _exportExcel(
    List<Order> orders,
    _AccountsSummary summary,
  ) async {
    setState(() => _exportingExcel = true);
    try {
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != 'التقرير المالي') {
        excel.rename(defaultSheet, 'التقرير المالي');
      }
      final sheet = excel['التقرير المالي'];
      sheet.isRTL = true;

      sheet.appendRow([TextCellValue('تقرير الحسابات')]);
      sheet.appendRow([TextCellValue('الفترة'), TextCellValue(_buildDateRangeLabel())]);
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('البيان'), TextCellValue('القيمة')]);
      sheet.appendRow(
        [TextCellValue('إجمالي المبيعات'), DoubleCellValue(summary.totalSales)],
      );
      sheet.appendRow(
        [TextCellValue('عمولة الطلبات 15%'), DoubleCellValue(summary.itemCommission)],
      );
      sheet.appendRow([
        TextCellValue('عمولة التوصيل الثابتة للتطبيق'),
        DoubleCellValue(summary.platformDeliveryFee),
      ]);
      sheet.appendRow(
        [TextCellValue('مستحقات السائقين'), DoubleCellValue(summary.driverEarnings)],
      );
      sheet.appendRow(
        [TextCellValue('إجمالي الطلبات المُسلَّمة'), IntCellValue(summary.deliveredCount)],
      );
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('رقم الطلب'),
        TextCellValue('المطعم'),
        TextCellValue('تاريخ التسليم'),
        TextCellValue('قيمة الطلب'),
        TextCellValue('عمولة الطلب'),
        TextCellValue('أجرة التوصيل'),
        TextCellValue('نصيب السائق'),
        TextCellValue('عمولة التوصيل للتطبيق'),
      ]);

      for (final order in orders) {
        sheet.appendRow([
          TextCellValue('#${order.orderNumber}'),
          TextCellValue(order.restaurantName),
          TextCellValue(_formatDate(_deliveryDateOf(order))),
          DoubleCellValue(order.itemsTotal),
          DoubleCellValue(order.calculatedCommission),
          DoubleCellValue(order.deliveryFee),
          DoubleCellValue(_driverEarningOf(order)),
          DoubleCellValue(_platformDeliveryFeeOf(order)),
        ]);
      }

      for (var i = 0; i < 8; i++) {
        sheet.setColumnAutoFit(i);
      }

      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('لم يتم إنشاء ملف Excel');
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/${_buildFileName(prefix: 'accounts_report', extension: 'xlsx')}',
      );
      await file.create(recursive: true);
      await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);

      if (mounted) {
        showSuccess(context, 'تم حفظ ملف Excel في: ${file.path}');
      }
    } catch (error) {
      if (mounted) showError(context, 'تعذر تصدير Excel: $error');
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  String _buildDateRangeLabel() {
    final start = _startDate == null ? 'من البداية' : _formatDay(_startDate!);
    final end = _endDate == null ? 'حتى الآن' : _formatDay(_endDate!);
    return '$start — $end';
  }

  String _buildFileName({
    required String prefix,
    required String extension,
  }) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${prefix}_$stamp.$extension';
  }

  String _currencyValue(double value) => '${value.toStringAsFixed(2)} ر.س';
}

class _AccountsSummary {
  final double totalSales;
  final double itemCommission;
  final double platformDeliveryFee;
  final double driverEarnings;
  final int deliveredCount;

  const _AccountsSummary({
    required this.totalSales,
    required this.itemCommission,
    required this.platformDeliveryFee,
    required this.driverEarnings,
    required this.deliveredCount,
  });

  factory _AccountsSummary.fromOrders(List<Order> orders) => _AccountsSummary(
        totalSales: orders.fold(0.0, (sum, order) => sum + order.itemsTotal),
        itemCommission: orders.fold(
          0.0,
          (sum, order) => sum + order.calculatedCommission,
        ),
        platformDeliveryFee: orders.fold(
          0.0,
          (sum, order) => sum + _readPlatformDeliveryFee(order),
        ),
        driverEarnings: orders.fold(
          0.0,
          (sum, order) => sum + _readDriverEarning(order),
        ),
        deliveredCount: orders.length,
      );

  static double _readDriverEarning(Order order) =>
      order.driverEarning > 0 ? order.driverEarning : order.deliveryFee;

  static double _readPlatformDeliveryFee(Order order) => order.platformDeliveryFee;
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateFilterChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = value == null
        ? 'كل الفترات'
        : DateFormat('yyyy/MM/dd').format(value!);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.date_range_outlined),
      label: Text('$label: $dateLabel'),
    );
  }
}
