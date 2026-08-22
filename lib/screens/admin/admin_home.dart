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
import 'admin_operators_screen.dart';
import 'admin_audit_screen.dart';
import 'admin_suggestions_screen.dart';
import 'order_tracking_tab.dart';
import 'broadcast_tab.dart';
import 'admin_complaints_screen.dart';
import 'admin_reports_tab.dart';
import 'admin_orders_archive_screen.dart';
import 'admin_driver_ledger_screen.dart';
import 'admin_ads_screen.dart';
import 'admin_banners_screen.dart';
import 'admin_payout_requests_screen.dart';
import 'admin_coupons_screen.dart';
import 'admin_incentives_screen.dart';
import 'admin_driver_applications_screen.dart';
import 'admin_restaurant_applications_screen.dart';
import '../auth/change_password_screen.dart';
import 'admin_registration_codes_screen.dart';
import 'admin_restaurant_requests_screen.dart';
import 'admin_diagnostics_screen.dart';
import '../../utils/app_lang.dart';

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

  static List<String> get _tabTitles => [
        tr('الرئيسية', 'Home'),
        tr('المتابعة الحية', 'Live tracking'),
        tr('الشكاوى', 'Complaints'),
        tr('السائقون', 'Drivers'),
        tr('المطاعم', 'Restaurants'),
      ];

  /// عناوين لوحة الدعم المنكمشة — تبويبان لا خمسة.
  static List<String> get _supportTabTitles =>
      [tr('المتابعة الحية', 'Live tracking'), tr('الشكاوى', 'Complaints')];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    // لوحة الدعم لوحةُ الإدارة نفسها منكمشةً: تبويبا الشكاوى والمتابعة
    // فقط، ودرجٌ فيه سجلّ الطلبات وحده. هذا **تجميلٌ للواجهة لا حماية**
    // — الحماية في قواعد Firestore التي تحصر الدعم في القراءة والشكاوى؛
    // فلو أظهرنا له شاشة مالية لعادت طلباتها كلها مرفوضة من القاعدة.
    final isSupport = auth.user?.role == UserRole.support;
    final titles = isSupport ? _supportTabTitles : _tabTitles;
    if (_tab >= titles.length) _tab = 0;
    return Scaffold(
      appBar: AppBar(
        title: Text('${titles[_tab]} — ${auth.user?.name ?? ""}'),
        actions: [
          // مدخل السجلّ من «المتابعة الحية» نفسها: هناك يقف المدير حين
          // يختفي الطلب الملغى من أمامه، فيجد السجلّ في مكان بحثه لا في
          // الدرج وحده.
          if (_tab == (isSupport ? 0 : 1))
            IconButton(
              tooltip: tr('سجلّ الطلبات', 'Order history'),
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => _DrawerScreen(
                        title: tr('سجلّ الطلبات', 'Order history'),
                        child: const AdminOrdersArchiveScreen())),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // تأكيد قبل الخروج (موحّد مع بقيّة النكهات): لمسةٌ خاطئة على
              // أيقونة الخروج كانت تُنهي جلسة المدير بلا سؤال.
              final ok = await showConfirmDialog(context,
                  title: tr('تسجيل الخروج', 'Log out'),
                  content: tr('هل تريد تسجيل الخروج من لوحة الإدارة؟',
                      'Log out of the admin dashboard?'),
                  confirmLabel: tr('خروج', 'Log out'),
                  confirmColor: AppColors.error);
              if (ok != true || !mounted) return;
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.flavorColors.primary, context.flavorColors.primaryDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  Text(auth.user?.name ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  Text(
                      isSupport
                          ? tr('موظف دعم', 'Support agent')
                          : tr('إدارة إضافية', 'Additional admin'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            // الدرج مقسَّمٌ إلى مجموعات دلاليّة (§٧): كان قائمةً مسطّحة من ١٨
            // وجهة بترتيبٍ متناقض (تغيير كلمة المرور وسط طلبات الانضمام،
            // والمال مبعثرٌ بين التسويق). الأقسام تجعل المدير يجد وجهته بالمعنى
            // لا بالمسح البصري لكل السطور.

            // — السجلّات والمتابعة — (سجلّ الطلبات يظهر للدعم أيضاً)
            _DrawerSection(tr('السجلّات', 'Logs')),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(tr('سجلّ الطلبات', 'Order history')),
              subtitle: Text(
                  tr('كل الطلبات — بحث وفلترة', 'All orders — search and filter'),
                  style: const TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _DrawerScreen(
                            title: tr('سجلّ الطلبات', 'Order history'),
                            child: const AdminOrdersArchiveScreen())));
              },
            ),
            // بقية الدرج إدارةٌ خالصة (مال وصلاحيات وبثّ) — تُطوى عن
            // الدعم؛ ولو ظهرت له لرفضتها القواعد طلباً طلباً.
            if (!isSupport) ...[
            // سجلّ الإدارة للمدير وحده (لا الدعم — والقاعدة تمنعه list):
            // من فعل ماذا ومتى, من الجوّال أو الويب.
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: Text(tr('سجلّ الإدارة', 'Admin log')),
              subtitle: Text(
                  tr('كل فعلٍ إداري حسّاس — من فعله ومتى',
                      'Every sensitive admin action — who and when'),
                  style: const TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _DrawerScreen(
                            title: tr('سجلّ الإدارة', 'Admin log'),
                            child: const AdminAuditScreen())));
              },
            ),

            // — المال —
            _DrawerSection(tr('المال', 'Money')),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: Text(tr('التقارير المالية', 'Financial reports')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('التقارير المالية', 'Financial reports'), child: const AdminReportsTab())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(tr('الحوافز والإحالات', 'Incentives & referrals')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('الحوافز والإحالات', 'Incentives & referrals'), child: const AdminIncentivesScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_offer_outlined),
              title: Text(tr('أكواد الخصم', 'Coupon codes')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('أكواد الخصم', 'Coupon codes'), child: const AdminCouponsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: Text(tr('طلبات سحب السائقين', 'Driver payout requests')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('طلبات سحب السائقين', 'Driver payout requests'), child: const AdminPayoutRequestsScreen())));
              },
            ),

            // — المستخدمون والانضمام —
            _DrawerSection(tr('المستخدمون والانضمام', 'Users & onboarding')),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(tr('المستخدمون', 'Users')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('المستخدمون', 'Users'), child: const AdminUsersTab())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_ind_outlined),
              title: Text(tr('طلبات انضمام الكباتن', 'Captain applications')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('طلبات انضمام الكباتن', 'Captain applications'), child: const AdminDriverApplicationsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(tr('طلبات انضمام المطاعم', 'Restaurant applications')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('طلبات انضمام المطاعم', 'Restaurant applications'), child: const AdminRestaurantApplicationsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: Text(tr('طلبات المطاعم', 'Restaurant requests')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('طلبات المطاعم — خريطة مبيعاتك', 'Restaurant requests — your sales map'), child: const AdminRestaurantRequestsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: Text(tr('أكواد التسجيل', 'Registration codes')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('أكواد التسجيل', 'Registration codes'), child: const AdminRegistrationCodesScreen())));
              },
            ),
            // مشغّلو الأسطول (دفعة «ابدأ المشغل»): ملفاتهم ونسبهم وإسناد كباتنهم.
            ListTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: Text(tr('مشغّلو الأسطول', 'Fleet operators')),
              subtitle: Text(
                  tr('النسب وإسناد الكباتن والدفعات',
                      'Shares, captain assignment, and payouts'),
                  style: const TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _DrawerScreen(
                            title: tr('مشغّلو الأسطول', 'Fleet operators'),
                            child: const AdminOperatorsScreen())));
              },
            ),

            // — التسويق والتواصل —
            _DrawerSection(tr('التسويق والتواصل', 'Marketing & outreach')),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(tr('الإعلانات ✨', 'Ads ✨')),
              subtitle: Text(
                  tr('توليد نصوص إعلانية جاهزة للنشر',
                      'Generate ready-to-post ad copy'),
                  style: const TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _DrawerScreen(
                            title: tr('الإعلانات', 'Ads'),
                            child: const AdminAdsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('البنرات الترويجية', 'Promo banners')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('البنرات الترويجية', 'Promo banners'), child: const AdminBannersScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: Text(tr('بث جماعي', 'Broadcast')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _DrawerScreen(title: tr('بث جماعي', 'Broadcast'), child: const BroadcastTab())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(tr('اقتراحات ونصائح', 'Suggestions & tips')),
              subtitle: Text(
                  tr('صوت الزوّار والمستخدمين', 'The voice of visitors and users'),
                  style: const TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _DrawerScreen(
                            title: tr('اقتراحات ونصائح', 'Suggestions & tips'),
                            child: const AdminSuggestionsScreen())));
              },
            ),

            // — النظام —
            _DrawerSection(tr('النظام', 'System')),
            // تبديل اللغة (دفعة «اللغة الثانية»): عربية ↔ إنجليزية.
            const LanguageToggleTile(),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(tr('تغيير كلمة المرور', 'Change password')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
              },
            ),
            // التشخيص آخر القائمة عمداً: لا يُفتح في التشغيل العادي، بل
            // عند وقوع عطل — فمكانه بعيدٌ عن أزرار العمل اليومي.
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: Text(tr('التشخيص', 'Diagnostics')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _DrawerScreen(
                            title: tr('التشخيص', 'Diagnostics'),
                            child: const AdminDiagnosticsScreen())));
              },
            ),
            ],
          ],
        ),
      ),
      body: IndexedStack(
          index: _tab,
          children: isSupport
              ? const [OrderTrackingTab(), AdminComplaintsScreen()]
              : const [
                  _StatsTab(),
                  OrderTrackingTab(),
                  AdminComplaintsScreen(),
                  _DriversTab(),
                  AdminRestaurantsTab(),
                ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: isSupport
            ? [
                NavigationDestination(
                    icon: const Icon(Icons.gps_fixed_outlined),
                    label: tr('المتابعة الحية', 'Live tracking')),
                NavigationDestination(
                    icon: const Icon(Icons.report_problem_outlined),
                    label: tr('الشكاوى', 'Complaints')),
              ]
            : [
                NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: tr('الرئيسية', 'Home')),
                NavigationDestination(icon: const Icon(Icons.gps_fixed_outlined), label: tr('المتابعة الحية', 'Live tracking')),
                NavigationDestination(icon: const Icon(Icons.report_problem_outlined), label: tr('الشكاوى', 'Complaints')),
                NavigationDestination(icon: const Icon(Icons.delivery_dining_outlined), label: tr('السائقون', 'Drivers')),
                NavigationDestination(icon: const Icon(Icons.restaurant_outlined), label: tr('المطاعم', 'Restaurants')),
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

/// عنوان قسمٍ في درج الإدارة — يجمع الوجهات الثماني عشرة تحت مجموعاتٍ
/// دلاليّة (مال/مستخدمون/تسويق/نظام) بدل قائمةٍ مسطّحة متناقضة الترتيب
/// دُفن فيها «تغيير كلمة المرور» وسط طلبات الانضمام.
class _DrawerSection extends StatelessWidget {
  final String title;
  const _DrawerSection(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: context.flavorColors.primary)),
      );
}

