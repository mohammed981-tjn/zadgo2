// lib/screens/admin/admin_home.dart
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
import 'admin_complaints_screen.dart';
import 'admin_reports_tab.dart';
import 'admin_driver_ledger_screen.dart';

/// شاشة المدير الرئيسية — أُعيدت هيكلتها لتحترم قاعدة "3-5 عناصر كحد أقصى"
/// للتنقل السفلي على الجوال (كما توصي بها Material Design 3 وiOS HIG).
///
/// الشريط السفلي يحتوي الآن 5 مهام يومية متكررة فقط: الرئيسية، المتابعة
/// الحية، الشكاوى، السائقون، المطاعم. أما المهام الأقل تكراراً (إدارة
/// المستخدمين، البث الجماعي) فانتقلت لقائمة جانبية (Drawer) تُفتح من
/// أيقونة القائمة أعلى الشاشة — نفس نمط Gmail (بريد أساسي في الأسفل،
/// تبديل حسابات ومجلدات في الدرج الجانبي).
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  static const _tabTitles = ['الرئيسية', 'المتابعة الحية', 'الشكاوى', 'السائقون', 'المطاعم'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text('${_tabTitles[_tab]} — ${auth.user?.name ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  Text(auth.user?.name ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('إدارة إضافية', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('التقارير المالية'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'التقارير المالية', child: AdminReportsTab())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('المستخدمون'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'المستخدمون', child: AdminUsersTab())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('بث جماعي'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'بث جماعي', child: BroadcastTab())));
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _tab, children: const [
        _StatsTab(),
        OrderTrackingTab(),
        AdminComplaintsScreen(),
        _DriversTab(),
        AdminRestaurantsTab(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.gps_fixed_outlined), label: 'المتابعة الحية'),
          NavigationDestination(icon: Icon(Icons.report_problem_outlined), label: 'الشكاوى'),
          NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), label: 'السائقون'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: 'المطاعم'),
        ],
      ),
    );
  }
}

/// غلاف بسيط لعرض تبويب من الدرج كشاشة مستقلة بشريط عنوان خاص بها، بدل
/// افتراض وجودها ضمن IndexedStack الرئيسي.
class _DrawerScreen extends StatelessWidget {
  final String title;
  final Widget child;
  const _DrawerScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: child,
      );
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
        // الرصيد بإشارة يظهر في القائمة مباشرةً ليعرف المدير بنظرة مَن عليه
        // مال نقدي لم يُسلَّم بعد، والنقر يفتح دفتر حسابه الكامل.
        final owes = d.balance < 0;
        return Card(child: ListTile(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AdminDriverLedgerScreen(driver: d))),
          leading: CircleAvatar(backgroundColor: d.isOnline ? AppColors.success.withOpacity(0.2) : Colors.grey.shade200,
              child: Text(d.name.isNotEmpty ? d.name[0] : '?')),
          title: Text(d.name),
          subtitle: Text('${d.totalDeliveries} توصيلة  •  ${d.rating.toStringAsFixed(1)} ⭐'
              '${d.warningCount > 0 ? '  •  ⚠️ ${d.warningCount} إنذار' : ''}'),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (d.balance != 0)
              Text('${owes ? 'عليه ' : 'له '}${formatCurrency(d.balance.abs())}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: owes ? AppColors.error : AppColors.success)),
            StatusBadge(label: d.isOnline ? 'متصل' : 'غير متصل', color: d.isOnline ? AppColors.success : Colors.grey),
          ]),
        ));
      });
    });
  }
}