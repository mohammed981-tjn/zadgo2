import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import 'admin_restaurants_tab.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('لوحة التحكم — ${auth.user?.name ?? ""}'), actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'change_password') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
            } else if (value == 'logout') {
              await auth.logout();
              if (mounted) Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'change_password',
                child: Row(children: [Icon(Icons.lock_reset_outlined, size: 20), SizedBox(width: 8), Text('تغيير كلمة المرور')])),
            PopupMenuItem(value: 'logout',
                child: Row(children: [Icon(Icons.logout, size: 20), SizedBox(width: 8), Text('تسجيل الخروج')])),
          ],
        ),
      ]),
      body: IndexedStack(index: _tab, children: const [
        _StatsTab(), AdminRestaurantsTab(), _OrdersTab(), _DriversTab(), _ChatsTab(), _ComplaintsTab(),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: 'المطاعم'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), label: 'السائقون'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'المحادثات'),
          NavigationDestination(icon: Icon(Icons.report_problem_outlined), label: 'الشكاوى'),
        ]),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Order>>(stream: service.streamAllOrders(), builder: (ctx, snap) {
      if (!snap.hasData) return const AppLoading();
      final orders = snap.data!;
      final delivered = orders.where((o) => o.status == OrderStatus.delivered).length;
      final active = orders.where((o) => o.status.isActive).length;
      final revenue = orders.where((o) => o.status == OrderStatus.delivered)
          .fold(0.0, (s, o) => s + o.grandTotal);
      return ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFc1121f)]),
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إجمالي الإيرادات', style: TextStyle(color: Colors.white70)),
            Text(formatCurrency(revenue), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          ])),
        const SizedBox(height: 16),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
          _stat('الطلبات', '${orders.length}', Icons.receipt_long, AppColors.primary),
          _stat('النشطة', '$active', Icons.hourglass_empty, AppColors.warning),
          _stat('مكتملة', '$delivered', Icons.done_all, AppColors.success),
        ]),
      ]);
    });
  }
  Widget _stat(String l, String v, IconData i, Color c) => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(i, color: c, size: 28), Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
      Text(l, style: const TextStyle(fontSize: 12)),
    ])));
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Order>>(stream: service.streamAllOrders(), builder: (ctx, snap) {
      if (!snap.hasData) return const AppLoading();
      final orders = snap.data!;
      if (orders.isEmpty) return const AppEmpty(emoji: '📦', title: 'لا يوجد طلبات');
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: orders.length, itemBuilder: (_, i) {
        final o = orders[i];
        return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('#${o.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(), StatusBadge(label: o.status.label, color: o.status.color)]),
            InfoRow(icon: Icons.restaurant, text: o.restaurantName),
            InfoRow(icon: Icons.person, text: o.customerName),
            Text(formatCurrency(o.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            if (o.status == OrderStatus.pending)
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: () => service.updateOrderStatus(o.id, OrderStatus.confirmed), child: const Text('تأكيد'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => service.cancelOrder(o.id), child: const Text('رفض'))),
              ]),
            if (o.status == OrderStatus.confirmed)
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => service.updateOrderStatus(o.id, OrderStatus.preparing), child: const Text('بدأ التحضير'))),
            if (o.status == OrderStatus.preparing)
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => service.updateOrderStatus(o.id, OrderStatus.readyForPickup), child: const Text('جاهز للاستلام'))),
            if (o.status == OrderStatus.readyForPickup && o.driverId == null)
              StreamBuilder<List<Driver>>(stream: service.streamDrivers(), builder: (ctx2, dSnap) {
                final drivers = (dSnap.data ?? []).where((d) => d.isAvailable && d.isOnline).toList();
                if (drivers.isEmpty) return const Text('لا يوجد سائقون متاحون', style: TextStyle(color: Colors.orange));
                return Wrap(spacing: 8, children: drivers.map((d) => ActionChip(label: Text(d.name),
                    onPressed: () => service.assignDriver(o.id, d.id, d.name))).toList());
              }),
            if (o.status == OrderStatus.outForDelivery)
              SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => service.markOrderDelivered(o.id, o.driverId ?? ''),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  child: const Text('تأكيد التوصيل'))),
          ])));
      });
    });
  }
}

