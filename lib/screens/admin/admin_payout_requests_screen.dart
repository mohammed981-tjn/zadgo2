// lib/screens/admin/admin_payout_requests_screen.dart
//
// طلبات سحب مستحقّات السائقين — السائق يقدّم الطلب من محفظته («اسحب
// أموالي»)، والإدارة تبتّ هنا: صرفٌ يُقيَّد في دفتر حركاته تلقائياً
// (خصم رصيد + حركة payout في دفعة واحدة)، أو رفضٌ بسبب مكتوب يراه السائق
// في محفظته.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminPayoutRequestsScreen extends StatelessWidget {
  const AdminPayoutRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<PayoutRequest>>(
      stream: () => service.streamAllPayoutRequests(),
      builder: (ctx, all) {
        final pending = all
            .where((r) => r.status == PayoutRequestStatus.pending)
            .toList();
        final processed = all
            .where((r) => r.status != PayoutRequestStatus.pending)
            .toList();

        if (all.isEmpty) {
          return AppEmpty(
              emoji: '💸',
              title: tr('لا توجد طلبات سحب', 'No payout requests'),
              subtitle: tr('يقدّمها السائقون من زر «اسحب أموالي» في محفظتهم',
                  'Drivers submit them via the "Withdraw my money" button in their wallet'));
        }

        return ListView(padding: const EdgeInsets.all(12), children: [
          if (pending.isNotEmpty) ...[
            SectionHeader(
                title: tr('قيد المعالجة (${pending.length})',
                    'Pending (${pending.length})')),
            ...pending.map((r) => _RequestCard(request: r, pending: true)),
            const SizedBox(height: 12),
          ],
          if (processed.isNotEmpty) ...[
            SectionHeader(title: tr('السجلّ', 'History')),
            ...processed.map((r) => _RequestCard(request: r, pending: false)),
          ],
        ]);
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final PayoutRequest request;
  final bool pending;
  const _RequestCard({required this.request, required this.pending});

  String _fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final r = request;
    final service = context.read<FirebaseService>();
    final statusColor = switch (r.status) {
      PayoutRequestStatus.pending => AppColors.warning,
      PayoutRequestStatus.paid => AppColors.success,
      PayoutRequestStatus.rejected => AppColors.error,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(r.driverName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5)),
            ),
            Text(formatCurrency(r.amount),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: statusColor)),
          ]),
          const SizedBox(height: 6),
          InfoRow(icon: Icons.account_balance_outlined, text: r.method),
          InfoRow(
              icon: Icons.schedule_outlined,
              text: tr('قُدّم ${_fmt(r.createdAt)}',
                  'Submitted ${_fmt(r.createdAt)}')),
          if (!pending) ...[
            Row(children: [
              StatusChip(label: r.status.label, color: statusColor),
              if (r.processedAt != null) ...[
                const SizedBox(width: 8),
                Text(_fmt(r.processedAt!),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textGray)),
              ],
            ]),
            if ((r.adminNote ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tr('ملاحظة: ${r.adminNote}', 'Note: ${r.adminNote}'),
                    style: const TextStyle(fontSize: 12.5)),
              ),
          ],
          if (pending) ...[
            // رصيد السائق لحظياً — البتّ بمعلومة حاضرة لا بذاكرة المدير؛
            // والصرف نفسه يُعيد الفحص قبل الخصم فلا صرف فوق الرصيد.
            AppStreamBuilder<Driver?>(
              stream: () => service.streamDriver(r.driverId),
              loading: const SizedBox.shrink(),
              builder: (ctx, d) => d == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                              tr('رصيده الحالي: ${formatCurrency(d.balance)}',
                                  'Current balance: ${formatCurrency(d.balance)}'),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: d.balance >= r.amount
                                      ? AppColors.success
                                      : AppColors.error)),
                        ),
                        _BalanceAudit(driver: d),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error)),
                  onPressed: () => _reject(context, service),
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: Text(tr('رفض', 'Reject')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success),
                  onPressed: () => _pay(context, service),
                  icon: const Icon(Icons.done_all_rounded, size: 17),
                  label: Text(tr('صُرف — قيّده', 'Paid — record it')),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _pay(BuildContext context, FirebaseService service) async {
    final ok = await showConfirmDialog(
      context,
      title: tr('تأكيد الصرف', 'Confirm payout'),
      content: tr(
          'صرف ${formatCurrency(request.amount)} للسائق ${request.driverName} '
          '(${request.method})؟\n\nسيُخصم من رصيده وتُقيَّد حركة «صرف مستحقّات» '
          'في دفتره. اضغط بعد تنفيذ التحويل/التسليم فعلياً.',
          'Pay ${formatCurrency(request.amount)} to driver ${request.driverName} '
          '(${request.method})?\n\nIt will be deducted from their balance and a "payout" '
          'entry recorded in their ledger. Confirm only after the transfer/handover actually happened.'),
      confirmLabel: tr('صُرف فعلاً', 'Paid for real'),
    );
    if (ok != true || !context.mounted) return;
    try {
      await service.payPayoutRequest(request);
      if (context.mounted) {
        showSuccess(context, tr('قُيّد الصرف في دفتر السائق',
            'Payout recorded in the driver ledger'));
      }
    } catch (e) {
      if (context.mounted) {
        showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _reject(BuildContext context, FirebaseService service) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(tr('رفض طلب السحب', 'Reject payout request')),
        content: TextField(
          controller: noteCtrl,
          decoration: InputDecoration(
            labelText: tr('سبب الرفض (يظهر للسائق)',
                'Rejection reason (visible to the driver)'),
            hintText: tr('مثال: الرجاء مراجعة الإدارة لتسوية العُهدة أولاً',
                'Example: please contact management to settle the cash custody first'),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr('إلغاء', 'Cancel'))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(tr('رفض', 'Reject'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (noteCtrl.text.trim().isEmpty) {
      showError(context, tr('اكتب سبب الرفض — السائق يستحق جواباً',
          'Write a rejection reason — the driver deserves an answer'));
      return;
    }
    try {
      await service.rejectPayoutRequest(request.id, noteCtrl.text);
      if (context.mounted) {
        showSuccess(context, tr('رُفض الطلب وأُبلغ السائق بالسبب',
            'Request rejected and the driver was told why'));
      }
    } catch (e) {
      if (context.mounted) {
        showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }
}

/// مطابقة الرصيد المخزَّن بمجموع دفتر الحركات — عند لحظة الصرف تحديداً.
///
/// رصيد السائق يُكتب من جهازه (قيد العُهدة وأجرة التوصيل يُسجَّلان هناك،
/// ولا Cloud Functions تكتبهما نيابةً)، فقواعد الأمان تسمح له بتعديل
/// `balance` على مستنده. وهذا يعني نظرياً أن سائقاً بنسخة معدَّلة يرفع
/// رصيده ثم يطلب صرفه.
///
/// الحارس هنا **كشفٌ لا منع**: كل حركة في الدفتر تحمل رصيدها بعدها، فإن
/// خالف آخرُها الرصيدَ المخزَّن فثمّة تغيير لم يمرّ بالدفتر — يُعرض أحمر
/// قبل زر الصرف. المنع الحقيقي يحتاج منطقاً على الخادم (المسار د).
class _BalanceAudit extends StatelessWidget {
  final Driver driver;
  const _BalanceAudit({required this.driver});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<DriverTransaction>>(
      stream: () => service.streamDriverTransactions(driver.id),
      loading: const SizedBox.shrink(),
      builder: (ctx, txs) {
        // دفتر فارغ لا يُقارَن: سائق جديد بلا حركات رصيده صفر طبيعياً.
        if (txs.isEmpty) return const SizedBox.shrink();
        // السجلّ يصل مرتّباً من الأحدث؛ آخر رصيد مسجَّل هو المرجع.
        final expected = txs.first.balanceAfter;
        final gap = driver.balance - expected;
        if (gap.abs() < 0.01) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.gpp_maybe_outlined,
                color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  tr(
                      'الرصيد لا يطابق الدفتر: المخزَّن '
                      '${formatCurrency(driver.balance)} وآخر رصيد في الحركات '
                      '${formatCurrency(expected)} '
                      '(فرق ${formatCurrency(gap.abs())}). راجع الدفتر قبل الصرف.',
                      'Balance does not match the ledger: stored '
                      '${formatCurrency(driver.balance)} vs latest ledger balance '
                      '${formatCurrency(expected)} '
                      '(gap ${formatCurrency(gap.abs())}). Review the ledger before paying.'),
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        );
      },
    );
  }
}
