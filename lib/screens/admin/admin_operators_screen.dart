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
        label: const Text('مشغّل جديد'),
      ),
      body: AppStreamBuilder<List<FleetOperator>>(
        stream: () => service.streamFleetOperators(),
        builder: (ctx, operators) {
          if (operators.isEmpty) {
            return const AppEmpty(
                emoji: '🚚',
                title: 'لا مشغّلين بعد',
                subtitle:
                    'ولّد كود «مشغّل الأسطول» من المستخدمين، ثم أنشئ ملفه هنا واسند إليه كباتنه.');
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
      const Text('ملف مشغّل جديد',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (widget.candidates.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
              'لا حساب بدور «مشغّل الأسطول» بعد. ولّد كوداً من شاشة المستخدمين أولاً.',
              style: TextStyle(color: AppColors.textGray)),
        )
      else
        DropdownButtonFormField<AppUser>(
          value: _selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'حساب المشغّل'),
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
        decoration: const InputDecoration(
            labelText: 'حصّة الكابتن من التوصيلة (ر.س)',
            helperText: '0 = المشغّل يأخذ الأجرة والكابتن يقبض من مؤسسته'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _feeCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
            labelText: 'رسم شهري على المشغّل (ر.س)',
            helperText: '0 عند الإطلاق (لا يُنصح بمطالبته قبل ثبوت دخله)'),
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
                      showSuccess(context, 'أُنشئ ملف المشغّل');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      setState(() => _saving = false);
                      showError(context, 'تعذّر الحفظ');
                    }
                  }
                },
          child: Text(_saving ? '...' : 'إنشاء'),
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
              child: Text(op.name.isEmpty ? '(بلا اسم)' : op.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            if (op.balance != 0)
              Text(
                  op.balance > 0
                      ? 'مستحق: ${op.balance.toStringAsFixed(0)}'
                      : 'مدفوع: ${(-op.balance).toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textGray)),
          ]),
          const SizedBox(height: 6),
          Text(
              'حصّة الكابتن: ${op.driverSharePerDelivery.toStringAsFixed(2)} ر.س'
              '${op.monthlyFee > 0 ? ' · رسم شهري: ${op.monthlyFee.toStringAsFixed(0)}' : ''}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textDark)),
          const Divider(height: 18),
          Wrap(spacing: 8, runSpacing: 4, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.percent_rounded, size: 16),
              label: const Text('النسب'),
              onPressed: () => _editRates(context, op),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.delivery_dining_outlined, size: 16),
              label: const Text('كباتنه'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _OperatorDriversScreen(op: op))),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('تسجيل دفعة'),
              onPressed: () => _recordPayout(context, op),
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
        title: const Text('نِسَب المشغّل'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: shareCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'حصّة الكابتن/توصيلة (ر.س)')),
          const SizedBox(height: 8),
          TextField(
              controller: feeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'رسم شهري (ر.س)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              await context.read<FirebaseService>().setOperatorRates(op.id,
                  driverSharePerDelivery:
                      double.tryParse(shareCtrl.text.trim()) ?? 0,
                  monthlyFee: double.tryParse(feeCtrl.text.trim()) ?? 0);
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _recordPayout(BuildContext context, FleetOperator op) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('تسجيل دفعة للمشغّل'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'المبلغ المدفوع (ر.س)',
              helperText: 'يُنقص من رصيد دفتره'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              await context
                  .read<FirebaseService>()
                  .recordOperatorPayout(op.id, amount);
              if (dCtx.mounted) {
                Navigator.pop(dCtx);
                showSuccess(context, 'سُجّلت الدفعة');
              }
            },
            child: const Text('تسجيل'),
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
      appBar: AppBar(title: Text('كباتن ${op.name}')),
      body: AppStreamBuilder<List<Driver>>(
        stream: () => service.streamDrivers(),
        builder: (ctx, drivers) {
          if (drivers.isEmpty) {
            return const AppEmpty(emoji: '🛵', title: 'لا كباتن');
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
        title: Text(driver.name.isEmpty ? '(بلا اسم)' : driver.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(otherOperator
            ? 'تابعٌ لمشغّلٍ آخر'
            : '${driver.totalDeliveries} توصيلة'
                '${isMine && driver.operatorDriverShare > 0 ? ' · حصّته ${driver.operatorDriverShare.toStringAsFixed(2)}' : ''}'),
        secondary: Icon(
            isMine ? Icons.link_rounded : Icons.link_off_rounded,
            color: isMine ? AppColors.success : AppColors.textGray),
      ),
    );
  }
}
