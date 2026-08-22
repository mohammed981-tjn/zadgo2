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
import '../../utils/app_lang.dart';
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
        label: Text(tr('كود جديد', 'New code')),
      ),
      body: AppStreamBuilder<List<Coupon>>(
        stream: () => service.streamCoupons(),
        builder: (ctx, coupons) {
          if (coupons.isEmpty) {
            return AppEmpty(
                emoji: '🎟️',
                title: tr('لا توجد أكواد خصم', 'No coupon codes'),
                subtitle: tr('أنشئ كوداً ترويجياً لجذب أول الطلبات',
                    'Create a promo code to attract the first orders'));
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
              Text(tr('أداء ${c.code}', '${c.code} performance'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17)),
              const Spacer(),
              Text(
                  tr('آخر ${snap.data!.length} طلب',
                      'Last ${snap.data!.length} orders'),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textGray)),
            ]),
            const SizedBox(height: 12),
            PriceRow(
                label: tr('طلبات مكتملة بالكود', 'Completed orders with the code'),
                value: '${delivered.length}'),
            PriceRow(
                label: tr('عملاء فريدون', 'Unique customers'),
                value: '$uniqueCustomers'),
            if (cancelled > 0)
              PriceRow(
                  label: tr('أُلغيت (أُرجع كودها)', 'Cancelled (code returned)'),
                  value: '$cancelled'),
            const Divider(height: 20),
            PriceRow(
                label: tr('كلفة الخصومات (تتحمّلها المنصّة)',
                    'Discount cost (borne by the platform)'),
                value: '- ${formatCurrency(cost)}'),
            PriceRow(
                label: tr('مبيعات جلبتها الطلبات المكتملة',
                    'Sales from completed orders'),
                value: formatCurrency(revenue), bold: true),
            const SizedBox(height: 8),
            Text(
              cost > 0
                  ? tr('كل ريال خصم جلب ${(revenue / cost).toStringAsFixed(1)} ريال مبيعات',
                      'Every riyal of discount brought ${(revenue / cost).toStringAsFixed(1)} riyals in sales')
                  : tr('لا خصومات مكتملة بعد', 'No completed discounts yet'),
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
        ? tr('موقوف', 'Paused')
        : c.isExpired
            ? tr('منتهٍ', 'Expired')
            : c.isExhausted
                ? tr('مستنفد', 'Exhausted')
                : tr('فعّال', 'Active');

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
              _meta(tr('حد أدنى', 'Minimum'),
                  tr('${c.minOrderTotal.toStringAsFixed(0)} ر.س',
                      '${c.minOrderTotal.toStringAsFixed(0)} SAR')),
            _meta(tr('الاستخدام', 'Usage'),
                c.usageLimit > 0 ? '${c.usedCount}/${c.usageLimit}' : '${c.usedCount}'),
            _meta(tr('لكل عميل', 'Per customer'),
                c.perUserLimit > 0 ? '${c.perUserLimit}' : tr('بلا حد', 'No limit')),
            if (c.expiresAt != null)
              _meta(tr('ينتهي', 'Expires'),
                  '${c.expiresAt!.year}/${c.expiresAt!.month}/${c.expiresAt!.day}'),
            if (c.restaurantId.isNotEmpty)
              _meta(tr('مقصور على', 'Limited to'),
                  tr('مطعم محدد', 'one restaurant')),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            TextButton.icon(
              onPressed: () => _showCouponForm(context, c),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(tr('تعديل', 'Edit'),
                  style: const TextStyle(fontSize: 12.5)),
            ),
            TextButton.icon(
              onPressed: () => service.setCouponActive(c.code, !c.isActive),
              icon: Icon(c.isActive ? Icons.pause : Icons.play_arrow, size: 16),
              label: Text(
                  c.isActive ? tr('إيقاف', 'Pause') : tr('تفعيل', 'Activate'),
                  style: const TextStyle(fontSize: 12.5)),
            ),
            TextButton.icon(
              onPressed: () => _showPerformanceSheet(context, c),
              icon: const Icon(Icons.insights_outlined, size: 16),
              label: Text(tr('أداء', 'Performance'),
                  style: const TextStyle(fontSize: 12.5)),
            ),
            const Spacer(),
            IconButton(
              tooltip: tr('حذف', 'Delete'),
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.error),
              onPressed: () async {
                // كود استُخدم فعلاً: الحذف يُفقد أثره عند مراجعة الحملة،
                // والإيقاف يمنع استخدامه ويُبقي سجلّه — فيُوجَّه إليه.
                final ok = await showConfirmDialog(context,
                    title: tr('حذف الكود', 'Delete code'),
                    content: c.usedCount > 0
                        ? tr(
                            'استُخدم ${c.code} ${c.usedCount} مرة. حذفه يُفقد '
                                'أثره عند مراجعة الحملة — «إيقاف» أفضل: يمنع '
                                'استخدامه ويُبقي سجلّه. الطلبات السابقة تحتفظ '
                                'بخصمها المسجَّل فيها.',
                            '${c.code} was used ${c.usedCount} times. Deleting '
                                'it loses its trail when reviewing the campaign '
                                '— "Pause" is better: it blocks use and keeps '
                                'the record. Past orders keep their recorded '
                                'discount.')
                        : tr(
                            'حذف ${c.code} نهائياً؟ الطلبات السابقة تحتفظ '
                                'بخصمها المسجَّل فيها.',
                            'Delete ${c.code} permanently? Past orders keep '
                                'their recorded discount.'),
                    confirmLabel: tr('حذف', 'Delete'),
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
      showError(context,
          tr('الكود من ٣ إلى ٢٤ خانة', 'The code is 3 to 24 characters'));
      return;
    }
    // حروف إنجليزية وأرقام فقط: الكود معرّف المستند، والعميل يكتبه بلوحة
    // مفاتيح قد تُدخل مسافة أو حرفاً عربياً فلا يطابق أبداً.
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
      showError(
          context,
          tr('الكود حروف إنجليزية وأرقام فقط بلا مسافات',
              'The code is English letters and digits only, no spaces'));
      return;
    }
    if (value <= 0) {
      showError(context,
          tr('أدخل قيمة خصم أكبر من صفر', 'Enter a discount value above zero'));
      return;
    }
    if (_type == CouponType.percentage && value > 100) {
      showError(
          context, tr('النسبة لا تتجاوز 100%', 'The rate cannot exceed 100%'));
      return;
    }
    // سقف الخصم صار **إلزامياً** لكوبون النسبة (تحصين 2026-08-15): القواعد
    // ترفض خصم نسبةٍ بلا سقف لحظة إنشاء الطلب — فكوبون يُحفظ بلا سقف يعمل
    // في الواجهة ثم يفشل عند الدفع. يُمنع من المنبع برسالة تشرح السبب.
    if (_type == CouponType.percentage &&
        (double.tryParse(_maxDiscount.text.trim()) ?? 0) <= 0) {
      showError(
          context,
          tr('كوبون النسبة يحتاج «سقف الخصم» — بلا سقف يمكن أن يبتلع خصمُ طلبٍ '
                  'كبير دخلَ يومٍ كامل، والنظام يرفضه عند الدفع',
              'A percentage coupon needs a "discount cap" — without one, the '
                  "discount on a large order can swallow a full day's income, "
                  'and the system rejects it at checkout'));
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
          showError(
              context,
              tr('الكود $code موجود مسبقاً — عدّله من قائمة الأكواد',
                  'Code $code already exists — edit it from the code list'));
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
        showSuccess(context, tr('حُفظ الكود $code', 'Code $code saved'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, tr('تعذّر حفظ الكود', 'Could not save the code'));
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
            Text(
                widget.existing == null
                    ? tr('كود خصم جديد', 'New coupon code')
                    : tr('تعديل الكود', 'Edit code'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              enabled: widget.existing == null,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                  labelText: tr('الكود', 'Code'), hintText: 'ZADGO20'),
            ),
            const SizedBox(height: 10),
            SegmentedButton<CouponType>(
              segments: [
                ButtonSegment(
                    value: CouponType.percentage,
                    label: Text(tr('نسبة %', 'Rate %')),
                    icon: const Icon(Icons.percent, size: 16)),
                ButtonSegment(
                    value: CouponType.fixed,
                    label: Text(tr('مبلغ ثابت', 'Fixed amount')),
                    icon: const Icon(Icons.payments_outlined, size: 16)),
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
                      ? tr('نسبة الخصم (%)', 'Discount rate (%)')
                      : tr('مبلغ الخصم (ر.س)', 'Discount amount (SAR)')),
            ),
            if (_type == CouponType.percentage)
              TextField(
                controller: _maxDiscount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: tr('سقف الخصم (ر.س) — إلزامي لكوبون النسبة',
                        'Discount cap (SAR) — required for rate coupons'),
                    hintText: tr('يمنع خصماً ضخماً على طلب كبير',
                        'Prevents a huge discount on a large order')),
              ),
            TextField(
              controller: _minOrder,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: tr('حد أدنى لقيمة الوجبات (ر.س) — اختياري',
                      'Minimum food total (SAR) — optional')),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _usageLimit,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: tr('حد الاستخدام الكلي', 'Total usage limit'),
                      hintText: tr('بلا حد', 'No limit')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _perUser,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: tr('لكل عميل', 'Per customer')),
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
                decoration: InputDecoration(
                    labelText: tr('مقصور على مطعم (اختياري)',
                        'Limited to a restaurant (optional)')),
                items: [
                  DropdownMenuItem(
                      value: '', child: Text(tr('كل المطاعم', 'All restaurants'))),
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
                  ? tr('بلا تاريخ انتهاء', 'No expiry date')
                  : tr('ينتهي في ${_expiresAt!.year}/${_expiresAt!.month}/${_expiresAt!.day}',
                      'Expires on ${_expiresAt!.year}/${_expiresAt!.month}/${_expiresAt!.day}')),
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
                  child: Text(tr('اختيار', 'Pick')),
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
              child: Text(
                tr('الخصم تتحمّله المنصّة من حصّتها — مستحق المطعم وأجرة السائق '
                        'لا تتأثران.',
                    "The discount comes out of the platform's share — the "
                        "restaurant's due and the driver's fee are untouched."),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving
                    ? tr('جارٍ الحفظ…', 'Saving…')
                    : tr('حفظ الكود', 'Save code')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
