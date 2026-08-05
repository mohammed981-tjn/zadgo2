// lib/screens/restaurant/restaurant_home.dart
//
// شاشة "مدير المطعم" — دور المطعم ثلاث مراحل فعلية فقط لا رابعة لها:
//   ١) تأكيد الاستلام   (restaurantPending  → restaurantAccepted)
//   ٢) جاري التحضير     (restaurantAccepted → preparing)
//   ٣) جاهز للاستلام    (preparing          → readyForPickup)
//
// بعد "جاهز للاستلام"، لا يملك المطعم أي زر إضافي. الانتقال التالي
// (readyForPickup → onTheWay) ينتج حصراً عن ضغطة السائق نفسه على "استلمت
// الطلب" في تطبيقه — لأن ضغطة المطعم وحدها غير موثوقة لتأكيد استلام لم
// يحدث فعلياً (قد يضغط المطعم قبل أن يصل السائق). بمجرد ضغطة السائق،
// شاشة المطعم تعرض تلقائياً شارة "تم التسليم" دون أي إجراء من طرفها.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import 'restaurant_reports_tab.dart';
import 'restaurant_menu_prices_tab.dart';

class RestaurantHome extends StatefulWidget {
  const RestaurantHome({super.key});

  @override
  State<RestaurantHome> createState() => _RestaurantHomeState();
}

class _RestaurantHomeState extends State<RestaurantHome> {
  int _tab = 0;

  Set<String> _knownPendingIds = {};
  bool _firstSnapshot = true;
  int _newOrdersBadgeCount = 0;
  OverlayEntry? _bannerEntry;

  @override
  void dispose() {
    _bannerEntry?.remove();
    super.dispose();
  }

  void _detectNewOrders(List<Order> allOrders) {
    final pendingNow =
        allOrders.where((o) => o.status == OrderStatus.restaurantPending).map((o) => o.id).toSet();

    if (_firstSnapshot) {
      _firstSnapshot = false;
      _knownPendingIds = pendingNow;
      return;
    }

    final newlyArrived = pendingNow.difference(_knownPendingIds);
    _knownPendingIds = pendingNow;

    if (newlyArrived.isEmpty) return;

    setState(() => _newOrdersBadgeCount += newlyArrived.length);
    _playAlertSound();
    _showNewOrderBanner(newlyArrived.length);
  }

  Future<void> _playAlertSound() async {
    for (var i = 0; i < 5; i++) {
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void _showNewOrderBanner(int count) {
    _bannerEntry?.remove();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              _bannerEntry?.remove();
              _bannerEntry = null;
              setState(() {
                _tab = 0;
                _newOrdersBadgeCount = 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    count == 1 ? 'طلب جديد وصل الآن' : '$count طلبات جديدة وصلت الآن',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, color: Colors.white),
              ]),
            ),
          ),
        ),
      ),
    );
    _bannerEntry = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 6), () {
      if (_bannerEntry == entry) {
        entry.remove();
        _bannerEntry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final restaurantId = auth.user?.restaurantId;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_tab) {
          0 => 'طلبات ${auth.user?.restaurantName ?? "المطعم"}',
          1 => 'التقارير والحسابات',
          _ => 'أسعار القائمة',
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              }
            },
          ),
        ],
      ),
      body: restaurantId == null || restaurantId.isEmpty
          ? const AppEmpty(
              emoji: '⚠️',
              title: 'حسابك غير مرتبط بمطعم',
              subtitle: 'يرجى مراجعة إدارة المنصة لربط الحساب بمطعم.',
            )
          : IndexedStack(index: _tab, children: [
              _RestaurantOrdersList(
                restaurantId: restaurantId,
                onOrdersChanged: _detectNewOrders,
              ),
              RestaurantReportsTab(restaurantId: restaurantId),
              RestaurantMenuPricesTab(restaurantId: restaurantId),
            ]),
      bottomNavigationBar: restaurantId == null || restaurantId.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() {
                _tab = i;
                if (i == 0) _newOrdersBadgeCount = 0;
              }),
              destinations: [
                NavigationDestination(
                  icon: _newOrdersBadgeCount > 0
                      ? Badge(
                          label: Text('$_newOrdersBadgeCount'),
                          backgroundColor: AppColors.error,
                          child: const Icon(Icons.receipt_long_outlined),
                        )
                      : const Icon(Icons.receipt_long_outlined),
                  label: 'الطلبات',
                ),
                const NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined), label: 'التقارير والحسابات'),
                const NavigationDestination(
                    icon: Icon(Icons.sell_outlined), label: 'الأسعار'),
              ],
            ),
    );
  }
}

