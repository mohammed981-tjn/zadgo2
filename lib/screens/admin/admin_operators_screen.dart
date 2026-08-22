// lib/screens/admin/admin_operators_screen.dart
//
// إدارة مشغّلي الأسطول (دفعة «ابدأ المشغل»): المدير يُنشئ ملف المشغّل
// (بمعرّف حسابه المسجَّل بكود «مشغّل الأسطول»)، يضبط نسبته ورسمه الشهري،
// يسند الكباتن إليه، ويسجّل دفعات دفتره. **كل ما هنا للمدير وحده** —
// القواعد تحرس fleet_operators وحقل operatorId على الكابتن.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminOperatorsScreen extends StatelessWidget {
  const AdminOperatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.group_add_outlined),
        label: Text(tr('مشغّل جديد', 'New operator')),
      ),
      body: AppStreamBuilder<List<FleetOperator>>(
        stream: () => service.streamFleetOperators(),
        builder: (ctx, operators) {
          if (operators.isEmpty) {
            return AppEmpty(
                emoji: '🚚',
                title: tr('لا مشغّلين بعد', 'No operators yet'),
                subtitle: tr(
                    'ولّد كود «مشغّل الأسطول» من المستخدمين، ثم أنشئ ملفه هنا واسند إليه كباتنه.',
                    'Generate a "Fleet operator" code from the users screen, then create their profile here and assign their captains.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: operators.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _OperatorCard(op: operators[i]),
          );
        },
      ),
    );
  }
}

/// إنشاء ملف مشغّل: يُختار من حسابات دور «مشغّل الأسطول» التي لم يُنشأ لها
/// ملفٌ بعد. الملف بمعرّف حساب المشغّل نفسه (fleet_operators/{uid}).
void _showCreateSheet(BuildContext context) {
  final service = context.read<FirebaseService>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: AppStreamBuilder<List<AppUser>>(
        stream: () => service.streamUsers(),
        builder: (ctx, users) {
          final ops = users
              .where((u) => u.role == UserRole.fleetOperator)
              .toList();
          return _CreateOperatorForm(candidates: ops);
        },
      ),
    ),
  );
}

class _CreateOperatorForm extends StatefulWidget {
  final List<AppUser> candidates;
  const _CreateOperatorForm({required this.candidates});
  @override
  State<_CreateOperatorForm> createState() => _CreateOperatorFormState();
}

class _CreateOperatorFormState extends State<_CreateOperatorForm> {
  AppUser? _selected;
  final _shareCtrl = TextEditingController(text: '0');
  final _feeCtrl = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _shareCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(tr('ملف مشغّل جديد', 'New operator profile'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (widget.candidates.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
              tr('لا حساب بدور «مشغّل الأسطول» بعد. ولّد كوداً من شاشة المستخدمين أولاً.',
                  'No account with the "Fleet operator" role yet. Generate a code from the users screen first.'),
              style: const TextStyle(color: AppColors.textGray)),
        )
      else
        DropdownButtonFormField<AppUser>(
          value: _selected,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: tr('حساب المشغّل', 'Operator account')),
          items: widget.candidates
              .map((u) => DropdownMenuItem(
                  value: u,
                  child: Text(u.name.isEmpty ? u.email : u.name,
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _selected = v),
        ),
      const SizedBox(height: 8),
      TextField(
        controller: _shareCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
            labelText: tr('حصّة الكابتن من التوصيلة (ر.س)',
                'Captain share per delivery (SAR)'),
            helperText: tr('0 = المشغّل يأخذ الأجرة والكابتن يقبض من مؤسسته',
                '0 = the operator keeps the fee and the captain is paid by their company')),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _feeCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
            labelText: tr('رسم شهري على المشغّل (ر.س)',
                'Monthly fee for the operator (SAR)'),
            helperText: tr('0 عند الإطلاق (لا يُنصح بمطالبته قبل ثبوت دخله)',
                '0 at launch (charging before their income stabilizes is not advised)')),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _selected == null || _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  final u = _selected!;
                  try {
                    await context.read<FirebaseService>().saveFleetOperator(
                          FleetOperator(
                            id: u.uid,
                            name: u.name,
                            phone: u.phone,
                            driverSharePerDelivery:
                                double.tryParse(_shareCtrl.text.trim()) ?? 0,
                            monthlyFee:
                                double.tryParse(_feeCtrl.text.trim()) ?? 0,
                          ),
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                      showSuccess(context,
                          tr('أُنشئ ملف المشغّل', 'Operator profile created'));
                    }
                  } catch (_) {
                    if (context.mounted) {
                      setState(() => _saving = false);
                      showError(context, tr('تعذّر الحفظ', 'Could not save'));
                    }
                  }
                },
          child: Text(_saving ? '...' : tr('إنشاء', 'Create')),
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }
}