/// الرئيسية كتقرير تشغيلي متكامل لا أرقام تراكمية مجردة: فترة قابلة
/// للتبديل (اليوم/الأسبوع/الكل)، تفصيل مالي (إيرادات، عمولات المنصة، صافي
/// المطاعم)، تنبيهات تتطلب تدخلاً الآن (متأخرة/بلا سائق/شكاوى مفتوحة)،
/// ومدخل مباشر للتقارير المالية الكاملة.
class _StatsTab extends StatefulWidget {
  const _StatsTab();
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  /// 0 = اليوم، 7 = آخر ٧ أيام، null = الكل.
  int? _periodDays = 0;

  /// الطلب النشط «المتأخر»: مضى عليه أكثر من هذه المدة ولم يُغلق.
  static const Duration _lateThreshold = Duration(minutes: 45);

  bool _inPeriod(Order o) {
    final days = _periodDays;
    if (days == null) return true;
    final now = DateTime.now();
    if (days == 0) {
      final startOfDay = DateTime(now.year, now.month, now.day);
      return o.createdAt.isAfter(startOfDay);
    }
    return o.createdAt.isAfter(now.subtract(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final fc = context.flavorColors;
    // تدفقان مقصودان لا واحد: التنبيهات (متأخر/بلا سائق) تقرأ **النشط
    // كله** دائماً — طلبٌ عالق من أمس أولى بالظهور لا أن تخفيه فلترة
    // «اليوم». والمالُ والعدّادات تقرأ **مدى الفترة كاملاً** من القاعدة
    // بدل الفلترة بعد نافذة الـ٥٠٠ التي كانت تقصّ الأرقام بصمت.
    return AppStreamBuilder<List<Order>>(
        stream: service.streamActiveOrders,
        builder: (ctxA, activeAll) {
      final nowA = DateTime.now();
      final lateOrders = activeAll
          .where((o) =>
              o.status.isActive &&
              nowA.difference(o.createdAt) > _lateThreshold)
          .toList();
      final driverless = activeAll
          .where((o) =>
              (o.status == OrderStatus.searchingDriver ||
                  o.status == OrderStatus.noDriverFound) &&
              (o.driverId == null || o.driverId!.isEmpty))
          .length;

      return AppStreamBuilder<List<Order>>(
        key: ValueKey(_periodDays),
        stream: () {
          final days = _periodDays;
          if (days == null) return service.streamAllOrders();
          final now = DateTime.now();
          final since = days == 0
              ? DateTime(now.year, now.month, now.day)
              : now.subtract(Duration(days: days));
          return service.streamOrdersSince(since);
        },
        builder: (ctx, allOrders) {
      final windowCapped = _periodDays == null && allOrders.length >= 500;
      final orders = allOrders.where(_inPeriod).toList();
      final deliveredOrders =
          orders.where((o) => o.status == OrderStatus.delivered).toList();
      final active = orders.where((o) => o.status.isActive).length;
      final cancelled = orders
          .where((o) =>
              o.status == OrderStatus.cancelled ||
              o.status == OrderStatus.restaurantRejected)
          .length;

      // المال — بنفس قواعد التسعير المعتمدة: ما دفعه العميل فعلاً (بعد خصم
      // الكوبون)، ودخل المنصة (15% من الوجبات + الرسم الثابت − الخصومات
      // التي موّلتها)، وصافي المطاعم بعد العمولة.
      final revenue = deliveredOrders.fold(0.0, (s, o) => s + o.payableTotal);
      final platformIncome =
          deliveredOrders.fold(0.0, (s, o) => s + o.platformNet);
      final restaurantsNet =
          deliveredOrders.fold(0.0, (s, o) => s + o.restaurantNet);

      return ListView(padding: const EdgeInsets.all(16), children: [
        // مبدّل الفترة
        Row(children: [
          for (final (label, days) in [
            (tr('اليوم', 'Today'), 0),
            (tr('٧ أيام', '7 days'), 7),
            (tr('الكل', 'All'), null)
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _periodDays == days,
                selectedColor: fc.primary,
                labelStyle: TextStyle(
                    color: _periodDays == days ? fc.onPrimary : AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5),
                onSelected: (_) => setState(() => _periodDays = days),
              ),
            ),
        ]),
        const SizedBox(height: 10),

        // البطاقة المالية المتكاملة
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [fc.primary, fc.primaryDark]),
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('إيرادات الطلبات المكتملة', 'Completed-order revenue'),
                style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
            Text(formatCurrency(revenue),
                style: const TextStyle(
                    color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24, height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _moneyCol(tr('دخل المنصة', 'Platform income'), platformIncome),
              _moneyCol(tr('صافي المطاعم', 'Restaurants net'), restaurantsNet),
              _moneyCol(tr('منها ضريبة', 'Incl. VAT'),
                  Pricing.vatIncludedIn(revenue)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // صدق نافذة «الكل»: أرقامها من أحدث ٥٠٠ طلب لا التاريخ كله —
        // يُصارَح المدير بذلك بدل عناوين تدّعي الكمال.
        if (windowCapped)
          const WindowCapNotice(margin: EdgeInsets.only(bottom: 12)),

        // بطاقة نقطة التعادل — «الطلبات المكتملة اليوم مقابل التعادل»:
        // الرقم الوحيد الذي أوصت الدراسة المالية بمراقبته ولم تعرضه أي
        // شاشة. تظهر في عرض «اليوم» وحده (مصدرها طلبات اليوم كاملةً من
        // الاستعلام الزمني)، والهدف يضبطه المدير من شاشة الحوافز (ج١):
        // صفر يخفيها ويُظهر تلميح الضبط بدلها.
        if (_periodDays == 0)
          AppStreamBuilder<IncentiveSettings>(
            stream: service.streamIncentiveSettings,
            loading: const SizedBox.shrink(),
            builder: (ctxT, settings) {
              final target = settings.dailyOrdersTarget;
              if (target <= 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                      tr('حدّد «نقطة التعادل اليومية» من شاشة الحوافز ليظهر '
                              'قياس يومك عليها هنا.',
                          'Set the "daily break-even" from the incentives screen '
                              'to see today measured against it here.'),
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textGray)),
                );
              }
              final done = deliveredOrders.length;
              final reached = done >= target;
              final color = reached ? AppColors.success : fc.primary;
              return Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.35)),
                ),
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(reached ? Icons.flag_rounded : Icons.flag_outlined,
                        color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(tr('نقطة التعادل اليومية', 'Daily break-even'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.5)),
                    const Spacer(),
                    Text('$done / $target',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: color)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (done / target).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                      reached
                          ? tr('بلغتَ التعادل اليوم — كل طلب بعده ربح صافٍ ✓',
                              'Break-even reached today — every order from here is net profit ✓')
                          : tr('تبقّى ${target - done} طلباً مكتملاً لبلوغ التعادل',
                              '${target - done} more completed orders to break even'),
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textGray)),
                ]),
              );
            },
          ),

        // تنبيهات تشغيلية — تظهر فقط حين يوجد ما يستحق التدخل
        if (lateOrders.isNotEmpty || driverless > 0)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.notification_important_rounded,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 6),
                Text(tr('يتطلب تدخلاً الآن', 'Needs action now'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.error)),
              ]),
              const SizedBox(height: 6),
              if (lateOrders.isNotEmpty)
                Text(
                    tr('• ${lateOrders.length} طلب نشط تجاوز ${_lateThreshold.inMinutes} دقيقة '
                            '(أقدمها #${lateOrders.first.orderNumber})',
                        '• ${lateOrders.length} active orders past ${_lateThreshold.inMinutes} min '
                            '(oldest #${lateOrders.first.orderNumber})'),
                    style: const TextStyle(fontSize: 12.5)),
              if (driverless > 0)
                Text(
                    tr('• $driverless طلب بلا سائق',
                        '• $driverless orders with no driver'),
                    style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 4),
              Text(
                  tr('تفاصيلها في تبويب «المتابعة الحية»',
                      'Details in the "Live tracking" tab'),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textGray)),
            ]),
          ),

        // ردود محافظ الإلغاء الذاتي المعلّقة (مراجعة 2026-08-15): القواعد
        // تمنع العميل من ردّ رصيده بنفسه — بحق — فيُختم طلبه الملغى بعلمٍ
        // يظهر هنا ليصرفه المدير بضغطة. البطاقة تختفي حين لا معلّق.
        StreamBuilder<List<Order>>(
          stream:
              context.read<FirebaseService>().streamWalletRefundsPending(),
          builder: (ctx, snap) {
            final pending = snap.data ?? const <Order>[];
            if (pending.isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 6),
                      Text(
                          tr('ردود محفظة معلّقة (${pending.length})',
                              'Pending wallet refunds (${pending.length})'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                        tr('عملاء ألغوا طلبات دفعوها من محافظهم — الردّ بضغطتك '
                                'أنت (العميل لا يستطيع ردّ رصيده بنفسه).',
                            'Customers cancelled orders paid from their wallets — '
                                "the refund takes your tap (they can't refund "
                                'themselves).'),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                    const SizedBox(height: 6),
                    for (final o in pending.take(5))
                      Row(children: [
                        Expanded(
                          child: Text(
                              tr('#${o.orderNumber} — ${o.customerName}: '
                                      '${o.walletUsed.toStringAsFixed(0)} ر.س',
                                  '#${o.orderNumber} — ${o.customerName}: '
                                      '${o.walletUsed.toStringAsFixed(0)} SAR'),
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                        TextButton(
                          onPressed: () async {
                            await context
                                .read<FirebaseService>()
                                .settlePendingWalletRefund(o);
                            if (ctx.mounted) {
                              showSuccess(
                                  ctx,
                                  tr('رُدّ الرصيد لمحفظة ${o.customerName}',
                                      "Balance refunded to ${o.customerName}'s wallet"));
                            }
                          },
                          child: Text(tr('ردّ الرصيد', 'Refund'),
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                      ]),
                    if (pending.length > 5)
                      Text(
                          tr('و${pending.length - 5} أخرى…',
                              'and ${pending.length - 5} more…'),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textGray)),
                  ]),
            );
          },
        ),

        // ردود البطاقة المعلّقة (تحصين ح٧ 2026-08-22): شحن البطاقة قبضٌ
        // نهائي وقع قبل إنشاء الطلب، فإلغاؤه دون خادمٍ يستلزم طابوراً
        // يدوياً: تستردّ من لوحة ميسر برقم الدفعة ثم تختم هنا «استُردّ».
        StreamBuilder<List<Order>>(
          stream: context.read<FirebaseService>().streamCardRefundsPending(),
          builder: (ctx, snap) {
            final pending = snap.data ?? const <Order>[];
            if (pending.isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.35)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.credit_card_off_outlined,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 6),
                      Text(
                          tr('ردود بطاقة معلّقة (${pending.length})',
                              'Pending card refunds (${pending.length})'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.error)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                        tr('طلبات بطاقة أُلغيت بعد الدفع — استردّ المبلغ من '
                                'لوحة ميسر برقم الدفعة ثم اختم «استُردّ».',
                            'Card orders cancelled after payment — refund from '
                                'the Moyasar dashboard by payment id, then mark '
                                'as refunded.'),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                    const SizedBox(height: 6),
                    for (final o in pending.take(5))
                      Row(children: [
                        Expanded(
                          child: Text(
                              tr('#${o.orderNumber} — ${o.customerName} · دفعة ${o.paymentId ?? ''}',
                                  '#${o.orderNumber} — ${o.customerName} · payment ${o.paymentId ?? ''}'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                        TextButton(
                          onPressed: () async {
                            final ok = await showConfirmDialog(context,
                                title: tr('ختم الاسترداد', 'Mark refunded'),
                                content: tr(
                                    'هل نفّذت استرداد الطلب #${o.orderNumber} من لوحة ميسر فعلاً؟ الختم لا يحوّل مالاً — يوثّق ما نفّذته.',
                                    'Did you actually refund order #${o.orderNumber} from the Moyasar dashboard? This mark documents it — it moves no money.'));
                            if (ok != true || !context.mounted) return;
                            await context
                                .read<FirebaseService>()
                                .settlePendingCardRefund(o);
                            if (ctx.mounted) {
                              showSuccess(ctx,
                                  tr('خُتم الاسترداد', 'Marked as refunded'));
                            }
                          },
                          child: Text(tr('استُردّ ✓', 'Refunded ✓'),
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                      ]),
                    if (pending.length > 5)
                      Text(
                          tr('و${pending.length - 5} أخرى…',
                              'and ${pending.length - 5} more…'),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textGray)),
                  ]),
            );
          },
        ),

        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
          _stat(tr('الطلبات', 'Orders'), '${orders.length}', Icons.receipt_long_outlined, fc.primary),
          _stat(tr('النشطة', 'Active'), '$active', Icons.hourglass_empty, AppColors.warning),
          _stat(tr('مكتملة', 'Completed'), '${deliveredOrders.length}', Icons.done_all, AppColors.success),
          _stat(tr('ملغاة/مرفوضة', 'Cancelled/rejected'), '$cancelled', Icons.cancel_outlined, AppColors.error),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _DrawerScreen(
                  title: tr('التقارير المالية', 'Financial reports'),
                  child: const AdminReportsTab()))),
          icon: const Icon(Icons.insights_outlined, size: 18),
          label: Text(tr('التقرير المالي الكامل (رسوم وأكثر الأصناف مبيعاً)',
              'Full financial report (charts & best sellers)')),
        ),
      ]);
    });
    });
  }

  Widget _moneyCol(String label, double value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          Text(formatCurrency(value),
              style: const TextStyle(
                  color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _stat(String l, String v, IconData i, Color c) => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(i, color: c, size: 28), Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
      Text(l, style: const TextStyle(fontSize: 12.5)),
    ])));
}