/// قائمة طلبات المطعم، مقسّمة لتبويبين: نشطة ومنتهية.
///
/// "نشطة" = الطلبات التي ما زالت ضمن مسؤولية المطعم فعلياً (المراحل الثلاث
/// فقط، حسب [OrderStatusExt.isRestaurantResponsibility]). "منتهية" = كل ما
/// خرج من مسؤولية المطعم — بما فيها onTheWay فور ضغطة السائق، رغم أن
/// المطعم لم يضغط شيئاً بنفسه.
class _RestaurantOrdersList extends StatefulWidget {
  final String restaurantId;
  final void Function(List<Order> allOrders) onOrdersChanged;
  const _RestaurantOrdersList({required this.restaurantId, required this.onOrdersChanged});

  @override
  State<_RestaurantOrdersList> createState() => _RestaurantOrdersListState();
}

class _RestaurantOrdersListState extends State<_RestaurantOrdersList>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Column(children: [
      Material(
        color: Colors.white,
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGray,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'نشطة'),
            Tab(text: 'منتهية'),
          ],
        ),
      ),
      Expanded(
        child: AppStreamBuilder<List<Order>>(
          stream: () => service.streamRestaurantOrders(widget.restaurantId),
          builder: (ctx, orders) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onOrdersChanged(orders);
            });

            final active =
                orders.where((o) => o.status.isRestaurantResponsibility).toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            final finished =
                orders.where((o) => !o.status.isRestaurantResponsibility).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return TabBarView(controller: _tabController, children: [
              _OrdersListView(
                orders: active,
                service: service,
                emptyEmoji: '🔔',
                emptyTitle: 'لا يوجد طلبات نشطة حالياً',
              ),
              _OrdersListView(
                orders: finished,
                service: service,
                emptyEmoji: '📋',
                emptyTitle: 'لا يوجد طلبات منتهية بعد',
              ),
            ]);
          },
        ),
      ),
    ]);
  }
}

class _OrdersListView extends StatelessWidget {
  final List<Order> orders;
  final FirebaseService service;
  final String emptyEmoji;
  final String emptyTitle;
  const _OrdersListView({
    required this.orders,
    required this.service,
    required this.emptyEmoji,
    required this.emptyTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return AppEmpty(emoji: emptyEmoji, title: emptyTitle);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, i) => _RestaurantOrderCard(
        order: orders[i],
        service: service,
        highlightAsNew: i == 0 && orders[i].status == OrderStatus.restaurantPending,
      ),
    );
  }
}

class _RestaurantOrderCard extends StatefulWidget {
  final Order order;
  final FirebaseService service;
  final bool highlightAsNew;
  const _RestaurantOrderCard({
    required this.order,
    required this.service,
    this.highlightAsNew = false,
  });

  @override
  State<_RestaurantOrderCard> createState() => _RestaurantOrderCardState();
}