class _DriversTab extends StatelessWidget {
  const _DriversTab();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Driver>>(stream: service.streamDrivers(), builder: (ctx, snap) {
      if (!snap.hasData) return const AppLoading();
      final all = snap.data!;
      final pending = all.where((d) => !d.isApproved).toList();
      final approved = all.where((d) => d.isApproved).toList();

      return ListView(padding: const EdgeInsets.all(12), children: [
        if (pending.isNotEmpty) ...[
          _sectionHeader('⏳ بانتظار الموافقة (${pending.length})', AppColors.warning),
          ...pending.map((d) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.warning.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: AppColors.warning.withOpacity(0.15),
                    child: Text(d.name.isNotEmpty ? d.name[0] : '?'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(d.phone, style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
                  ])),
                  StatusBadge(label: 'معلق', color: AppColors.warning),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('قبول'),
                      onPressed: () => service.approveDriver(d.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('رفض'),
                      onPressed: () => showDialog(
                        context: ctx,
                        builder: (_) => AlertDialog(
                          title: const Text('تأكيد الرفض'),
                          content: Text('هل تريد رفض طلب ${d.name}؟ لن يتمكن من استخدام التطبيق كسائق.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                            TextButton(
                              onPressed: () { service.rejectDriver(d.id); Navigator.pop(ctx); },
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                              child: const Text('رفض'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          )),
          const SizedBox(height: 8),
        ],

        if (approved.isNotEmpty)
          _sectionHeader('✅ السائقون النشطون (${approved.length})', AppColors.success),
        if (approved.isEmpty && pending.isEmpty)
          const AppEmpty(emoji: '🛵', title: 'لا يوجد سائقون'),
        ...approved.map((d) => Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: d.isOnline ? AppColors.success.withOpacity(0.2) : Colors.grey.shade200,
              child: Text(d.name.isNotEmpty ? d.name[0] : '?')),
          title: Text(d.name), subtitle: Text('${d.totalDeliveries} توصيلة  •  ${d.rating.toStringAsFixed(1)} ⭐'),
          trailing: StatusBadge(label: d.isOnline ? 'متصل' : 'غير متصل', color: d.isOnline ? AppColors.success : Colors.grey),
        ))),
      ]);
    });
  }

  Widget _sectionHeader(String title, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
  );
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Order>>(
      stream: service.streamAllOrders(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const AppLoading();
        final orders = snap.data!.where((o) => o.driverId != null).toList();
        if (orders.isEmpty) return const AppEmpty(emoji: '💬', title: 'لا توجد محادثات');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final o = orders[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                ),
                title: Text('#${o.orderNumber} — ${o.restaurantName}'),
                subtitle: Text(
                  '${o.customerName}  ↔  ${o.driverName ?? "السائق"}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: StatusBadge(label: o.status.label, color: o.status.color),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminChatScreen(order: o)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminChatScreen extends StatefulWidget {
  final Order order;
  const AdminChatScreen({super.key, required this.order});
  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final user = auth.user!;
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderId: widget.order.id,
      senderId: user.uid,
      senderName: 'الإدارة',
      senderRole: 'admin',
      text: text,
      createdAt: DateTime.now(),
    );
    _msgCtrl.clear();
    await service.sendChatMessage(msg);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final auth = context.read<app_auth.AuthProvider>();
    final myUid = auth.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('محادثة #${widget.order.orderNumber}'),
          Text(
            '${widget.order.customerName} ↔ ${widget.order.driverName ?? "السائق"}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: service.streamChatMessages(widget.order.id),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Center(child: Text('تعذّر التحميل: ${snap.error}'));
              }
              if (!snap.hasData) return const AppLoading();
              final messages = snap.data!;
              if (messages.isEmpty) {
                return const AppEmpty(emoji: '💬', title: 'لا توجد رسائل بعد');
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final m = messages[i];
                  final isMe = m.senderId == myUid;
                  final isAdmin = m.senderRole == 'admin';
                  Color bubbleColor = isMe
                      ? AppColors.primary
                      : (isAdmin ? AppColors.secondary : Colors.white);
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          isAdmin && !isMe ? '⚙️ الإدارة' : m.senderName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white70 : AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(m.text,
                            style: TextStyle(color: isMe || isAdmin ? Colors.white : AppColors.textDark)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: const InputDecoration(hintText: 'رسالة من الإدارة...'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _send,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ComplaintsTab extends StatelessWidget {
  const _ComplaintsTab();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Complaint>>(stream: service.streamComplaints(), builder: (ctx, snap) {
      if (!snap.hasData) return const AppLoading();
      final list = snap.data!;
      if (list.isEmpty) return const AppEmpty(emoji: '✅', title: 'لا يوجد شكاوى');
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (_, i) {
        final c = list[i];
        return Card(child: ListTile(
          title: Text('${c.type.label} — #${c.orderNumber}'),
          subtitle: Text(c.description, maxLines: 2),
          trailing: StatusBadge(label: c.status.label, color: c.status.color),
          onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
            title: const Text('تحديث حالة الشكوى'),
            content: Wrap(spacing: 8, children: ComplaintStatus.values.map((s) => ActionChip(
                label: Text(s.label), onPressed: () { service.updateComplaintStatus(c.id, s); Navigator.pop(context); },
              )).toList()),
          )),
        ));
      });
    });
  }
}
