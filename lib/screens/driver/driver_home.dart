// lib/screens/driver/driver_home.dart
//
// شاشة السائق — لا يملك حق رفض طلب مُسنَد إليه؛ الالتزام إلزامي حتى
// التسليم، إلا في حالة عطل يعالجه المدير يدوياً (تحويل الطلب لسائق آخر).
//
// [إصلاح permission-denied]: كانت الشاشة تستدعي streamAllOrders() — استعلام
// list بلا أي فلتر، ترفضه قواعد Firestore فوراً لأن السائق لا يملك حق
// list على كل الطلبات (فقط على ما يخصه: driverId == currentUid()). استُبدلت
// بـ streamDriverOrders(driverId)، المصدر الوحيد الآمن تحت القواعد الحالية.
//
// أثر جانبي مقصود: هذا يُلغي تبويب "طلبات متاحة للقبول" بالكامل — لم يعد
// له داعٍ أصلاً، لأن التعيين صار تلقائياً بالكامل من طرف النظام (عند تأكيد
// المطعم للاستلام، وشبكة أمان عند تعليمه جاهزاً)، لا باختيار السائق يدوياً.
// السائق يرى فقط طلباته المُسنَدة، بدءاً من اللحظة التي يؤكد فيها المطعم
// الاستلام (قد تكون الحالة عندها restaurantAccepted أو preparing، قبل أن
// يصبح الطلب جاهزاً فعلياً) — فيرى شارة توضح أن الطلب قيد التحضير، بلا أي
// زر إجراء، حتى تصل الحالة فعلياً لـ driverAssigned.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import '../customer/order_map_screen.dart';
import '../customer/order_chat_screen.dart';
import '../../navigator_key.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});
  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  int _tab = 0;
  Timer? _locationTimer;
  double _simLat = 24.7136;
  double _simLng = 46.6753;
  int _driverStreamRetryToken = 0;

  @override
  void initState() {
    super.initState();
    _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pushLocation());
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _pushLocation() {
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final driverId = auth.user?.uid;
    if (driverId == null) return;
    _simLat += (0.0003 * (DateTime.now().second.isEven ? 1 : -1));
    _simLng += (0.0003 * (DateTime.now().second.isOdd ? 1 : -1));
    service.updateDriverLocation(driverId, _simLat, _simLng);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final driverId = auth.user?.uid ?? '';

    return StreamBuilder<Driver?>(
      key: ValueKey(_driverStreamRetryToken),
      stream: service.streamDriver(driverId),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: AppError(
              error: snap.error,
              onRetry: () => setState(() => _driverStreamRetryToken++),
            ),
          );
        }
        final driver = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text('مرحباً ${auth.user?.name ?? ""}'),
            actions: [
              if (driver != null)
                Row(children: [
                  Text(driver.isOnline ? 'متصل' : 'غير متصل',
                      style: TextStyle(color: driver.isOnline ? Colors.greenAccent : Colors.white54, fontSize: 12)),
                  Switch(value: driver.isOnline, onChanged: (v) => service.setDriverOnline(driverId, v),
                      activeColor: Colors.greenAccent),
                ]),
              IconButton(icon: const Icon(Icons.logout), onPressed: () async {
                if (driver != null) await service.setDriverOnline(driverId, false);
                await auth.logout();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                }
              }),
            ],
          ),
          body: Column(children: [
            StreamBuilder<List<BroadcastMessage>>(
              stream: service.streamBroadcasts(BroadcastAudience.drivers),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  debugPrint('BroadcastBanner error: ${snap.error}');
                  return const SizedBox.shrink();
                }
                final list = snap.data;
                if (list == null || list.isEmpty) return const SizedBox.shrink();
                final latest = list.first;
                return BroadcastBanner(title: latest.title, body: latest.body);
              },
            ),
            Expanded(
              child: IndexedStack(index: _tab, children: [
                _MyOrdersTab(driverId: driverId, driver: driver),
                _DriverEarningsTab(driver: driver),
              ]),
            ),
          ]),
          bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'الطلبات'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'أرباحي'),
            ]),
        );
      },
    );
  }
}

