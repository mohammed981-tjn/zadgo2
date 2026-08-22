// lib/screens/admin/admin_orders_archive_screen.dart
//
// «سجلّ الطلبات» — أرشيف الإدارة الكامل للطلبات بكل حالاتها.
//
// لماذا شاشة مستقلة عن «المتابعة الحية» و«التقارير المالية»؟ (ملاحظة المالك
// ٢٠٢٦-٠٨-١١ بعد إلغاء طلب اختباري ثم البحث عنه فلم يجده):
//   • المتابعة الحية تعرض النشط فقط — الطلب لحظة إلغائه يختفي من الشاشة.
//   • التقارير المالية تحسب المكتمل وحده عمداً (الملغى لم يتحقق إيراداً).
// فبقي الملغى والمرفوض و«تعذّر إيجاد سائق» بلا أي مكان يُرى فيه — بينما
// العميل والسائق لكلٍّ منهما سجلّ طلباته الكامل. هذه الشاشة تسدّ الفجوة:
// كل الطلبات، ببحث نصّي حرّ وفلاتر حالة وفترة، ومدخل للفاتورة التفصيلية.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../customer/order_receipt_screen.dart';
import '../customer/order_chat_screen.dart';
import '../customer/order_map_screen.dart';

/// مجموعات الحالة كما يفكّر بها المدير لا كما تُخزَّن: «ملغاة» تجمع الإلغاء
/// والاسترداد، و«متعثّرة» تجمع رفض المطعم وتعذّر إيجاد سائق — فهي عند
/// المراجعة سؤال واحد: أي طلب لم يصل العميل ولماذا؟
enum _StatusGroup { all, active, delivered, cancelled, failed }

extension _StatusGroupExt on _StatusGroup {
  String get label => switch (this) {
        _StatusGroup.all => tr('الكل', 'All'),
        _StatusGroup.active => tr('جارية', 'Active'),
        _StatusGroup.delivered => tr('مكتملة', 'Delivered'),
        _StatusGroup.cancelled => tr('ملغاة', 'Cancelled'),
        _StatusGroup.failed => tr('متعثّرة', 'Failed'),
      };

  bool matches(OrderStatus s) => switch (this) {
        _StatusGroup.all => true,
        _StatusGroup.active => s.isActive,
        _StatusGroup.delivered => s == OrderStatus.delivered,
        _StatusGroup.cancelled =>
          s == OrderStatus.cancelled || s == OrderStatus.refunded,
        _StatusGroup.failed => s == OrderStatus.restaurantRejected ||
            s == OrderStatus.noDriverFound,
      };
}

class AdminOrdersArchiveScreen extends StatefulWidget {
  const AdminOrdersArchiveScreen({super.key});

  @override
  State<AdminOrdersArchiveScreen> createState() =>
      _AdminOrdersArchiveScreenState();
}

