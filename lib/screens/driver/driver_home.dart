import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, SystemSound, SystemSoundType;
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
import '../customer/submit_complaint_screen.dart';
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

  final Set<String> _acknowledgedNotified = {};
  final Set<String> _autoAssignedNotified = {};
  OverlayEntry? _bannerEntry;

  @override
  void initState() {
    super.initState();
    _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pushLocation());
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _bannerEntry?.remove();
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

  /// نغمة + اهتزاز مع كل إسناد جديد — الشريط الصامت لا يلفت سائقاً هاتفه
  /// في جيبه أو على حامل الدراجة.
  Future<void> _playAssignmentSound() async {
    for (var i = 0; i < 4; i++) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  void _checkForNotifications(List<Order> orders) {
    for (final o in orders) {
      if (o.needsDriverAcknowledgement) {
        if (!_acknowledgedNotified.contains(o.id)) {
          _acknowledgedNotified.add(o.id);
          _playAssignmentSound();
          _showDecisionBanner(o);
        }
      } else if (o.driverId != null &&
          o.driverId!.isNotEmpty &&
          o.status == OrderStatus.driverAssigned) {
        if (!_autoAssignedNotified.contains(o.id)) {
          _autoAssignedNotified.add(o.id);
          _playAssignmentSound();
          _showInfoBanner(o);
        }
      }
    }
  }

  void _showDecisionBanner(Order order) {
    _bannerEntry?.remove();
    final overlay = Overlay.of(context);
    final service = context.read<FirebaseService>();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.local_shipping_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'طلب #${order.orderNumber} أُسند إليك — بانتظار قرارك',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                '${order.restaurantName} ← ${order.deliveryAddress}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      entry.remove();
                      _bannerEntry = null;
                      await service.rejectAssignedOrder(order.id);
                    },
                    child: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.warning,
                    ),
                    onPressed: () async {
                      entry.remove();
                      _bannerEntry = null;
                      await service.acceptAssignedOrder(order.id);
                    },
                    child: const Text('قبول'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
    _bannerEntry = entry;
    overlay.insert(entry);
  }

  void _showInfoBanner(Order order) {
    if (_bannerEntry != null) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'طلب جديد #${order.orderNumber} أُسند إليك',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    _bannerEntry = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (_bannerEntry == entry) {
        entry.remove();
        _bannerEntry = null;
      }
    });
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
                _MyOrdersTab(
                  driverId: driverId,
                  driver: driver,
                  onOrdersChanged: _checkForNotifications,
                ),
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

class _MyOrdersTab extends StatelessWidget {
  final String driverId;
  final Driver? driver;
  final void Function(List<Order> orders) onOrdersChanged;
  const _MyOrdersTab({required this.driverId, this.driver, required this.onOrdersChanged});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return AppStreamBuilder<List<Order>>(
      stream: () => service.streamDriverOrders(driverId),
      builder: (ctx, all) {
        final active = all.where((o) => o.status.isActive).toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onOrdersChanged(active);
        });

        final confirmedActive =
            active.where((o) => !o.needsDriverAcknowledgement).toList();

        if (confirmedActive.isEmpty) {
          return AppEmpty(
            emoji: (driver?.isOnline ?? false) ? '📦' : '🔌',
            title: 'لا توجد طلبات نشطة حالياً',
            subtitle: 'سيُسند إليك أي طلب جديد تلقائياً فور توفره',
          );
        }