class _RestaurantOrderCardState extends State<_RestaurantOrderCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.highlightAsNew) {
      var completedCycles = 0;
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) {
            completedCycles++;
            if (completedCycles >= 5) {
              _pulseController?.stop();
            }
          }
        })
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  /// نص ولون وأيقونة الشارة العلوية. الحالات بعد readyForPickup
  /// (searchingDriver/driverAssigned/onTheWay/delivered) لا تخص المطعم
  /// بإجراء، وتُعرض جميعها بنص "تم التسليم — جاري التوصيل" لأن انتقالها
  /// كلها ناتج عن فعل السائق أو المدير لا المطعم.
  (String, Color, IconData) get _bannerInfo {
    switch (widget.order.status) {
      case OrderStatus.restaurantPending:
        return ('طلب جديد بانتظار التأكيد', AppColors.warning, Icons.fiber_new_rounded);
      case OrderStatus.restaurantAccepted:
        return ('تم تأكيد الاستلام', AppColors.primary, Icons.check_circle_outline_rounded);
      case OrderStatus.preparing:
        return ('جاري التحضير', AppColors.primary, Icons.restaurant_rounded);
      case OrderStatus.readyForPickup:
        return ('جاهز — بانتظار استلام السائق', Colors.teal, Icons.shopping_bag_rounded);
      case OrderStatus.restaurantRejected:
        return ('تم رفض الطلب', AppColors.error, Icons.block_rounded);
      case OrderStatus.searchingDriver:
      case OrderStatus.driverAssigned:
      case OrderStatus.onTheWay:
        return ('تم التسليم — جاري التوصيل', AppColors.success, Icons.delivery_dining_rounded);
      case OrderStatus.delivered:
        return ('تم التوصيل للعميل', AppColors.success, Icons.done_all_rounded);
      default:
        return (widget.order.status.label, widget.order.status.color, Icons.info_outline_rounded);
    }
  }

  String _waitingLabel() {
    final elapsed = DateTime.now().difference(widget.order.createdAt);
    if (elapsed.inMinutes < 1) return 'منذ لحظات';
    if (elapsed.inMinutes < 60) return 'منذ ${elapsed.inMinutes} د';
    final hours = elapsed.inHours;
    final mins = elapsed.inMinutes % 60;
    return mins == 0 ? 'منذ $hours س' : 'منذ $hours س $mins د';
  }

  Future<void> _call(BuildContext context, String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: trimmed);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        showError(context, 'تعذّر فتح تطبيق الاتصال على هذا الجهاز');
      }
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر فتح تطبيق الاتصال');
    }
  }

  Future<void> _confirmAcceptance(BuildContext context) async {
    setState(() => _actionLoading = true);
    try {
      await widget.service.updateOrderStatus(widget.order.id, OrderStatus.restaurantAccepted);
      await widget.service.tryAutoAssignOnAcceptance(widget.order);
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر تحديث حالة الطلب');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _confirmReady(BuildContext context) async {
    setState(() => _actionLoading = true);
    try {
      await widget.service.updateOrderStatus(widget.order.id, OrderStatus.readyForPickup);
      await widget.service.retryAutoAssignIfNeeded(widget.order);
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر تحديث حالة الطلب');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _runStatusChange(BuildContext context, OrderStatus to) async {
    setState(() => _actionLoading = true);
    try {
      await widget.service.updateOrderStatus(widget.order.id, to);
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر تحديث حالة الطلب');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض',
              hintText: 'مثال: نفد أحد الأصناف، المطعم مغلق مؤقتاً...',
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة سبب الرفض' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogCtx, ctrl.text.trim());
              }
            },
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    setState(() => _actionLoading = true);
    try {
      await widget.service.rejectOrderByRestaurant(widget.order.id, reason);
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر رفض الطلب');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final (bannerLabel, bannerColor, bannerIcon) = _bannerInfo;

    final cardContent = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bannerColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(bannerIcon, size: 16, color: bannerColor),
            const SizedBox(width: 6),
            Text(bannerLabel,
                style: TextStyle(color: bannerColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          Text(formatCurrency(order.itemsTotal),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.person_outline, size: 15, color: AppColors.textGray),
          const SizedBox(width: 6),
          Expanded(
            child: Text(order.customerName,
                style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.timer_outlined, size: 14, color: AppColors.textGray.withOpacity(0.8)),
          const SizedBox(width: 3),
          Text(_waitingLabel(),
              style: TextStyle(fontSize: 12, color: AppColors.textGray.withOpacity(0.8))),
          if (order.customerPhone.trim().isNotEmpty)
            IconButton(
              tooltip: 'الاتصال بالعميل',
              icon: const Icon(Icons.call_outlined, color: AppColors.success, size: 20),
              visualDensity: VisualDensity.compact,
              onPressed: () => _call(context, order.customerPhone),
            ),
        ]),
        const Divider(height: 20),
        ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${item.quantity}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textDark)),
                    if (item.extras != null && item.extras!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(item.extras!,
                            style: TextStyle(fontSize: 12, color: AppColors.textGray.withOpacity(0.9))),
                      ),
                  ]),
                ),
              ]),
            )),
        if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(order.notes!,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textDark)),
              ),
            ]),
          ),
        ],
        if (order.status == OrderStatus.restaurantRejected &&
            order.rejectionReason != null &&
            order.rejectionReason!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.block_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text('سبب الرفض: ${order.rejectionReason}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textDark)),
              ),
            ]),
          ),
        ],
        // ===================================================================
        // المطعم يملك ثلاثة أزرار فقط. بعد "جاهز للاستلام" لا يوجد أي زر
        // إضافي — الشارة العلوية وحدها تُعلم المطعم بما يجري لاحقاً، لأن
        // إخراج الطلب من مسؤوليته يقرره السائق بضغطته هو، لا المطعم.
        // ===================================================================
        if (order.status == OrderStatus.restaurantPending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _ActionButton(
                label: 'تأكيد الاستلام',
                color: AppColors.primary,
                loading: _actionLoading,
                onPressed: () => _confirmAcceptance(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'رفض',
                color: AppColors.error,
                loading: _actionLoading,
                onPressed: () => _showRejectDialog(context),
              ),
            ),
          ]),
        ],
        if (order.status == OrderStatus.restaurantAccepted) ...[
          const SizedBox(height: 10),
          _ActionButton(
            label: 'جاري التحضير',
            color: AppColors.primary,
            loading: _actionLoading,
            onPressed: () => _runStatusChange(context, OrderStatus.preparing),
          ),
        ],
        if (order.status == OrderStatus.preparing) ...[
          const SizedBox(height: 10),
          _ActionButton(
            label: 'جاهز للاستلام',
            color: AppColors.success,
            loading: _actionLoading,
            onPressed: () => _confirmReady(context),
          ),
        ],
      ]),
    );

    if (_pulseController == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: cardContent,
      );
    }

    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Color.lerp(Colors.white, AppColors.warning.withOpacity(0.15), _pulseController!.value),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.warning.withOpacity(0.5 + _pulseController!.value * 0.5), width: 1.5),
        ),
        child: child,
      ),
      child: cardContent,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool loading;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
}