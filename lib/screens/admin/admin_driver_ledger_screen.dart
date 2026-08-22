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
import '../../utils/app_lang.dart';
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
  final sheetName = tr('الدفتر', 'Ledger');
  final sheet = workbook[sheetName];
  workbook.setDefaultSheet(sheetName);
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  sheet.appendRow([
    xl.TextCellValue(tr('السائق', 'Driver')),
    xl.TextCellValue(driver.name),
    xl.TextCellValue(tr('الرصيد الحالي', 'Current balance')),
    xl.DoubleCellValue(driver.balance),
  ]);
  sheet.appendRow([xl.TextCellValue('')]);
  sheet.appendRow([
    xl.TextCellValue(tr('التاريخ', 'Date')),
    xl.TextCellValue(tr('النوع', 'Type')),
    xl.TextCellValue(tr('المبلغ', 'Amount')),
    xl.TextCellValue(tr('الرصيد بعدها', 'Balance after')),
    xl.TextCellValue(tr('رقم الطلب', 'Order no.')),
    xl.TextCellValue(tr('ملاحظة', 'Note')),
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
        name: tr('دفتر_${driver.name}.xlsx', 'ledger_${driver.name}.xlsx'),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ],
    subject: tr('دفتر حساب ${driver.name}', 'Account ledger for ${driver.name}'),
  );
}

class AdminDriverLedgerScreen extends StatelessWidget {
  final Driver driver;
  const AdminDriverLedgerScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      appBar: AppBar(
          title: Text(tr('حساب ${driver.name}', '${driver.name} account'))),
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
                    Text(owes
                            ? tr('على السائق للتطبيق', 'Driver owes the app')
                            : tr('للسائق لدى التطبيق', 'App owes the driver'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                    const SizedBox(height: 4),
                    Text(formatCurrency(d.balance.abs()),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(tr(
                            '${d.totalDeliveries} توصيلة • صُرف له '
                                '${formatCurrency(d.totalEarnings)}',
                            '${d.totalDeliveries} deliveries • paid out '
                                '${formatCurrency(d.totalEarnings)}'),
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
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
                    label: Text(tr('إيداع نقد', 'Cash deposit')),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                    onPressed: () => _showEntryDialog(
                      context,
                      title: tr('تسجيل إيداع', 'Record deposit'),
                      hint: tr('المبلغ الذي سلّمه السائق نقداً',
                          'Amount the driver handed over in cash'),
                      onConfirm: (amount, note) => service.recordDriverDeposit(
                          driverId: d.id, amount: amount, note: note),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.north_east_rounded, size: 18),
                    label: Text(tr('صرف مستحقّات', 'Pay out earnings')),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning),
                    onPressed: () => _showEntryDialog(
                      context,
                      title: tr('تسجيل صرف', 'Record payout'),
                      hint: tr('المبلغ المدفوع للسائق', 'Amount paid to the driver'),
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
                  label: Text(tr('منح مكافأة 🎉', 'Grant bonus 🎉')),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: () => _showEntryDialog(
                    context,
                    title: tr('منح مكافأة', 'Grant bonus'),
                    hint: tr('المبلغ — واذكر السبب في الملاحظة (تحدٍّ/إحالة/تميّز)',
                        'Amount — state the reason in the note (challenge/referral/excellence)'),
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
                  label: Text(tr('تسوية يدوية', 'Manual adjustment')),
                  onPressed: () => _showEntryDialog(
                    context,
                    title: tr('تسوية يدوية', 'Manual adjustment'),
                    hint: tr('موجب يزيد الرصيد، سالب ينقصه',
                        'Positive raises the balance, negative lowers it'),
                    allowNegative: true,
                    onConfirm: (amount, note) => service.recordDriverAdjustment(
                        driverId: d.id, amount: amount, note: note),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: tr('سجلّ الحركات', 'Transaction log')),
              AppStreamBuilder<List<DriverTransaction>>(
                stream: () => service.streamDriverTransactions(d.id),
                builder: (ctx2, txs) {
                  if (txs.isEmpty) {
                    return AppEmpty(
                        emoji: '🧾',
                        title: tr('لا توجد حركات بعد', 'No transactions yet'));
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
                        label: Text(tr('تصدير الدفتر Excel', 'Export ledger to Excel'),
                            style: const TextStyle(fontSize: 12.5)),
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
            decoration: InputDecoration(
                labelText: tr('المبلغ', 'Amount'), hintText: hint),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
                labelText: tr('ملاحظة (اختياري)', 'Note (optional)')),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء', 'Cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('تأكيد', 'Confirm'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount == 0 || (!allowNegative && amount < 0)) {
      showError(context, tr('أدخل مبلغاً صحيحاً', 'Enter a valid amount'));
      return;
    }
    final note = noteCtrl.text.trim();
    try {
      await onConfirm(amount, note.isEmpty ? null : note);
      if (context.mounted) {
        showSuccess(context, tr('تم تسجيل الحركة', 'Transaction recorded'));
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر تسجيل الحركة', 'Could not record the transaction'));
      }
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
        title: Text(tx.type.label, style: const TextStyle(fontSize: 13.5)),
        subtitle: Text(
          [
            if (tx.orderNumber != null)
              tr('طلب #${tx.orderNumber}', 'Order #${tx.orderNumber}'),
            if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
            '${tx.createdAt.day}/${tx.createdAt.month} '
                '${tx.createdAt.hour}:${tx.createdAt.minute.toString().padLeft(2, '0')}',
          ].join(' • '),
          style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${positive ? '+' : '−'}${formatCurrency(tx.amount.abs())}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13.5)),
            Text(tr('الرصيد: ${formatCurrency(tx.balanceAfter)}',
                    'Balance: ${formatCurrency(tx.balanceAfter)}'),
                style: const TextStyle(fontSize: 10.5, color: AppColors.textGray)),
          ],
        ),
      ),
    );
  }
}