class _DriversTab extends StatelessWidget {
  const _DriversTab();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Column(children: [
      // طلبات الانضمام المعلّقة تظهر هنا — حيث يعمل المدير يومياً — لا في
      // شاشة درجٍ عليه تذكّرها (درس لقطات تكسي طيبة 2026-08-18: الاعتماد
      // في متناول اليد). اللافتة تظهر فقط حين يوجد معلّق، وتفتح المراجعة.
      StreamBuilder<List<DriverApplication>>(
        stream: service.streamDriverApplications(),
        builder: (c, snap) {
          final pending = (snap.data ?? const <DriverApplication>[])
              .where((a) => a.status == DriverApplicationStatus.pending)
              .length;
          if (pending == 0) return const SizedBox.shrink();
          return Material(
            color: AppColors.warning.withOpacity(0.12),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _DrawerScreen(
                      title: tr('طلبات انضمام الكباتن', 'Captain applications'),
                      child: const AdminDriverApplicationsScreen()))),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  const Icon(Icons.pending_actions_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        tr('$pending كابتن بانتظار اعتمادك',
                            '$pending captains awaiting your approval'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                  const Icon(Icons.chevron_left_rounded, size: 20),
                ]),
              ),
            ),
          );
        },
      ),
      Expanded(child: AppStreamBuilder<List<Driver>>(stream: service.streamDrivers, builder: (ctx, list) {
      if (list.isEmpty) {
        return AppEmpty(emoji: '🛵', title: tr('لا يوجد سائقون', 'No drivers'));
      }
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
          // ت٣: شارة الموقع المُحاكى بجوار الإنذارات — نيّة غشٍّ مثبتة
          // تقنياً تستحق أن تُرى قبل أن تتكرر، والقرار للمدير.
          subtitle: Text(tr(
              '${d.totalDeliveries} توصيلة  •  ${d.rating.toStringAsFixed(1)} ⭐'
                  '${d.warningCount > 0 ? '  •  ⚠️ ${d.warningCount} إنذار' : ''}'
                  '${d.mockLocationCount > 0 ? '  •  🛰️ ${d.mockLocationCount} موقع وهمي' : ''}',
              '${d.totalDeliveries} deliveries  •  ${d.rating.toStringAsFixed(1)} ⭐'
                  '${d.warningCount > 0 ? '  •  ⚠️ ${d.warningCount} warnings' : ''}'
                  '${d.mockLocationCount > 0 ? '  •  🛰️ ${d.mockLocationCount} mocked GPS' : ''}')),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (d.balance != 0)
              Text(
                  tr('${owes ? 'عليه ' : 'له '}${formatCurrency(d.balance.abs())}',
                      '${owes ? 'Owes ' : 'Is owed '}${formatCurrency(d.balance.abs())}'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold,
                      color: owes ? AppColors.error : AppColors.success)),
            StatusBadge(
                label: d.isOnline ? tr('متصل', 'Online') : tr('غير متصل', 'Offline'),
                color: d.isOnline ? AppColors.success : Colors.grey),
          ]),
        ));
      });
    })),
    ]);
  }
}