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

  static const _tabTitles = ['الرئيسية', 'المتابعة الحية', 'الشكاوى', 'السائقون', 'المطاعم'];

  /// عناوين لوحة الدعم المنكمشة — تبويبان لا خمسة.
  static const _supportTabTitles = ['المتابعة الحية', 'الشكاوى'];

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
              tooltip: 'سجلّ الطلبات',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _DrawerScreen(
                        title: 'سجلّ الطلبات',
                        child: AdminOrdersArchiveScreen())),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // تأكيد قبل الخروج (موحّد مع بقيّة النكهات): لمسةٌ خاطئة على
              // أيقونة الخروج كانت تُنهي جلسة المدير بلا سؤال.
              final ok = await showConfirmDialog(context,
                  title: 'تسجيل الخروج',
                  content: 'هل تريد تسجيل الخروج من لوحة الإدارة؟',
                  confirmLabel: 'خروج',
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
                  Text(isSupport ? 'موظف دعم' : 'إدارة إضافية',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            // الدرج مقسَّمٌ إلى مجموعات دلاليّة (§٧): كان قائمةً مسطّحة من ١٨
            // وجهة بترتيبٍ متناقض (تغيير كلمة المرور وسط طلبات الانضمام،
            // والمال مبعثرٌ بين التسويق). الأقسام تجعل المدير يجد وجهته بالمعنى
            // لا بالمسح البصري لكل السطور.

            // — السجلّات والمتابعة — (سجلّ الطلبات يظهر للدعم أيضاً)
            const _DrawerSection('السجلّات'),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('سجلّ الطلبات'),
              subtitle: const Text('كل الطلبات — بحث وفلترة',
                  style: TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const _DrawerScreen(
                            title: 'سجلّ الطلبات',
                            child: AdminOrdersArchiveScreen())));
              },
            ),
            // بقية الدرج إدارةٌ خالصة (مال وصلاحيات وبثّ) — تُطوى عن
            // الدعم؛ ولو ظهرت له لرفضتها القواعد طلباً طلباً.
            if (!isSupport) ...[
            // سجلّ الإدارة للمدير وحده (لا الدعم — والقاعدة تمنعه list):
            // من فعل ماذا ومتى, من الجوّال أو الويب.
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('سجلّ الإدارة'),
              subtitle: const Text('كل فعلٍ إداري حسّاس — من فعله ومتى',
                  style: TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const _DrawerScreen(
                            title: 'سجلّ الإدارة', child: AdminAuditScreen())));
              },
            ),

            // — المال —
            const _DrawerSection('المال'),
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
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('الحوافز والإحالات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'الحوافز والإحالات', child: AdminIncentivesScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_offer_outlined),
              title: const Text('أكواد الخصم'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'أكواد الخصم', child: AdminCouponsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('طلبات سحب السائقين'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'طلبات سحب السائقين', child: AdminPayoutRequestsScreen())));
              },
            ),

            // — المستخدمون والانضمام —
            const _DrawerSection('المستخدمون والانضمام'),
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
              leading: const Icon(Icons.assignment_ind_outlined),
              title: const Text('طلبات انضمام الكباتن'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'طلبات انضمام الكباتن', child: AdminDriverApplicationsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('طلبات انضمام المطاعم'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'طلبات انضمام المطاعم', child: AdminRestaurantApplicationsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: const Text('طلبات المطاعم'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'طلبات المطاعم — خريطة مبيعاتك', child: AdminRestaurantRequestsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: const Text('أكواد التسجيل'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'أكواد التسجيل', child: AdminRegistrationCodesScreen())));
              },
            ),
            // مشغّلو الأسطول (دفعة «ابدأ المشغل»): ملفاتهم ونسبهم وإسناد كباتنهم.
            ListTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: const Text('مشغّلو الأسطول'),
              subtitle: const Text('النسب وإسناد الكباتن والدفعات',
                  style: TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const _DrawerScreen(
                            title: 'مشغّلو الأسطول',
                            child: AdminOperatorsScreen())));
              },
            ),

            // — التسويق والتواصل —
            const _DrawerSection('التسويق والتواصل'),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('الإعلانات ✨'),
              subtitle: const Text('توليد نصوص إعلانية جاهزة للنشر',
                  style: TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const _DrawerScreen(
                            title: 'الإعلانات', child: AdminAdsScreen())));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('البنرات الترويجية'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _DrawerScreen(title: 'البنرات الترويجية', child: AdminBannersScreen())));
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
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('اقتراحات ونصائح'),
              subtitle: const Text('صوت الزوّار والمستخدمين',
                  style: TextStyle(fontSize: 11.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const _DrawerScreen(
                            title: 'اقتراحات ونصائح',
                            child: AdminSuggestionsScreen())));
              },
            ),

            // — النظام —
            const _DrawerSection('النظام'),
            // تبديل اللغة (دفعة «اللغة الثانية»): عربية ↔ إنجليزية.
            const LanguageToggleTile(),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('تغيير كلمة المرور'),
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
              title: const Text('التشخيص'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const _DrawerScreen(
                            title: 'التشخيص',
                            child: AdminDiagnosticsScreen())));
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
            ? const [
                NavigationDestination(
                    icon: Icon(Icons.gps_fixed_outlined),
                    label: 'المتابعة الحية'),
                NavigationDestination(
                    icon: Icon(Icons.report_problem_outlined),
                    label: 'الشكاوى'),
              ]
            : const [
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
          for (final (label, days) in [('اليوم', 0), ('٧ أيام', 7), ('الكل', null)])
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
            const Text('إيرادات الطلبات المكتملة',
                style: TextStyle(color: Colors.white70, fontSize: 13.5)),
            Text(formatCurrency(revenue),
                style: const TextStyle(
                    color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24, height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _moneyCol('دخل المنصة', platformIncome),
              _moneyCol('صافي المطاعم', restaurantsNet),
              _moneyCol('منها ضريبة', Pricing.vatIncludedIn(revenue)),
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
                return const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                      'حدّد «نقطة التعادل اليومية» من شاشة الحوافز ليظهر '
                      'قياس يومك عليها هنا.',
                      style:
                          TextStyle(fontSize: 11.5, color: AppColors.textGray)),
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
                    const Text('نقطة التعادل اليومية',
                        style: TextStyle(
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
                          ? 'بلغتَ التعادل اليوم — كل طلب بعده ربح صافٍ ✓'
                          : 'تبقّى ${target - done} طلباً مكتملاً لبلوغ التعادل',
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
              const Row(children: [
                Icon(Icons.notification_important_rounded,
                    color: AppColors.error, size: 18),
                SizedBox(width: 6),
                Text('يتطلب تدخلاً الآن',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.error)),
              ]),
              const SizedBox(height: 6),
              if (lateOrders.isNotEmpty)
                Text('• ${lateOrders.length} طلب نشط تجاوز ${_lateThreshold.inMinutes} دقيقة '
                    '(أقدمها #${lateOrders.first.orderNumber})',
                    style: const TextStyle(fontSize: 12.5)),
              if (driverless > 0)
                Text('• $driverless طلب بلا سائق',
                    style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 4),
              const Text('تفاصيلها في تبويب «المتابعة الحية»',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
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
                      Text('ردود محفظة معلّقة (${pending.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning)),
                    ]),
                    const SizedBox(height: 4),
                    const Text(
                        'عملاء ألغوا طلبات دفعوها من محافظهم — الردّ بضغطتك '
                        'أنت (العميل لا يستطيع ردّ رصيده بنفسه).',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                    const SizedBox(height: 6),
                    for (final o in pending.take(5))
                      Row(children: [
                        Expanded(
                          child: Text(
                              '#${o.orderNumber} — ${o.customerName}: '
                              '${o.walletUsed.toStringAsFixed(0)} ر.س',
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                        TextButton(
                          onPressed: () async {
                            await context
                                .read<FirebaseService>()
                                .settlePendingWalletRefund(o);
                            if (ctx.mounted) {
                              showSuccess(ctx,
                                  'رُدّ الرصيد لمحفظة ${o.customerName}');
                            }
                          },
                          child: const Text('ردّ الرصيد',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ]),
                    if (pending.length > 5)
                      Text('و${pending.length - 5} أخرى…',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textGray)),
                  ]),
            );
          },
        ),

        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
          _stat('الطلبات', '${orders.length}', Icons.receipt_long_outlined, fc.primary),
          _stat('النشطة', '$active', Icons.hourglass_empty, AppColors.warning),
          _stat('مكتملة', '${deliveredOrders.length}', Icons.done_all, AppColors.success),
          _stat('ملغاة/مرفوضة', '$cancelled', Icons.cancel_outlined, AppColors.error),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const _DrawerScreen(
                  title: 'التقارير المالية', child: AdminReportsTab()))),
          icon: const Icon(Icons.insights_outlined, size: 18),
          label: const Text('التقرير المالي الكامل (رسوم وأكثر الأصناف مبيعاً)'),
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
                  builder: (_) => const _DrawerScreen(
                      title: 'طلبات انضمام الكباتن',
                      child: AdminDriverApplicationsScreen()))),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  const Icon(Icons.pending_actions_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$pending كابتن بانتظار اعتمادك',
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
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold,
                      color: owes ? AppColors.error : AppColors.success)),
            StatusBadge(label: d.isOnline ? 'متصل' : 'غير متصل', color: d.isOnline ? AppColors.success : Colors.grey),
          ]),
        ));
      });
    })),
    ]);
  }
}