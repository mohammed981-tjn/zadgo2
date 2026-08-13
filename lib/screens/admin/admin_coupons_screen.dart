// lib/screens/admin/admin_coupons_screen.dart
//
// أكواد الخصم — أداة التسويق الأساسية للإطلاق. الخصم تموّله المنصّة من
// حصّتها: لا يُنقص مستحق المطعم ولا أجرة السائق، فلا يحتاج تفاوضاً مع أحد.
//
// كل كود: نسبة أو مبلغ ثابت، حد أدنى للطلب، سقف للخصم، حد استخدام كلي
// وحد لكل عميل، صلاحية، وقصره على مطعم بعينه إن أُريد.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminCouponsScreen extends StatelessWidget {
  const AdminCouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCouponForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('كود جديد'),
      ),
      body: AppStreamBuilder<List<Coupon>>(
        stream: () => service.streamCoupons(),
        builder: (ctx, coupons) {
          if (coupons.isEmpty) {
            return const AppEmpty(
                emoji: '🎟️',
                title: 'لا توجد أكواد خصم',
                subtitle: 'أنشئ كوداً ترويجياً لجذب أول الطلبات');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: coupons.map((c) => _CouponCard(coupon: c)).toList(),
          );
        },
      ),
    );
  }
}

/// تقرير أداء كوبون واحد (نفذ ٣): كان المتاح رقماً مخلوطاً واحداً
/// (usedCount) لا يجيب سؤال الحملة الحقيقي — «كم كلّفني الكود وكم جلب؟».
/// يُحسب من الطلبات نفسها (couponCode/discountAmount) لا من العدّاد،
/// فالملغى يُستبعد ويظهر أثره صريحاً.
Future<void> _showPerformanceSheet(BuildContext context, Coupon c) async {
  final service = context.read<FirebaseService>();
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => Padding(
      padding: const EdgeInsets.all(20),
      child: FutureBuilder<List<Order>>(
        future: service.streamAllOrders().first,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const SizedBox(height: 160, child: AppLoading());
          }
          final all = snap.data!
              .where((o) => o.couponCode == c.code && o.discountAmount > 0)
              .toList();
          final delivered =
              all.where((o) => o.status == OrderStatus.delivered).toList();
          final cancelled = all.length - delivered.length -
              all.where((o) => o.status.isActive).length;
          final cost = delivered.fold(0.0, (s, o) => s + o.discountAmount);
          final revenue = delivered.fold(0.0, (s, o) => s + o.itemsTotal);
          final uniqueCustomers = all.map((o) => o.customerId).toSet().length;
          return Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('أداء ${c.code}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17)),
              const Spacer(),
              Text('آخر ${snap.data!.length} طلب',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textGray)),
            ]),
            const SizedBox(height: 12),
            PriceRow(label: 'طلبات مكتملة بالكود', value: '${delivered.length}'),
            PriceRow(label: 'عملاء فريدون', value: '$uniqueCustomers'),
            if (cancelled > 0)
              PriceRow(label: 'أُلغيت (أُرجع كودها)', value: '$cancelled'),
            const Divider(height: 20),
            PriceRow(
                label: 'كلفة الخصومات (تتحمّلها المنصّة)',
                value: '- ${formatCurrency(cost)}'),
            PriceRow(
                label: 'مبيعات جلبتها الطلبات المكتملة',
                value: formatCurrency(revenue), bold: true),
            const SizedBox(height: 8),
            Text(
              cost > 0
                  ? 'كل ريال خصم جلب ${(revenue / cost).toStringAsFixed(1)} ريال مبيعات'
                  : 'لا خصومات مكتملة بعد',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
            ),
          ]);
        },
      ),
    ),
  );
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final c = coupon;
    final service = context.read<FirebaseService>();
    final dead = !c.isActive || c.isExpired || c.isExhausted;
    final statusLabel = !c.isActive
        ? 'موقوف'
        : c.isExpired
            ? 'منتهٍ'
            : c.isExhausted
                ? 'مستنفد'
                : 'فعّال';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (dead ? AppColors.textGray : AppColors.primary)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(c.code,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: dead ? AppColors.textGray : AppColors.primary)),
            ),
            const SizedBox(width: 8),
            Text(c.label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14.5)),
            const Spacer(),
            StatusChip(
                label: statusLabel,
                color: dead ? AppColors.textGray : AppColors.success),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 2, children: [
            if (c.minOrderTotal > 0)
              _meta('حد أدنى', '${c.minOrderTotal.toStringAsFixed(0)} ر.س'),
            _meta('الاستخدام',
                c.usageLimit > 0 ? '${c.usedCount}/${c.usageLimit}' : '${c.usedCount}'),
            _meta('لكل عميل', c.perUserLimit > 0 ? '${c.perUserLimit}' : 'بلا حد'),
            if (c.expiresAt != null)
              _meta('ينتهي',
                  '${c.expiresAt!.year}/${c.expiresAt!.month}/${c.expiresAt!.day}'),
            if (c.restaurantId.isNotEmpty) _meta('مقصور على', 'مطعم محدد'),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            TextButton.icon(
              onPressed: () => _showCouponForm(context, c),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('تعديل', style: TextStyle(fontSize: 12.5)),
            ),
            TextButton.icon(
              onPressed: () => service.setCouponActive(c.code, !c.isActive),
              icon: Icon(c.isActive ? Icons.pause : Icons.play_arrow, size: 16),
              label: Text(c.isActive ? 'إيقاف' : 'تفعيل',
                  style: const TextStyle(fontSize: 12.5)),
            ),
            TextButton.icon(
              onPressed: () => _showPerformanceSheet(context, c),
              icon: const Icon(Icons.insights_outlined, size: 16),
              label: const Text('أداء', style: TextStyle(fontSize: 12.5)),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.error),
              onPressed: () async {
                // كود استُخدم فعلاً: الحذف يُفقد أثره عند مراجعة الحملة،
                // والإيقاف يمنع استخدامه ويُبقي سجلّه — فيُوجَّه إليه.
                final ok = await showConfirmDialog(context,
                    title: 'حذف الكود',
                    content: c.usedCount > 0
                        ? 'استُخدم ${c.code} ${c.usedCount} مرة. حذفه يُفقد '
                            'أثره عند مراجعة الحملة — «إيقاف» أفضل: يمنع '
                            'استخدامه ويُبقي سجلّه. الطلبات السابقة تحتفظ '
                            'بخصمها المسجَّل فيها.'
                        : 'حذف ${c.code} نهائياً؟ الطلبات السابقة تحتفظ '
                            'بخصمها المسجَّل فيها.',
                    confirmLabel: 'حذف',
                    confirmColor: AppColors.error);
                if (ok == true) await service.deleteCoupon(c.code);
              },
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _meta(String label, String value) => Text('$label: $value',
      style: const TextStyle(fontSize: 12.5, color: AppColors.textGray));
}