        return ListView(padding: const EdgeInsets.all(12), children: [
          const SectionHeader(title: 'طلباتي'),
          ...confirmedActive.map((o) => _OrderCard(order: o)),
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
    final auth = context.read<app_auth.AuthProvider>();

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
            // الاتصال بالعميل — بعد استلام الطلب من المطعم، حيث يبدأ السائق
            // التوجّه للعميل وقد يحتاج تأكيد العنوان أو الوصول.
            if ((order.status == OrderStatus.pickedUp ||
                    order.status == OrderStatus.onTheWay) &&
                order.customerPhone.trim().isNotEmpty)
              IconButton(
                icon: const Icon(Icons.phone, color: AppColors.success),
                onPressed: () => callPhone(context, order.customerPhone),
                tooltip: 'الاتصال بالعميل',
              ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.secondary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderChatScreen(order: order))),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, color: AppColors.secondary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderMapScreen(order: order, readOnly: false))),
            ),
            // ✅ زر الشكوى — يفتح شاشة تقديم شكوى مشتركة، مع تحديد السائق
            // كمُقدِّم الشكوى (submittedByRole: driver) لتظهر له خيارات
            // "ضد العميل" أو "ضد المطعم" فقط (لا يمكنه الشكوى ضد نفسه).
            // يختفي بعد انتهاء مهلة الشكوى (24 ساعة من إنهاء الطلب).
            if (order.canSubmitComplaint)
              IconButton(
                icon: const Icon(Icons.report_problem_outlined, color: AppColors.warning),
                tooltip: 'تقديم شكوى',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubmitComplaintScreen(
                      order: order,
                      submittedByUid: auth.user?.uid ?? '',
                      submittedByName: auth.user?.name ?? '',
                      submittedByRole: UserRole.driver,
                    ),
                  ),
                ),
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

  Widget _buildAction(BuildContext ctx, FirebaseService service) {
    if (order.status == OrderStatus.restaurantPending ||
        order.status == OrderStatus.restaurantAccepted ||
        order.status == OrderStatus.preparing) {
      return const Text('الطلب قيد التحضير عند المطعم — سنُعلمك فور جهوزيته',
          style: TextStyle(color: AppColors.textGray, fontStyle: FontStyle.italic));
    }
    if (order.status == OrderStatus.readyForPickup ||
        order.status == OrderStatus.searchingDriver ||
        order.status == OrderStatus.driverAssigned) {
      return SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () async {
          final ok = await showConfirmDialog(ctx, title: 'استلام الطلب', content: 'هل استلمت الطلب فعلياً من المطعم؟', confirmLabel: 'نعم');
          if (ok == true) {
            await service.markPickedUpBySelf(order.id);
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
    // الرصيد بإشارة: سالب يعني أن بيد السائق مالاً ليس له (حصيلة الطلبات
    // النقدية)، وموجب يعني أن للتطبيق مستحقّات عليه للسائق. عرضه برقم مجرّد
    // كان سيوهم السائق بأن الدَّين ربح.
    final owesPlatform = d.balance < 0;
    final amount = d.balance.abs();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: owesPlatform
                ? [AppColors.error, const Color(0xFFB71C1C)]
                : [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(owesPlatform ? 'مبلغ عليك تسليمه' : 'رصيدك لدى التطبيق',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Text(formatCurrency(amount),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            owesPlatform
                ? 'حصيلة طلبات نقدية بيدك — تُسلَّم للإدارة'
                : 'مستحقّاتك من الطلبات المدفوعة إلكترونياً',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ]),
      ),
      if (Pricing.isDriverDebtWarning(d.balance))
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('يُفضّل تسليم المبلغ للإدارة قريباً',
                    style: TextStyle(fontSize: 12, color: AppColors.warning)),
              ),
            ]),
          ),
        ),
      const SizedBox(height: 20),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
        _stat('التوصيلات', '${d.totalDeliveries}', Icons.local_shipping_outlined, AppColors.primary),
        _stat('استلمته فعلياً', formatCurrency(d.totalEarnings), Icons.savings_outlined, AppColors.success),
        _stat('التقييم', d.rating.toStringAsFixed(1), Icons.star_rounded, Colors.amber),
        _stat('الحالة', d.isOnline ? 'متصل' : 'غير متصل', d.isOnline ? Icons.wifi : Icons.wifi_off,
            d.isOnline ? AppColors.success : AppColors.textGray),
      ]),
      const SizedBox(height: 16),
      const SectionHeader(title: 'سجلّ الحركات'),
      SizedBox(
        height: 320,
        child: AppStreamBuilder<List<DriverTransaction>>(
          stream: () => context.read<FirebaseService>().streamDriverTransactions(d.id),
          builder: (ctx, txs) {
            if (txs.isEmpty) {
              return const AppEmpty(emoji: '🧾', title: 'لا توجد حركات بعد');
            }
            return ListView.builder(
              itemCount: txs.length,
              itemBuilder: (_, i) => _TransactionTile(tx: txs[i]),
            );
          },
        ),
      ),
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

/// سطر حركة واحدة في سجلّ دفتر السائق — اللون والإشارة يوضّحان الاتجاه فوراً.
class _TransactionTile extends StatelessWidget {
  final DriverTransaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount >= 0;
    final color = positive ? AppColors.success : AppColors.error;
    return ListTile(
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
          '${tx.createdAt.day}/${tx.createdAt.month}',
        ].join(' • '),
        style: const TextStyle(fontSize: 11, color: AppColors.textGray),
      ),
      trailing: Text(
        '${positive ? '+' : '−'}${formatCurrency(tx.amount.abs())}',
        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
      ),
    );
  }
}