/// طلبات السائق الخاصة به فقط — عبر streamDriverOrders الآمنة تحت القواعد.
/// تعرض كل طلب مُسنَد له بصرف النظر عن حالته (حتى لو ما زال قيد التحضير
/// عند المطعم، بسبب التعيين المبكر)، حتى المكتمل منها (delivered) — يستفيد
/// السائق من رؤية سجل توصيلاته دون تبويب منفصل مخصص لذلك.
class _MyOrdersTab extends StatelessWidget {
  final String driverId;
  final Driver? driver;
  const _MyOrdersTab({required this.driverId, this.driver});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return AppStreamBuilder<List<Order>>(
      stream: () => service.streamDriverOrders(driverId),
      builder: (ctx, all) {
        final active = all.where((o) => o.status.isActive).toList();

        if (active.isEmpty) {
          return AppEmpty(
            emoji: (driver?.isOnline ?? false) ? '📦' : '🔌',
            title: 'لا توجد طلبات نشطة حالياً',
            subtitle: 'سيُسند إليك أي طلب جديد تلقائياً فور توفره',
          );
        }

        return ListView(padding: const EdgeInsets.all(12), children: [
          const SectionHeader(title: 'طلباتي'),
          ...active.map((o) => _OrderCard(order: o)),
        ]);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.secondary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderChatScreen(order: order))),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, color: AppColors.secondary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderMapScreen(order: order, readOnly: false))),
            ),
            StatusBadge(label: order.status.label, color: order.status.color, icon: order.status.icon),
          ]),
          const SizedBox(height: 10),
          InfoRow(icon: Icons.restaurant_outlined, text: order.restaurantName),
          InfoRow(icon: Icons.person_outline, text: '${order.customerName} — ${order.customerPhone}'),
          InfoRow(icon: Icons.location_on_outlined, text: order.deliveryAddress),
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(formatCurrency(order.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(order.paymentMethod.label, style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          _buildAction(context, service),
        ]),
      ),
    );
  }

  /// إجراء السائق حسب الحالة — لا زر رفض أو قبول: التعيين تلقائي والالتزام
  /// إلزامي، فلا حاجة لأي إجراء من السائق قبل driverAssigned.
  Widget _buildAction(BuildContext ctx, FirebaseService service) {
    // الطلب مُسنَد له مبكراً لكن ما زال عند المطعم — لا إجراء ممكن بعد،
    // فقط رسالة توضيحية بدل زر معطل قد يوحي بإمكانية غير متاحة فعلاً.
    if (order.status == OrderStatus.restaurantPending ||
        order.status == OrderStatus.restaurantAccepted ||
        order.status == OrderStatus.preparing) {
      return const Text('الطلب قيد التحضير عند المطعم — سنُعلمك فور جهوزيته',
          style: TextStyle(color: AppColors.textGray, fontStyle: FontStyle.italic));
    }
    // جاهز عند المطعم لكن لم يُسلَّم للسائق فعلياً بعد (المطعم لم يضغط "تم
    // التسليم" بعد رغم تعليمه جاهزاً).
    if (order.status == OrderStatus.readyForPickup || order.status == OrderStatus.searchingDriver) {
      return const Text('الطلب جاهز — بانتظار تسليمه إليك من المطعم',
          style: TextStyle(color: AppColors.textGray, fontStyle: FontStyle.italic));
    }
    if (order.status == OrderStatus.driverAssigned) {
      return SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () async {
          final ok = await showConfirmDialog(ctx, title: 'استلام الطلب', content: 'هل استلمت الطلب من المطعم؟', confirmLabel: 'نعم');
          if (ok == true) {
            await service.markOrderPickedUp(order.id);
            final now = DateTime.now();
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => OrderMapScreen(
                  order: order.copyWith(
                    status: OrderStatus.onTheWay,
                    updatedAt: now,
                    statusChangedAt: now,
                  ),
                  readOnly: false,
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.delivery_dining),
        label: const Text('استلمت الطلب — في الطريق'),
      ));
    }
    if (order.status == OrderStatus.onTheWay) {
      return SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () async {
          final ok = await showConfirmDialog(ctx, title: 'تأكيد التوصيل', content: 'هل تم توصيل الطلب للعميل؟', confirmLabel: 'نعم');
          if (ok == true) {
            await service.markOrderDelivered(order.id, order.driverId ?? '');
            if (ctx.mounted) showSuccess(ctx, 'تم التوصيل! +${order.driverShare.toStringAsFixed(2)} ر.س أرباح');
          }
        },
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
        icon: const Icon(Icons.done_all_rounded),
        label: const Text('تأكيد التوصيل'),
      ));
    }
    return const SizedBox.shrink();
  }
}

class _DriverEarningsTab extends StatelessWidget {
  final Driver? driver;
  const _DriverEarningsTab({this.driver});

  @override
  Widget build(BuildContext context) {
    if (driver == null) return const AppLoading();
    final d = driver!;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('إجمالي أرباحك', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Text(formatCurrency(d.totalEarnings), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(height: 20),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
        _stat('التوصيلات', '${d.totalDeliveries}', Icons.local_shipping_outlined, AppColors.primary),
        _stat('المستحقات', formatCurrency(d.pendingPayout), Icons.account_balance_wallet_outlined, AppColors.warning),
        _stat('التقييم', d.rating.toStringAsFixed(1), Icons.star_rounded, Colors.amber),
        _stat('الحالة', d.isOnline ? 'متصل' : 'غير متصل', d.isOnline ? Icons.wifi : Icons.wifi_off,
            d.isOnline ? AppColors.success : AppColors.textGray),
      ]),
    ]);
  }

  Widget _stat(String label, String value, IconData icon, Color color) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 28),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 12)),
    ])));
}