class _AdminOrdersArchiveScreenState extends State<AdminOrdersArchiveScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _StatusGroup _group = _StatusGroup.all;

  /// null = كل الفترات.
  int? _periodDays;

  /// نتيجة البحث العميق (خارج نافذة الـ٥٠٠ الأحدث) — تُملأ عند الطلب فقط.
  List<Order>? _deepResults;
  bool _deepSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// مطابقة نصّية حرّة على كل ما قد يتذكّره المدير عن الطلب: رقمه، اسم
  /// العميل أو جواله، المطعم، السائق، أو العنوان.
  bool _matchesQuery(Order o) {
    if (_query.isEmpty) return true;
    final q = _query;
    final haystack = [
      o.orderNumber,
      o.customerName,
      o.customerPhone,
      o.restaurantName,
      o.driverName ?? '',
      o.driverPhone ?? '',
      o.deliveryAddress,
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  bool _inPeriod(Order o) {
    if (_periodDays == null) return true;
    return o.createdAt
        .isAfter(DateTime.now().subtract(Duration(days: _periodDays!)));
  }

  /// شبكة الأمان: طلب أقدم من نافذة الـ٥٠٠ لا يظهر في التدفّق، فيُبحث عنه
  /// برقمه مباشرةً في القاعدة. لا يُشغَّل تلقائياً — استعلام لكل ضغطة زرّ
  /// أهون من استعلام مع كل حرف يكتبه المدير.
  Future<void> _deepSearch() async {
    final service = context.read<FirebaseService>();
    setState(() => _deepSearching = true);
    try {
      final found = await service.findOrdersByNumber(_query);
      if (mounted) setState(() => _deepResults = found);
    } catch (_) {
      if (mounted) {
        showError(context, tr('تعذّر البحث في الأرشيف الكامل',
            'Could not search the full archive'));
      }
    } finally {
      if (mounted) setState(() => _deepSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return AppStreamBuilder<List<Order>>(
      stream: service.streamAllOrders,
      builder: (ctx, all) {
        final filtered = all
            .where((o) => _group.matches(o.status))
            .where(_inPeriod)
            .where(_matchesQuery)
            .toList();

        // نتائج البحث العميق تُعرض وحدها حين لا تُطابق النافذة شيئاً —
        // وإلا التبس على المدير أيّ القائمتين يقرأ.
        final deep = _deepResults;
        final showDeep = filtered.isEmpty && deep != null && deep.isNotEmpty;
        final shown = showDeep ? deep : filtered;

        final total = shown.fold(0.0, (s, o) => s + o.payableTotal);

        return Column(children: [
          _SearchBar(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {
              _query = v.trim().toLowerCase().replaceAll('#', '');
              // أي تعديل على النص يُبطل نتيجة بحث سابقة عن رقم آخر.
              _deepResults = null;
            }),
          ),
          _FilterChips(
            group: _group,
            periodDays: _periodDays,
            onGroup: (g) => setState(() => _group = g),
            onPeriod: (d) => setState(() => _periodDays = d),
          ),
          // سطر الحصيلة: عدد الطلبات ومجموع قيمتها ضمن الفلاتر الحالية —
          // يجيب «كم طلباً ألغي هذا الأسبوع وبكم؟» بلا حساب يدوي.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.flavorColors.primary.withOpacity(0.06),
            child: Text(
              shown.isEmpty
                  ? tr('لا نتائج', 'No results')
                  : tr(
                      '${shown.length} طلب • إجمالي قيمتها ${formatCurrency(total)}'
                          '${showDeep ? ' (من الأرشيف الكامل)' : ''}',
                      '${shown.length} orders • total value ${formatCurrency(total)}'
                          '${showDeep ? ' (from the full archive)' : ''}'),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.flavorColors.primaryDark),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 40),
                    AppEmpty(
                      emoji: '🔍',
                      title: _query.isEmpty
                          ? tr('لا طلبات ضمن هذا الفلتر', 'No orders match this filter')
                          : tr('لا نتائج لبحثك ضمن آخر ٥٠٠ طلب',
                              'No results for your search in the latest 500 orders'),
                      subtitle: _query.isEmpty
                          ? null
                          : tr('الطلب قد يكون أقدم من ذلك — ابحث في الأرشيف الكامل برقمه',
                              'The order may be older than that — search the full archive by its number'),
                    ),
                    if (_query.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _deepSearching
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : OutlinedButton.icon(
                                  onPressed: _deepSearch,
                                  icon: const Icon(Icons.travel_explore_rounded,
                                      size: 18),
                                  label: Text(tr(
                                      'ابحث في الأرشيف الكامل برقم الطلب',
                                      'Search the full archive by order number')),
                                ),
                        ),
                      ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => _ArchiveCard(order: shown[i]),
                  ),
          ),
        ]);
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: tr('ابحث برقم الطلب أو العميل أو الجوال أو المطعم…',
                'Search by order number, customer, phone or restaurant…'),
            hintStyle: const TextStyle(fontSize: 13.5),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.12))),
          ),
        ),
      );
}

