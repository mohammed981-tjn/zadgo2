// lib/screens/admin/admin_driver_ledger_screen.dart
//
// دفتر حساب سائق واحد في لوحة الإدارة: الرصيد الحالي بإشارته، وأزرار تسجيل
// الإيداع (استلام نقد من السائق) والصرف (دفع مستحقّاته)، وسجلّ كامل بالحركات.
//
// المرحلة الحالية (التجريب) لا تفرض أي تقييد على السائقين — هذه الشاشة أداة
// محاسبة يدوية تُظهر للإدارة مَن عليه مال ومَن له، مع أثر موثّق لكل عملية.
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'admin_incentives_screen.dart' show DriverReferralCodeChip;

/// تصدير دفتر سائق واحد إلى Excel — لتسليمه إياه عند التسوية أو لمراجعة
/// محاسبية خارج التطبيق. الأعمدة بأسماء سجلّ الحركات نفسها.
Future<void> exportDriverLedgerExcel({
  required Driver driver,
  required List<DriverTransaction> txs,
}) async {
  final workbook = xl.Excel.createExcel();
  final sheet = workbook['الدفتر'];
  workbook.setDefaultSheet('الدفتر');
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  sheet.appendRow([
    xl.TextCellValue('السائق'),
    xl.TextCellValue(driver.name),
    xl.TextCellValue('الرصيد الحالي'),
    xl.DoubleCellValue(driver.balance),
  ]);
  sheet.appendRow([xl.TextCellValue('')]);
  sheet.appendRow([
    xl.TextCellValue('التاريخ'),
    xl.TextCellValue('النوع'),
    xl.TextCellValue('المبلغ'),
    xl.TextCellValue('الرصيد بعدها'),
    xl.TextCellValue('رقم الطلب'),
    xl.TextCellValue('ملاحظة'),
  ]);
  for (final t in txs) {
    sheet.appendRow([
      xl.TextCellValue(dateFmt.format(t.createdAt)),
      xl.TextCellValue(t.type.label),
      xl.DoubleCellValue(t.amount),
      xl.DoubleCellValue(t.balanceAfter),
      xl.TextCellValue(t.orderNumber == null ? '' : '#${t.orderNumber}'),
      xl.TextCellValue(t.note ?? ''),
    ]);
  }

  final bytes = workbook.save();
  if (bytes == null) return;
  await Share.shareXFiles(
    [
      XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'دفتر_${driver.name}.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ],
    subject: 'دفتر حساب ${driver.name}',
  );
}

class AdminDriverLedgerScreen extends StatelessWidget {
  final Driver driver;
  const AdminDriverLedgerScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      appBar: AppBar(title: Text('حساب ${driver.name}')),
      // يُتابَع السائق لحظياً ليظهر الرصيد محدَّثاً فور تسجيل أي حركة.
      body: AppStreamBuilder<List<Driver>>(
        stream: service.streamDrivers,
        builder: (ctx, drivers) {
          final d = drivers.firstWhere(
            (x) => x.id == driver.id,
            orElse: () => driver,
          );
          final owes = d.balance < 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: owes
                        ? [AppColors.error, const Color(0xFFB71C1C)]
                        : [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(owes ? 'على السائق للتطبيق' : 'للسائق لدى التطبيق',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(formatCurrency(d.balance.abs()),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('${d.totalDeliveries} توصيلة • صُرف له '
                        '${formatCurrency(d.totalEarnings)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 8),
                    // كود إحالته — يسأل عنه السائق أحياناً عبر الهاتف.
                    DriverReferralCodeChip(driver: d),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.south_west_rounded, size: 18),
                    label: const Text('إيداع نقد'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                    onPressed: () => _showEntryDialog(
                      context,
                      title: 'تسجيل إيداع',
                      hint: 'المبلغ الذي سلّمه السائق نقداً',
                      onConfirm: (amount, note) => service.recordDriverDeposit(
                          driverId: d.id, amount: amount, note: note),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.north_east_rounded, size: 18),
                    label: const Text('صرف مستحقّات'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning),
                    onPressed: () => _showEntryDialog(
                      context,
                      title: 'تسجيل صرف',
                      hint: 'المبلغ المدفوع للسائق',
                      onConfirm: (amount, note) => service.recordDriverPayout(
                          driverId: d.id, amount: amount, note: note),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: const Text('منح مكافأة 🎉'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: () => _showEntryDialog(
                    context,
                    title: 'منح مكافأة',
                    hint: 'المبلغ — واذكر السبب في الملاحظة (تحدٍّ/إحالة/تميّز)',
                    onConfirm: (amount, note) => service.recordDriverBonus(
                        driverId: d.id, amount: amount, note: note),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('تسوية يدوية'),
                  onPressed: () => _showEntryDialog(
                    context,
                    title: 'تسوية يدوية',
                    hint: 'موجب يزيد الرصيد، سالب ينقصه',
                    allowNegative: true,
                    onConfirm: (amount, note) => service.recordDriverAdjustment(
                        driverId: d.id, amount: amount, note: note),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'سجلّ الحركات'),
              AppStreamBuilder<List<DriverTransaction>>(
                stream: () => service.streamDriverTransactions(d.id),
                builder: (ctx2, txs) {
                  if (txs.isEmpty) {
                    return const AppEmpty(emoji: '🧾', title: 'لا توجد حركات بعد');
                  }
                  return Column(children: [
                    // تصدير الدفتر لتسليمه للسائق عند التسوية — بنفس أعمدة
                    // السجلّ المعروض حرفياً.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () =>
                            exportDriverLedgerExcel(driver: d, txs: txs),
                        icon: const Icon(Icons.table_view_outlined, size: 16),
                        label: const Text('تصدير الدفتر Excel',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    ...txs.map((t) => _LedgerTile(tx: t)),
                  ]);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// نافذة إدخال مبلغ وملاحظة — مشتركة بين الإيداع والصرف والتسوية، مع تحقّق
  /// من صحة المبلغ قبل الكتابة لأن الخطأ هنا يمسّ حساباً مالياً.
  Future<void> _showEntryDialog(
    BuildContext context, {
    required String title,
    required String hint,
    required Future<void> Function(double amount, String? note) onConfirm,
    bool allowNegative = false,
  }) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: InputDecoration(labelText: 'المبلغ', hintText: hint),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount == 0 || (!allowNegative && amount < 0)) {
      showError(context, 'أدخل مبلغاً صحيحاً');
      return;
    }
    final note = noteCtrl.text.trim();
    try {
      await onConfirm(amount, note.isEmpty ? null : note);
      if (context.mounted) showSuccess(context, 'تم تسجيل الحركة');
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر تسجيل الحركة');
    }
  }
}

class _LedgerTile extends StatelessWidget {
  final DriverTransaction tx;
  const _LedgerTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount >= 0;
    final color = positive ? AppColors.success : AppColors.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(tx.type.icon, size: 16, color: color),
        ),
        title: Text(tx.type.label, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          [
            if (tx.orderNumber != null) 'طلب #${tx.orderNumber}',
            if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
            '${tx.createdAt.day}/${tx.createdAt.month} '
                '${tx.createdAt.hour}:${tx.createdAt.minute.toString().padLeft(2, '0')}',
          ].join(' • '),
          style: const TextStyle(fontSize: 11, color: AppColors.textGray),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${positive ? '+' : '−'}${formatCurrency(tx.amount.abs())}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            Text('الرصيد: ${formatCurrency(tx.balanceAfter)}',
                style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
          ],
        ),
      ),
    );
  }
}