class _OperatorCard extends StatelessWidget {
  final FleetOperator op;
  const _OperatorCard({required this.op});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.groups_2_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(op.name.isEmpty ? tr('(بلا اسم)', '(no name)') : op.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            // «سُدّ الثغرة»: الرقم من مجموع دفتره (operator_transactions) لا
            // من حقلٍ مخزَّن — نفس الرقم الذي يراه المشغّل في تطبيقه حرفاً،
            // فلا خلاف تعاقدياً على رقمين.
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: context
                  .read<FirebaseService>()
                  .streamOperatorLedger(op.id),
              builder: (ctx, snap) {
                double cashNet = 0;
                for (final e in snap.data ?? const []) {
                  if (e['type'] != 'sharesPayout') {
                    cashNet += (e['amount'] as num?)?.toDouble() ?? 0;
                  }
                }
                if (cashNet == 0) return const SizedBox.shrink();
                return Text(
                    cashNet < 0
                        ? tr('عليه للمنصّة: ${(-cashNet).toStringAsFixed(0)}',
                            'Owes platform: ${(-cashNet).toStringAsFixed(0)}')
                        : tr('له على المنصّة: ${cashNet.toStringAsFixed(0)}',
                            'Platform owes: ${cashNet.toStringAsFixed(0)}'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cashNet < 0
                            ? AppColors.error
                            : AppColors.success));
              },
            ),
          ]),
          const SizedBox(height: 6),
          Text(
              tr(
                  'حصّة الكابتن: ${op.driverSharePerDelivery.toStringAsFixed(2)} ر.س'
                  '${op.monthlyFee > 0 ? ' · رسم شهري: ${op.monthlyFee.toStringAsFixed(0)}' : ''}',
                  'Captain share: SAR ${op.driverSharePerDelivery.toStringAsFixed(2)}'
                  '${op.monthlyFee > 0 ? ' · monthly fee: ${op.monthlyFee.toStringAsFixed(0)}' : ''}'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textDark)),
          const Divider(height: 18),
          Wrap(spacing: 8, runSpacing: 4, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.percent_rounded, size: 16),
              label: Text(tr('النسب', 'Rates')),
              onPressed: () => _editRates(context, op),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.delivery_dining_outlined, size: 16),
              label: Text(tr('كباتنه', 'Captains')),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _OperatorDriversScreen(op: op))),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: Text(tr('تسجيل دفعة', 'Record payment')),
              onPressed: () => _recordPayout(context, op),
            ),
            // تحصيل الرسم الشهري (دفعة ٢): يظهر فقط حين ضبط المدير رسماً — كان
            // `monthlyFee` يُضبط ولا يُحصَّل بأي مسار (ميّتاً وظيفياً).
            if (op.monthlyFee > 0)
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: Text(tr('تحصيل الرسم (${op.monthlyFee.toStringAsFixed(0)})',
                    'Charge fee (${op.monthlyFee.toStringAsFixed(0)})')),
                onPressed: () => _chargeMonthlyFee(context, op),
              ),
            // «سُدّ الثغرة»: تسوية حساب النقد — النقد الذي حصّله المشغّل
            // من كباتنه (عليه) أو دفعه من جيبه (له) يُصفّى هنا بقيدٍ لا
            // بتحرير رقم.
            OutlinedButton.icon(
              icon: const Icon(Icons.account_balance_outlined, size: 16),
              label: Text(tr('تسوية النقد', 'Settle cash')),
              onPressed: () => _settleCash(context, op),
            ),
          ]),
        ]),
      ),
    );
  }

  void _editRates(BuildContext context, FleetOperator op) {
    final shareCtrl = TextEditingController(
        text: op.driverSharePerDelivery.toStringAsFixed(2));
    final feeCtrl =
        TextEditingController(text: op.monthlyFee.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(tr('نِسَب المشغّل', 'Operator rates')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: shareCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: tr('حصّة الكابتن/توصيلة (ر.س)',
                      'Captain share per delivery (SAR)'))),
          const SizedBox(height: 8),
          TextField(
              controller: feeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: tr('رسم شهري (ر.س)', 'Monthly fee (SAR)'))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(tr('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () async {
              await context.read<FirebaseService>().setOperatorRates(op.id,
                  driverSharePerDelivery:
                      double.tryParse(shareCtrl.text.trim()) ?? 0,
                  monthlyFee: double.tryParse(feeCtrl.text.trim()) ?? 0);
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: Text(tr('حفظ', 'Save')),
          ),
        ],
      ),
    );
  }

  void _chargeMonthlyFee(BuildContext context, FleetOperator op) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(tr('تحصيل الرسم الشهري', 'Charge the monthly fee')),
        content: Text(
            tr(
                'تحصيل ${op.monthlyFee.toStringAsFixed(0)} ر.س رسماً شهرياً من '
                '${op.name.isEmpty ? "المشغّل" : op.name}؟ يُنقص من صافي دفتره '
                'ويُسجَّل في سجلّ العمليات.',
                'Charge SAR ${op.monthlyFee.toStringAsFixed(0)} as a monthly fee from '
                '${op.name.isEmpty ? "the operator" : op.name}? It is deducted from their ledger net '
                'and recorded in the activity log.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(tr('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () async {
              await context
                  .read<FirebaseService>()
                  .chargeOperatorMonthlyFee(op.id, op.monthlyFee);
              if (dCtx.mounted) {
                Navigator.pop(dCtx);
                showSuccess(context, tr('حُصِّل الرسم الشهري', 'Monthly fee charged'));
              }
            },
            child: Text(tr('تحصيل', 'Charge')),
          ),
        ],
      ),
    );
  }

  /// تسوية حساب النقد مع المشغّل — قيد adminSettlement على دفتره:
  /// «قبضتُ منه» يزيد صافيه نحو الصفر (كان عليه)، و«دفعتُ له» ينقصه
  /// نحو الصفر (كان له). القيد لا يُعدَّل ولا يُحذف — التصحيح بقيدٍ معاكس.
  void _settleCash(BuildContext context, FleetOperator op) {
    final amountCtrl = TextEditingController();
    var received = true; // true = قبضتُ منه، false = دفعتُ له
    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx2, setDialogState) => AlertDialog(
          title: Text(tr('تسوية النقد مع ${op.name.isEmpty ? "المشغّل" : op.name}',
              'Settle cash with ${op.name.isEmpty ? "the operator" : op.name}')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: true,
                    label: Text(tr('قبضتُ منه', 'Received from them'))),
                ButtonSegment(
                    value: false,
                    label: Text(tr('دفعتُ له', 'Paid to them'))),
              ],
              selected: {received},
              onSelectionChanged: (s) =>
                  setDialogState(() => received = s.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: tr('المبلغ (ر.س)', 'Amount (SAR)')),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: Text(tr('إلغاء', 'Cancel'))),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                await context.read<FirebaseService>().recordOperatorEntry(
                      operatorId: op.id,
                      type: 'adminSettlement',
                      amount: received ? amount : -amount,
                      note: received ? 'قبض نقدي من المشغّل' : 'دفع نقدي للمشغّل',
                    );
                if (dCtx.mounted) {
                  Navigator.pop(dCtx);
                  showSuccess(context, tr('قُيّدت التسوية', 'Settlement recorded'));
                }
              },
              child: Text(tr('قَيِّد', 'Record')),
            ),
          ],
        ),
      ),
    ).then((_) => amountCtrl.dispose());
  }

  void _recordPayout(BuildContext context, FleetOperator op) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(tr('تسجيل دفعة للمشغّل', 'Record a payment to the operator')),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: tr('المبلغ المدفوع (ر.س)', 'Amount paid (SAR)'),
              helperText: tr('يُنقص من رصيد دفتره', 'Deducted from their ledger balance')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(tr('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              await context
                  .read<FirebaseService>()
                  .recordOperatorPayout(op.id, amount);
              if (dCtx.mounted) {
                Navigator.pop(dCtx);
                showSuccess(context, tr('سُجّلت الدفعة', 'Payment recorded'));
              }
            },
            child: Text(tr('تسجيل', 'Record')),
          ),
        ],
      ),
    );
  }
}