class _FilterChips extends StatelessWidget {
  final _StatusGroup group;
  final int? periodDays;
  final ValueChanged<_StatusGroup> onGroup;
  final ValueChanged<int?> onPeriod;
  const _FilterChips({
    required this.group,
    required this.periodDays,
    required this.onGroup,
    required this.onPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onTap(),
            backgroundColor: Colors.white,
            selectedColor: fc.primary.withOpacity(0.15),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? fc.primaryDark : AppColors.textDark,
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final g in _StatusGroup.values)
              chip(g.label, g == group, () => onGroup(g)),
          ]),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (label, days) in [
              (tr('اليوم', 'Today'), 1),
              (tr('٧ أيام', '7 days'), 7),
              (tr('٣٠ يوماً', '30 days'), 30),
              (tr('كل الفترات', 'All time'), 0),
            ])
              chip(label, (days == 0 ? null : days) == periodDays,
                  () => onPeriod(days == 0 ? null : days)),
          ]),
        ),
      ]),
    );
  }
}

/// بطاقة الأرشيف — بلغة بطاقة طلبات العميل نفسها (رأس ملوّن بالحالة، ملخص
/// أصناف، مبلغ بارز، أفعال حبوب)، مضافاً إليها ما يهم الإدارة وحدها:
/// طرفا الطلب معاً وسبب التعثّر إن وُجد.
class _ArchiveCard extends StatelessWidget {
  final Order order;
  const _ArchiveCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final st = o.status;
    final t = o.createdAt;
    final time = '${t.year}/${t.month}/${t.day} — '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: st.color.withOpacity(0.35)),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            color: st.color.withOpacity(0.10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: st.color.withOpacity(0.18)),
                child: Icon(st.icon, size: 15, color: st.color),
              ),
              const SizedBox(width: 8),
              Text(st.label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: st.color)),
              const Spacer(),
              Text('#${o.orderNumber}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12.5)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.storefront_rounded,
                        size: 16, color: AppColors.textGray),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(o.restaurantName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(time,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                  ]),
                  const SizedBox(height: 6),
                  // طرفا الطلب معاً — أول ما يبحث عنه المدير في المراجعة.
                  InfoRow(
                      icon: Icons.person_outline,
                      text: o.customerPhone.trim().isEmpty
                          ? o.customerName
                          : '${o.customerName} — ${o.customerPhone}'),
                  InfoRow(
                      icon: Icons.delivery_dining_outlined,
                      text: (o.driverName ?? '').trim().isEmpty
                          ? tr('بلا سائق', 'No driver')
                          : o.driverName!),
                  if (o.items.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      o.items
                          .map((i) => '${i.name} ×${i.quantity}')
                          .join(tr('، ', ', ')),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textGray, height: 1.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // سبب رفض المطعم يُعرض هنا لا في شاشة أخرى: بلا سببٍ ظاهر
                  // يبقى الطلب المتعثّر لغزاً عند المراجعة.
                  if ((o.rejectionReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(tr('السبب: ${o.rejectionReason}',
                              'Reason: ${o.rejectionReason}'),
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.error)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(formatCurrency(o.payableTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: AppColors.primaryDark)),
                    ),
                    const SizedBox(width: 8),
                    Text(o.paymentMethod.label,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _pill(
                      icon: Icons.receipt_long_outlined,
                      label: tr('الفاتورة', 'Receipt'),
                      color: AppColors.primary,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => OrderReceiptScreen(order: o))),
                    ),
                    _pill(
                      icon: Icons.chat_bubble_outline,
                      label: tr('المحادثة', 'Chat'),
                      color: AppColors.secondary,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => OrderChatScreen(order: o))),
                    ),
                    if (o.restaurantLat != null || o.deliveryLat != null)
                      _pill(
                        icon: Icons.map_outlined,
                        label: tr('الخريطة', 'Map'),
                        color: AppColors.secondary,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => OrderMapScreen(order: o))),
                      ),
                  ]),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Material(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ]),
          ),
        ),
      );
}
