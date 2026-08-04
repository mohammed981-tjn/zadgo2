import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import 'admin_restaurants_tab.dart';
import 'admin_users_tab.dart';
import 'order_tracking_tab.dart';
import 'broadcast_tab.dart';

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
        IconButton(icon: const Icon(Icons.logout), onPressed: () async {
          await auth.logout();
          if (mounted) Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        }),
      ]),
      // تبويب "الطلبات" (_OrdersTab) حُذف نهائياً من هنا — كان مكرَّراً مع
      // "المتابعة الحية" (OrderTrackingTab) الأكثر اكتمالاً (تنبيهات مُهل،
      // تحويل سائق، إسناد يدوي)، بالإضافة إلى احتوائه أزرار "بدأ التحضير"
      // و"جاهز للاستلام" التي هي من اختصاص المطعم حصراً (موجودة فعلياً في
      // restaurant_home.dart)، لا المدير العام.
      body: IndexedStack(index: _tab, children: const [
        _StatsTab(), AdminRestaurantsTab(), OrderTrackingTab(), _DriversTab(), _ComplaintsTab(), BroadcastTab(), AdminUsersTab(),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: 'المطاعم'),
          NavigationDestination(icon: Icon(Icons.gps_fixed_outlined), label: 'المتابعة الحية'),
          NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), label: 'السائقون'),
          NavigationDestination(icon: Icon(Icons.report_problem_outlined), label: 'الشكاوى'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'بث جماعي'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'المستخدمون'),
        ]),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Order>>(stream: service.streamAllOrders, builder: (ctx, orders) {
      final delivered = orders.where((o) => o.status == OrderStatus.delivered).length;
      final active = orders.where((o) => o.status.isActive).length;
      final revenue = orders.where((o) => o.status == OrderStatus.delivered)
          .fold(0.0, (s, o) => s + o.grandTotal);
      return ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إجمالي الإيرادات', style: TextStyle(color: Colors.white70)),
            Text(formatCurrency(revenue), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          ])),
        const SizedBox(height: 16),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
          _stat('الطلبات', '${orders.length}', Icons.receipt_long_outlined, AppColors.primary),
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

class _DriversTab extends StatelessWidget {
  const _DriversTab();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Driver>>(stream: service.streamDrivers, builder: (ctx, list) {
      if (list.isEmpty) return const AppEmpty(emoji: '🛵', title: 'لا يوجد سائقون');
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (_, i) {
        final d = list[i];
        return Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: d.isOnline ? AppColors.success.withOpacity(0.2) : Colors.grey.shade200,
              child: Text(d.name.isNotEmpty ? d.name[0] : '?')),
          title: Text(d.name), subtitle: Text('${d.totalDeliveries} توصيلة  •  ${d.rating.toStringAsFixed(1)} ⭐'),
          trailing: StatusBadge(label: d.isOnline ? 'متصل' : 'غير متصل', color: d.isOnline ? AppColors.success : Colors.grey),
        ));
      });
    });
  }
}

class _ComplaintsTab extends StatelessWidget {
  const _ComplaintsTab();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Complaint>>(stream: service.streamComplaints, builder: (ctx, list) {
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