void _showCouponForm(BuildContext context, Coupon? existing) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => _CouponForm(existing: existing),
  );
}

class _CouponForm extends StatefulWidget {
  final Coupon? existing;
  const _CouponForm({this.existing});

  @override
  State<_CouponForm> createState() => _CouponFormState();
}

class _CouponFormState extends State<_CouponForm> {
  late final TextEditingController _code, _value, _minOrder, _maxDiscount,
      _usageLimit, _perUser;
  late CouponType _type;
  DateTime? _expiresAt;
  String _restaurantId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _code = TextEditingController(text: c?.code ?? '');
    _value = TextEditingController(text: c?.value.toStringAsFixed(0) ?? '');
    _minOrder =
        TextEditingController(text: (c?.minOrderTotal ?? 0) == 0 ? '' : c!.minOrderTotal.toStringAsFixed(0));
    _maxDiscount =
        TextEditingController(text: (c?.maxDiscount ?? 0) == 0 ? '' : c!.maxDiscount.toStringAsFixed(0));
    _usageLimit =
        TextEditingController(text: (c?.usageLimit ?? 0) == 0 ? '' : '${c!.usageLimit}');
    _perUser = TextEditingController(text: '${c?.perUserLimit ?? 1}');
    _type = c?.type ?? CouponType.percentage;
    _expiresAt = c?.expiresAt;
    _restaurantId = c?.restaurantId ?? '';
  }

  @override
  void dispose() {
    for (final c in [_code, _value, _minOrder, _maxDiscount, _usageLimit, _perUser]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase();
    final value = double.tryParse(_value.text.trim()) ?? 0;
    if (code.length < 3 || code.length > 24) {
      showError(context, 'الكود من ٣ إلى ٢٤ خانة');
      return;
    }
    // حروف إنجليزية وأرقام فقط: الكود معرّف المستند، والعميل يكتبه بلوحة
    // مفاتيح قد تُدخل مسافة أو حرفاً عربياً فلا يطابق أبداً.
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
      showError(context, 'الكود حروف إنجليزية وأرقام فقط بلا مسافات');
      return;
    }
    if (value <= 0) {
      showError(context, 'أدخل قيمة خصم أكبر من صفر');
      return;
    }
    if (_type == CouponType.percentage && value > 100) {
      showError(context, 'النسبة لا تتجاوز 100%');
      return;
    }
    setState(() => _saving = true);
    // الكود معرّف المستند والحفظ بالدمج، فكود جديد باسم كودٍ قائم كان
    // يندمج فيه صامتاً: يستبدل قيمته ويرث عدّاد استخداماته — بلا أي تنبيه.
    if (widget.existing == null) {
      try {
        if (await context.read<FirebaseService>().couponExists(code)) {
          if (!mounted) return;
          setState(() => _saving = false);
          showError(context, 'الكود $code موجود مسبقاً — عدّله من قائمة الأكواد');
          return;
        }
      } catch (_) {
        // تعذّر الفحص (شبكة) — لا يُمنع الحفظ بسببه.
      }
      if (!mounted) return;
    }
    try {
      await context.read<FirebaseService>().saveCoupon(Coupon(
            code: code,
            type: _type,
            value: value,
            minOrderTotal: double.tryParse(_minOrder.text.trim()) ?? 0,
            maxDiscount: double.tryParse(_maxDiscount.text.trim()) ?? 0,
            usageLimit: int.tryParse(_usageLimit.text.trim()) ?? 0,
            perUserLimit: int.tryParse(_perUser.text.trim()) ?? 1,
            restaurantId: _restaurantId,
            expiresAt: _expiresAt,
            isActive: widget.existing?.isActive ?? true,
            createdAt: widget.existing?.createdAt ?? DateTime.now(),
          ));
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'حُفظ الكود $code');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, 'تعذّر حفظ الكود');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'كود خصم جديد' : 'تعديل الكود',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              enabled: widget.existing == null,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'الكود', hintText: 'ZADGO20'),
            ),
            const SizedBox(height: 10),
            SegmentedButton<CouponType>(
              segments: const [
                ButtonSegment(
                    value: CouponType.percentage,
                    label: Text('نسبة %'),
                    icon: Icon(Icons.percent, size: 16)),
                ButtonSegment(
                    value: CouponType.fixed,
                    label: Text('مبلغ ثابت'),
                    icon: Icon(Icons.payments_outlined, size: 16)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: _type == CouponType.percentage
                      ? 'نسبة الخصم (%)'
                      : 'مبلغ الخصم (ر.س)'),
            ),
            if (_type == CouponType.percentage)
              TextField(
                controller: _maxDiscount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'سقف الخصم (ر.س) — اختياري',
                    hintText: 'يمنع خصماً ضخماً على طلب كبير'),
              ),
            TextField(
              controller: _minOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'حد أدنى لقيمة الوجبات (ر.س) — اختياري'),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _usageLimit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'حد الاستخدام الكلي', hintText: 'بلا حد'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _perUser,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'لكل عميل'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            // القصر على مطعم — اختياري، والافتراضي كل المطاعم.
            AppStreamBuilder<List<Restaurant>>(
              stream: () => service.streamRestaurants(),
              loading: const SizedBox.shrink(),
              builder: (ctx, restaurants) => DropdownButtonFormField<String>(
                value: _restaurantId.isEmpty ? null : _restaurantId,
                decoration:
                    const InputDecoration(labelText: 'مقصور على مطعم (اختياري)'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('كل المطاعم')),
                  ...restaurants.map((r) =>
                      DropdownMenuItem(value: r.id, child: Text(r.name))),
                ],
                onChanged: (v) => setState(() => _restaurantId = v ?? ''),
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(_expiresAt == null
                  ? 'بلا تاريخ انتهاء'
                  : 'ينتهي في ${_expiresAt!.year}/${_expiresAt!.month}/${_expiresAt!.day}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_expiresAt != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _expiresAt = null),
                  ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 730)),
                    );
                    // نهاية اليوم لا بدايته: مُنتقي التاريخ يعيد منتصف
                    // الليل، فكوبون «ينتهي ١٥/٨» كان ميتاً طوال يوم ١٥
                    // كاملاً. المالك يقصد «صالح إلى آخر ذلك اليوم».
                    if (picked != null) {
                      setState(() => _expiresAt = DateTime(
                          picked.year, picked.month, picked.day, 23, 59, 59));
                    }
                  },
                  child: const Text('اختيار'),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'الخصم تتحمّله المنصّة من حصّتها — مستحق المطعم وأجرة السائق '
                'لا تتأثران.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ الكود'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