/// إسناد الكباتن لمشغّل: قائمة كل الكباتن مع مفتاح تبعيّة لهذا المشغّل
/// وحقل حصّة. الإسناد يكتب operatorId + operatorDriverShare (محميّ للمدير).
class _OperatorDriversScreen extends StatelessWidget {
  final FleetOperator op;
  const _OperatorDriversScreen({required this.op});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Scaffold(
      appBar: AppBar(
          title: Text(tr('كباتن ${op.name}', '${op.name} captains'))),
      body: AppStreamBuilder<List<Driver>>(
        stream: () => service.streamDrivers(),
        builder: (ctx, drivers) {
          if (drivers.isEmpty) {
            return AppEmpty(emoji: '🛵', title: tr('لا كباتن', 'No captains'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: drivers.length,
            itemBuilder: (_, i) => _AssignTile(driver: drivers[i], op: op),
          );
        },
      ),
    );
  }
}

class _AssignTile extends StatelessWidget {
  final Driver driver;
  final FleetOperator op;
  const _AssignTile({required this.driver, required this.op});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final isMine = driver.operatorId == op.id;
    // كابتنٌ تابعٌ لمشغّلٍ آخر لا يُخطف: يُعرض معطَّلاً بإشارةٍ لتبعيّته.
    final otherOperator =
        driver.operatorId.isNotEmpty && driver.operatorId != op.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: SwitchListTile(
        value: isMine,
        onChanged: otherOperator
            ? null
            : (v) async {
                await service.assignDriverOperator(driver.id,
                    operatorId: v ? op.id : '',
                    operatorDriverShare:
                        v ? op.driverSharePerDelivery : 0);
              },
        title: Text(driver.name.isEmpty ? tr('(بلا اسم)', '(no name)') : driver.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(otherOperator
            ? tr('تابعٌ لمشغّلٍ آخر', 'Belongs to another operator')
            : tr(
                '${driver.totalDeliveries} توصيلة'
                    '${isMine && driver.operatorDriverShare > 0 ? ' · حصّته ${driver.operatorDriverShare.toStringAsFixed(2)}' : ''}',
                '${driver.totalDeliveries} deliveries'
                    '${isMine && driver.operatorDriverShare > 0 ? ' · share ${driver.operatorDriverShare.toStringAsFixed(2)}' : ''}')),
        secondary: Icon(
            isMine ? Icons.link_rounded : Icons.link_off_rounded,
            color: isMine ? AppColors.success : AppColors.textGray),
      ),
    );
  }
}
