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
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, SystemSound, SystemSoundType;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/app_lang.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/complaint_window.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import '../customer/submit_complaint_screen.dart';
import '../customer/my_complaints_screen.dart';
import 'restaurant_reports_tab.dart';
import 'restaurant_menu_prices_tab.dart';
import 'restaurant_reviews_tab.dart';

class RestaurantHome extends StatefulWidget {
  const RestaurantHome({super.key});

  @override
  State<RestaurantHome> createState() => _RestaurantHomeState();
}

class _RestaurantHomeState extends State<RestaurantHome> {
  /// ورقة الإيقاف المؤقت: مدد جاهزة + استئناف فوري. الكتابة على مستند
  /// المطعم نفسه (القاعدة تجيزها لمديره)، والاستئناف التلقائي بانقضاء
  /// الموعد — فلا حالة «مشغول منسيّة» تُخفي المطعم إلى الأبد.
  Future<void> _showPauseSheet(BuildContext context, String restaurantId,
      {required bool paused}) async {
    final service = context.read<FirebaseService>();
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
                paused
                    ? tr('المطعم «مشغول مؤقتاً» الآن',
                        'The restaurant is set to "temporarily busy"')
                    : tr('إيقاف استقبال الطلبات مؤقتاً؟',
                        'Pause incoming orders temporarily?'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
                tr(
                    'يظهر للعملاء «مشغول مؤقتاً — يستأنف HH:MM» ويستأنف '
                        'الاستقبال وحده في الموعد. الطلبات الجارية لا تتأثر.',
                    'Customers see "Temporarily busy — resumes at HH:MM" and '
                        'orders resume automatically on time. Ongoing orders are not affected.'),
                style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in [15, 30, 60, 120])
              ActionChip(
                label: Text(m < 60
                    ? tr('$m دقيقة', '$m min')
                    : tr('${m ~/ 60} ساعة${m == 120 ? 'تان' : ''}',
                        '${m ~/ 60} hour${m == 120 ? 's' : ''}')),
                onPressed: () => Navigator.pop(sheetCtx, m),
              ),
            if (paused)
              ActionChip(
                avatar: const Icon(Icons.play_arrow_rounded,
                    size: 18, color: AppColors.success),
                label: Text(tr('استئناف الآن', 'Resume now')),
                onPressed: () => Navigator.pop(sheetCtx, 0),
              ),
          ]),
          const SizedBox(height: 14),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      await service.setRestaurantPaused(
          restaurantId,
          choice == 0
              ? null
              : DateTime.now().add(Duration(minutes: choice)));
      if (mounted) {
        showSuccess(
            context,
            choice == 0
                ? tr('استؤنف الاستقبال — أهلاً بالطلبات',
                    'Orders resumed — welcome back')
                : tr('أوقف الاستقبال $choice دقيقة ويستأنف وحده',
                    'Orders paused for $choice min — resumes automatically'));
      }
    } catch (_) {
      if (mounted) {
        showError(
            context, tr('تعذّر التغيير — حاول مجدداً', 'Change failed — try again'));
      }
    }
  }

  int _tab = 0;

  Set<String> _knownPendingIds = {};
  bool _firstSnapshot = true;
  int _newOrdersBadgeCount = 0;
  OverlayEntry? _bannerEntry;
  Timer? _alarmTimer;

  @override
  void initState() {
    super.initState();
    // جهاز المطعم «شاشة طلبات» تعمل طوال الدوام: تبقى الشاشة مضاءة ما دام
    // التطبيق مفتوحاً، فلا يفوّت المطعم طلباً لأن الجهاز أطفأ شاشته —
    // وهي أكثر أسباب «لم نستلم الطلب» شيوعاً في التشغيل الفعلي.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _stopAlarm();
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

    // إن عولجت كل الطلبات المعلّقة من تبويب الطلبات مباشرةً (دون ضغط
    // الشريط)، يسكت الإنذار ويختفي الشريط من تلقاء نفسه.
    if (pendingNow.isEmpty) {
      _stopAlarm();
      _bannerEntry?.remove();
      _bannerEntry = null;
    }

    if (newlyArrived.isEmpty) return;

    setState(() => _newOrdersBadgeCount += newlyArrived.length);
    _startAlarm();
    _showNewOrderBanner(newlyArrived.length);
  }

  /// إنذار متكرّر لا خمس نغمات وتصمت: يظل يرنّ ويهتزّ كل ثانيتين حتى يضغط
  /// المدير شريط «طلب جديد» فيُقرّ باستلامه — خمس نغمات في مطبخ مشغول تمرّ
  /// دون أن يسمعها أحد، والطلب الضائع خسارة مباشرة. سقف أمان ٣ دقائق حتى
  /// لا يرنّ جهاز مهجور بلا نهاية.
  static const Duration _alarmInterval = Duration(seconds: 2);
  static const int _alarmMaxTicks = 90;

  void _startAlarm() {
    _alarmTimer?.cancel();
    var ticks = 0;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
    _alarmTimer = Timer.periodic(_alarmInterval, (t) {
      if (++ticks >= _alarmMaxTicks) {
        _stopAlarm();
        return;
      }
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
    });
  }

  void _stopAlarm() {
    _alarmTimer?.cancel();
    _alarmTimer = null;
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
              _stopAlarm();
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
              // نصٌّ ورموزٌ كحلية على الكهرماني: الأبيض على الكهرماني ~١٫٩:١،
              // وهذا أهمّ تنبيه في المطبخ (طلبٌ جديد) فيجب أن يُقرأ من بعيد —
              // الكحلي عليه ~٨:١.
              child: Row(children: [
                const Icon(Icons.notifications_active_rounded, color: AppColors.dark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    count == 1
                        ? tr('طلب جديد وصل الآن', 'New order just arrived')
                        : tr('$count طلبات جديدة وصلت الآن',
                            '$count new orders just arrived'),
                    style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, color: AppColors.dark),
              ]),
            ),
          ),
        ),
      ),
    );
    _bannerEntry = entry;
    overlay.insert(entry);
    // لا إخفاء تلقائياً سريعاً: الشريط يبقى حتى يُقرّ المدير به بالضغط أو
    // تُعالَج الطلبات المعلّقة كلها — إخفاؤه بعد ثوانٍ كان يعني أن من غاب
    // عن الشاشة دقيقة لا يرى أي أثر للطلب الفائت. سقف أمان يطابق سقف
    // الإنذار الصوتي.
    Future.delayed(_alarmInterval * _alarmMaxTicks, () {
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
          0 => tr('طلبات ${auth.user?.restaurantName ?? "المطعم"}',
              '${auth.user?.restaurantName ?? "Restaurant"} orders'),
          1 => tr('التقارير والحسابات', 'Reports & accounts'),
          2 => tr('أسعار القائمة والتوفر', 'Menu prices & availability'),
          _ => tr('التقييمات', 'Reviews'),
        }),
        actions: [
          // تبديل اللغة (دفعة «اللغة الثانية»).
          const LanguageToggleButton(),
          // الإيقاف المؤقت (يوم المطعم): مطبخ غارق يوقف الاستقبال بمدد
          // جاهزة ويستأنف وحده — بدل الإغلاق الكامل الذي يُخفيه عن
          // العملاء أو الغرقِ بطلبات لن تخرج في وقتها.
          if (restaurantId != null && restaurantId.isNotEmpty)
            StreamBuilder<Restaurant?>(
              stream: context.read<FirebaseService>().streamRestaurant(restaurantId),
              builder: (ctx, snap) {
                final r = snap.data;
                final paused = r?.isPausedNow == true;
                return IconButton(
                  tooltip: paused
                      ? tr('مشغول حتى ${r!.pausedUntil!.hour.toString().padLeft(2, '0')}:${r.pausedUntil!.minute.toString().padLeft(2, '0')} — اضغط للاستئناف/التمديد',
                          'Busy until ${r!.pausedUntil!.hour.toString().padLeft(2, '0')}:${r.pausedUntil!.minute.toString().padLeft(2, '0')} — tap to resume/extend')
                      : tr('إيقاف الاستقبال مؤقتاً', 'Pause incoming orders'),
                  icon: Icon(
                      paused
                          ? Icons.pause_circle_filled_rounded
                          : Icons.pause_circle_outline_rounded,
                      color: paused ? AppColors.warning : null),
                  onPressed: () => _showPauseSheet(context, restaurantId,
                      paused: paused),
                );
              },
            ),
          IconButton(
            tooltip: tr('تغيير كلمة المرور', 'Change password'),
            icon: const Icon(Icons.lock_outline),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen())),
          ),
          IconButton(
            tooltip: tr('الشكاوى', 'Complaints'),
            icon: const Icon(Icons.support_agent_rounded),
            onPressed: () {
              final uid = auth.user?.uid;
              if (uid == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyComplaintsScreen(
                    uid: uid,
                    role: UserRole.restaurantManager,
                    restaurantId: auth.user?.restaurantId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // تأكيد قبل الخروج (موحّد مع بقيّة النكهات): لمسةٌ خاطئة على
              // أيقونة الخروج كانت تُنهي جلسة المطعم بلا سؤال.
              final ok = await showConfirmDialog(context,
                  title: tr('تسجيل الخروج', 'Log out'),
                  content: tr('هل تريد تسجيل الخروج من حساب المطعم؟',
                      'Log out of the restaurant account?'),
                  confirmLabel: tr('خروج', 'Log out'),
                  confirmColor: AppColors.error);
              if (ok != true || !context.mounted) return;
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
          ? AppEmpty(
              emoji: '⚠️',
              title: tr('حسابك غير مرتبط بمطعم',
                  'Your account is not linked to a restaurant'),
              subtitle: tr('يرجى مراجعة إدارة المنصة لربط الحساب بمطعم.',
                  'Please contact platform admin to link your account to a restaurant.'),
            )
          : IndexedStack(index: _tab, children: [
              _RestaurantOrdersList(
                restaurantId: restaurantId,
                onOrdersChanged: _detectNewOrders,
              ),
              RestaurantReportsTab(restaurantId: restaurantId),
              RestaurantMenuPricesTab(restaurantId: restaurantId),
              RestaurantReviewsTab(restaurantId: restaurantId),
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
                  label: tr('الطلبات', 'Orders'),
                ),
                NavigationDestination(
                    icon: const Icon(Icons.bar_chart_outlined),
                    label: tr('التقارير والحسابات', 'Reports & accounts')),
                NavigationDestination(
                    icon: const Icon(Icons.sell_outlined),
                    label: tr('الأسعار', 'Prices')),
                NavigationDestination(
                    icon: const Icon(Icons.star_outline_rounded),
                    label: tr('التقييمات', 'Reviews')),
              ],
            ),
    );
  }
}

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
          labelColor: context.flavorColors.primary,
          unselectedLabelColor: AppColors.textGray,
          indicatorColor: context.flavorColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          tabs: [
            Tab(text: tr('نشطة', 'Active')),
            Tab(text: tr('منتهية', 'Completed')),
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
                emptyTitle: tr('لا يوجد طلبات نشطة حالياً',
                    'No active orders right now'),
              ),
              _OrdersListView(
                orders: finished,
                service: service,
                emptyEmoji: '📋',
                emptyTitle: tr('لا يوجد طلبات منتهية بعد',
                    'No completed orders yet'),
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

  (String, Color, IconData) get _bannerInfo {
    switch (widget.order.status) {
      case OrderStatus.restaurantPending:
        return (
          tr('طلب جديد بانتظار التأكيد', 'New order awaiting acceptance'),
          AppColors.warning,
          Icons.fiber_new_rounded
        );
      case OrderStatus.restaurantAccepted:
        return (
          tr('تم تأكيد الاستلام', 'Order accepted'),
          AppColors.primary,
          Icons.check_circle_outline_rounded
        );
      case OrderStatus.preparing:
        return (
          tr('جاري التحضير', 'Preparing'),
          AppColors.primary,
          Icons.restaurant_rounded
        );
      case OrderStatus.readyForPickup:
        // بلاغ المالك ٢٠٢٦-٠٨-١٢: البطاقة كانت تقول «بانتظار استلام
        // السائق» بينما تحتها ختمُ «سلّمتُ الطلب للسائق» — سطران
        // متناقضان ظاهرياً في بطاقة واحدة، فظنّ المالك أن الكابتن أكّد
        // استلامه من بُعد وأن حارس المئة متر انخرم.
        //
        // ولا تناقض في الحقيقة: ختمُ المطعم إقرارٌ من طرفه وحده ولا
        // يغيّر الحالة (وهذا مقصود — ضغطة المطعم لا تُثبت استلاماً لم
        // يقع)، والحالة لا تنتقل إلا بتأكيد الكابتن وهو محكومٌ بالحارس.
        // فالعلّة في **الصياغة** لا في المنطق: العنوان الآن يقول أي
        // الطرفين أقرّ وأيّهما ينتظر.
        // أخضر النجاح لا التركوازي الخام: التركوازي خارج اللوحة ويصطدم بختم
        // «سلّمته» الأخضر (success) الذي يظهر مباشرةً بعده — لونان لحالة
        // «جاهز/سُلّم» الواحدة. توحيدهما على success يجعل المسار عائلةً واحدة.
        return widget.order.restaurantHandoverAt == null
            ? (
                tr('جاهز — بانتظار استلام السائق',
                    'Ready — waiting for captain'),
                AppColors.success,
                Icons.shopping_bag_rounded
              )
            : (
                tr('سلّمته — بانتظار تأكيد الكابتن',
                    'Handed over — awaiting captain confirmation'),
                AppColors.success,
                Icons.hourglass_bottom_rounded
              );
      case OrderStatus.restaurantRejected:
        return (
          tr('تم رفض الطلب', 'Order rejected'),
          AppColors.error,
          Icons.block_rounded
        );
      case OrderStatus.searchingDriver:
      case OrderStatus.driverAssigned:
      case OrderStatus.onTheWay:
        return (
          tr('تم التسليم — جاري التوصيل', 'Handed over — out for delivery'),
          AppColors.success,
          Icons.delivery_dining_rounded
        );
      case OrderStatus.delivered:
        return (
          tr('تم التوصيل للعميل', 'Delivered to customer'),
          AppColors.success,
          Icons.done_all_rounded
        );
      default:
        return (widget.order.status.label, widget.order.status.color, Icons.info_outline_rounded);
    }
  }

  /// العمر وحده لا يكفي (بلاغ المالك ٢٠٢٦-٠٨-١١): «منذ ٤٠ د» تُخبر المطبخ
  /// كم انتظر الطلب، لكنها لا تُطابَق مع شاشة الكابتن ولا تصلح في مراجعة
  /// نزاع تأخير — فأُضيفت الساعة، والتاريخ حين يكون الطلب من يوم سابق.
  String _waitingLabel() {
    final t = widget.order.createdAt;
    final now = DateTime.now();
    final elapsed = now.difference(t);
    final String age;
    if (elapsed.inMinutes < 1) {
      age = tr('منذ لحظات', 'moments ago');
    } else if (elapsed.inMinutes < 60) {
      age = tr('منذ ${elapsed.inMinutes} د', '${elapsed.inMinutes} min ago');
    } else {
      final hours = elapsed.inHours;
      final mins = elapsed.inMinutes % 60;
      age = mins == 0
          ? tr('منذ $hours س', '$hours h ago')
          : tr('منذ $hours س $mins د', '$hours h $mins min ago');
    }
    final clock =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    final stamp = sameDay ? clock : '${t.day}/${t.month} — $clock';
    return '$stamp ($age)';
  }

  Future<void> _call(BuildContext context, String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: trimmed);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        showError(
            context,
            tr('تعذّر فتح تطبيق الاتصال على هذا الجهاز',
                'Could not open the phone app on this device'));
      }
    } catch (_) {
      if (context.mounted) {
        showError(context,
            tr('تعذّر فتح تطبيق الاتصال', 'Could not open the phone app'));
      }
    }
  }

  Future<void> _confirmAcceptance(BuildContext context) async {
    // وقت التحضير يُختار لحظة القبول (يوم المطعم 2026-08-20): توقّعٌ
    // صادق للعميل والكابتن بدل التخمين. «بدون تقدير» متاح فلا يعطّل
    // الاختيارُ مطبخاً مستعجلاً — والتراجع عن الورقة يلغي القبول كله.
    final prep = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(tr('كم يحتاج التحضير؟', 'How long to prepare?'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in [10, 15, 20, 30, 45])
                ActionChip(
                  label: Text(tr('$m دقيقة', '$m min')),
                  onPressed: () => Navigator.pop(sheetCtx, m),
                ),
              ActionChip(
                label: Text(tr('بدون تقدير', 'No estimate')),
                onPressed: () => Navigator.pop(sheetCtx, 0),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ]),
      ),
    );
    if (prep == null || !context.mounted) return;
    setState(() => _actionLoading = true);
    try {
      await widget.service
          .acceptOrderWithPrep(widget.order.id, prep > 0 ? prep : null);
      final assigned =
          await widget.service.tryAutoAssignOnAcceptance(widget.order);
      // إخفاق الإسناد لحظة القبول لم يعد صامتاً أيضاً (كان الصمت هنا يخفي
      // العطل حتى لحظة الجهوزية، فيظن المطعم أن كابتناً في الطريق).
      // والطلب المجدول البعيد ليس إخفاقاً أصلاً — الإسناد ممتنع عمداً
      // حتى نافذة موعده، فرسالته طمأنة لا خطأ.
      if (!assigned && context.mounted) {
        if (widget.order.scheduledStillEarly) {
          showSuccess(
              context,
              tr('قُبل الطلب المجدول — يُسنَد كابتن قرب موعده (${formatDateTime(widget.order.scheduledFor!)})',
                  'Scheduled order accepted — a captain will be assigned near its time (${formatDateTime(widget.order.scheduledFor!)})'));
        } else {
          showError(
              context,
              tr('قُبل الطلب، لكن لا يوجد كابتن متصل الآن — سيُسنَد فور توفّره أو من الإدارة',
                  'Order accepted, but no captain is online right now — one will be assigned as soon as available, or by admin'));
        }
      }
    } catch (_) {
      if (context.mounted) {
        showError(context,
            tr('تعذّر تحديث حالة الطلب', 'Failed to update order status'));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _confirmReady(BuildContext context) async {
    setState(() => _actionLoading = true);
    try {
      await widget.service.updateOrderStatus(widget.order.id, OrderStatus.readyForPickup);
      // الحالة تُقرأ من القاعدة لا من لقطة الشاشة: لقطة قديمة قد تحمل
      // driverId لسائقٍ رفض الطلب بعدها، فيظن الجهاز أن الإسناد قائم
      // ويصمت (بلاغ المالك: طلبات مطعم لم تصل أي سائق).
      final fresh = await widget.service.getOrderOnce(widget.order.id);
      final assigned =
          await widget.service.retryAutoAssignIfNeeded(fresh ?? widget.order);
      if (!assigned && context.mounted) {
        // إخفاق الإسناد لم يعد صامتاً: المطعم يعرف أن الطلب ينتظر تدخّل
        // الإدارة بدل أن يظنّ سائقاً في طريقه إليه.
        showError(
            context,
            tr('الطلب جاهز، لكن لا يوجد كابتن متاح الآن — أبلغنا الإدارة وستتولّى الإسناد',
                'Order is ready, but no captain is available right now — admin has been notified and will assign one'));
      }
    } catch (_) {
      if (context.mounted) {
        showError(context,
            tr('تعذّر تحديث حالة الطلب', 'Failed to update order status'));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _confirmHandover(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: tr('تسليم الطلب للسائق', 'Hand order to captain'),
      content: tr(
          'هل سلّمتَ الطلب #${widget.order.orderNumber} للكابتن الآن؟\n\n'
              'سيُسجَّل وقت التسليم من طرفك في الفاتورة — وهو إثباتك إن نشأ '
              'خلاف حول موعد الاستلام.',
          'Did you hand order #${widget.order.orderNumber} to the captain just now?\n\n'
              'Your handover time will be recorded on the invoice — it is your '
              'proof if a dispute arises over the pickup time.'),
      confirmLabel: tr('سلّمتُه الآن', 'Handed over now'),
    );
    if (ok != true) return;
    setState(() => _actionLoading = true);
    try {
      await widget.service.confirmRestaurantHandover(widget.order.id);
      if (context.mounted) {
        showSuccess(context,
            tr('سُجّل تسليمك للطلب', 'Your handover was recorded'));
      }
    } catch (e) {
      // رسالة عربية ثابتة لا نصّ الاستثناء الخام: بقيّة معالِجات هذا الملف
      // تعرض رسالةً مضبوطة، وتسريب `e.toString()` قد يُظهر نصاً تقنياً للمطعم.
      if (context.mounted) {
        showError(
            context,
            tr('تعذّر تسجيل التسليم — حاول مجدداً',
                'Failed to record handover — try again'));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _runStatusChange(BuildContext context, OrderStatus to) async {
    setState(() => _actionLoading = true);
    try {
      await widget.service.updateOrderStatus(widget.order.id, to);
      // طلبٌ بلا كابتن يبدأ تحضيره: أعد محاولة الإسناد — المسار الطبيعي
      // للمجدول (بوابة القلب كانت تمنعه والآن حانت نافذته أو قاربت)،
      // وشبكة أمان لأي طلب فاته الإسناد لحظة القبول.
      if (to == OrderStatus.preparing &&
          (widget.order.driverId ?? '').isEmpty) {
        await widget.service.retryAutoAssignIfNeeded(widget.order);
      }
    } catch (_) {
      if (context.mounted) {
        showError(context,
            tr('تعذّر تحديث حالة الطلب', 'Failed to update order status'));
      }
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
        title: Text(tr('رفض الطلب', 'Reject order')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr('سبب الرفض', 'Rejection reason'),
              hintText: tr('مثال: نفد أحد الأصناف، المطعم مغلق مؤقتاً...',
                  'e.g. an item ran out, restaurant temporarily closed...'),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? tr('يرجى كتابة سبب الرفض', 'Please enter a rejection reason')
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(tr('تراجع', 'Cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogCtx, ctrl.text.trim());
              }
            },
            child: Text(tr('تأكيد الرفض', 'Confirm rejection')),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    setState(() => _actionLoading = true);
    try {
      await widget.service.rejectOrderByRestaurant(widget.order.id, reason);
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر رفض الطلب', 'Failed to reject order'));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final (bannerLabel, bannerColor, bannerIcon) = _bannerInfo;
    final auth = context.read<app_auth.AuthProvider>();

    final cardContent = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
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
          const Spacer(),
          // ✅ زر الشكوى — المطعم يقدّم شكوى ضد السائق أو العميل من هنا،
          // ويختفي في لحظة انتهاء مهلة الشكوى (24 ساعة من إنهاء الطلب).
          // المتبقّي يظهر في التلميح، ويصير أحمر في ساعاته الثلاث الأخيرة
          // حتى لا تفوت المطعمَ نافذةُ الاعتراض على طلبٍ فيه إشكال.
          ComplaintWindow(
            order: order,
            builder: (context, left, canSubmit) {
              if (!canSubmit) return const SizedBox.shrink();
              final urgent = left != null && left.inHours < 3;
              return IconButton(
                icon: Icon(
                    urgent ? Icons.timer_outlined : Icons.report_problem_outlined,
                    color: urgent ? AppColors.error : AppColors.warning,
                    size: 20),
                tooltip: left == null
                    ? tr('تقديم شكوى', 'File a complaint')
                    : tr('تقديم شكوى — يتبقّى ${formatRemaining(left)}',
                        'File a complaint — ${formatRemaining(left)} left'),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubmitComplaintScreen(
                      order: order,
                      submittedByUid: auth.user?.uid ?? '',
                      submittedByName: auth.user?.restaurantName ?? auth.user?.name ?? '',
                      submittedByRole: UserRole.restaurantManager,
                    ),
                  ),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const Spacer(),
          // إجمالي الطلب كحليّ لا ذهبيّ: الذهبي على البطاقة البيضاء ~١٫٦:١،
          // ورقم الإيراد على كل بطاقة يجب أن يُقرأ.
          Text(formatCurrency(order.itemsTotal),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 14.5)),
        ]),
        // موعد الطلب المجدول (ح4) — بارزاً بلون تحذيري: أخطر خطأ تشغيلي
        // هنا أن يُحضَّر طلب الثامنة ظهراً فيبرد قبل موعده.
        if (order.isScheduled) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.schedule_rounded,
                  size: 15, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                  tr('مجدول: ${formatDateTime(order.scheduledFor!)} — لا تحضّره مبكراً',
                      'Scheduled: ${formatDateTime(order.scheduledFor!)} — do not prepare it early'),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning)),
            ]),
          ),
        ],
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.person_outline, size: 15, color: AppColors.textGray),
          const SizedBox(width: 6),
          Expanded(
            child: Text(order.customerName,
                style: const TextStyle(fontSize: 13.5, color: AppColors.textGray)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.timer_outlined, size: 14, color: AppColors.textGray.withOpacity(0.8)),
          const SizedBox(width: 3),
          Text(_waitingLabel(),
              style: TextStyle(fontSize: 12.5, color: AppColors.textGray.withOpacity(0.8))),
          if (order.customerPhone.trim().isNotEmpty)
            IconButton(
              tooltip: tr('الاتصال بالعميل', 'Call customer'),
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
                      // كحليّ على التلوين الذهبي الخفيف: الذهبي على تدرّجه ذاته
                      // ~٢:١ لرقمٍ صغير — الكحلي يجعله مقروءاً كبقيّة الحبوب.
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.dark)),
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
                            style: TextStyle(fontSize: 12.5, color: AppColors.textGray.withOpacity(0.9))),
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
                child: Text(
                    tr('سبب الرفض: ${order.rejectionReason}',
                        'Rejection reason: ${order.rejectionReason}'),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textDark)),
              ),
            ]),
          ),
        ],
        if (order.status == OrderStatus.restaurantPending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _ActionButton(
                label: tr('تأكيد الاستلام', 'Accept order'),
                color: AppColors.primary,
                loading: _actionLoading,
                onPressed: () => _confirmAcceptance(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: tr('رفض', 'Reject'),
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
            label: tr('جاري التحضير', 'Preparing'),
            color: AppColors.primary,
            loading: _actionLoading,
            onPressed: () => _runStatusChange(context, OrderStatus.preparing),
          ),
        ],
        if (order.status == OrderStatus.preparing) ...[
          const SizedBox(height: 10),
          _ActionButton(
            label: tr('جاهز للاستلام', 'Ready for pickup'),
            color: AppColors.success,
            loading: _actionLoading,
            onPressed: () => _confirmReady(context),
          ),
        ],
        // إقرار الطرف الثاني بالتسليم (طلب المالك ٢٠٢٦-٠٨-١١): الطلب كان
        // يبقى «جاهز — بانتظار استلام السائق» حتى بعد أن يأخذه الكابتن،
        // فلا يملك المطعم ما يُثبت أنه سلّمه. الضغطة **لا تغيّر الحالة**
        // (الانتقال بيد الكابتن كما هو — ضغطة المطعم لا تُثبت استلاماً لم
        // يقع)، بل تختم لحظة التسليم من طرفه فيصير في الطلب إقرار طرفين
        // يظهر في الفاتورة ويُحتكم إليه في نزاع «سلّمتُه»/«لم يصلني».
        //
        // وقرار المالك ٢٠٢٦-٠٨-١٢: **لا يُضغط الزر إلا بعد أن يصل الكابتن
        // فعلاً**. وإلا صار إقراراً بلا واقعة: مطعمٌ يضغطه والكيس ما زال
        // على الرفّ يُنتج «إثباتاً» يناقض الحقيقة — وإثباتٌ يكذب أسوأ من
        // لا إثبات، لأنه يُحتكم إليه في النزاع.
        //
        // والمرجع هو ختم وصول الكابتن (`arrivedAtRestaurantAt`) لا موقعه
        // اللحظي: ذاك ختمٌ مرّ بحارس المئة متر وقت وقوعه، والموقع اللحظي
        // قد يكون متقادماً دقائق فيقبل من ليس هناك أو يرفض من هو هناك.
        //
        // والزر لا يُخفى بل يُقفَل ويشرح — قاعدة اعتُمدت بعد عطل «الكابتن
        // لا يجد زرّ الاستلام»: الحجب الصامت في الواجهة يُقرأ عطلاً في
        // التطبيق لا شرطاً غير مستوفٍ.
        if (order.status == OrderStatus.readyForPickup) ...[
          const SizedBox(height: 10),
          if (order.restaurantHandoverAt != null)
            _HandoverStamp(at: order.restaurantHandoverAt!)
          else if (order.arrivedAtRestaurantAt == null)
            const _LockedHandoverHint()
          else ...[
            _ActionButton(
              label: tr('سلّمتُ الطلب للسائق', 'Handed to captain'),
              color: AppColors.success,
              loading: _actionLoading,
              onPressed: () => _confirmHandover(context),
            ),
            const SizedBox(height: 6),
            // رمز الاستلام (و7): إثبات مادي — الكابتن يمسحه بكاميرته
            // فيؤكد أن الجهازين تواجها فعلاً في نفس المكان واللحظة،
            // وهو أقوى من زرّين يُضغطان كلٌّ من مكانه.
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: Text(
                  tr('رمز الاستلام — يمسحه الكابتن',
                      'Pickup code — captain scans it'),
                  style: const TextStyle(fontSize: 12.5)),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(tr('طلب #${order.orderNumber}',
                      'Order #${order.orderNumber}')),
                  content: SizedBox(
                    width: 240,
                    height: 240,
                    // المحتوى معرّف الطلب لا رقمه: الرقم ٦ خانات يُخمَّن،
                    // والمعرّف الكامل لا يُزوَّر بالتخمين.
                    child: QrImageView(
                      data: 'zadgo:pickup:${order.id}',
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
        // بعد أن يؤكد الكابتن استلامه، يبقى ختم المطعم ظاهراً كإثبات.
        if (order.status.index >= OrderStatus.pickedUp.index &&
            order.status.isActive &&
            order.restaurantHandoverAt != null) ...[
          const SizedBox(height: 10),
          _HandoverStamp(at: order.restaurantHandoverAt!),
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

/// الزرّ مقفلاً قبل وصول الكابتن — يشرح سببه بدل أن يختفي.
///
/// الاختفاء الصامت كان درساً مكلفاً في تطبيق الكابتن: زرٌّ غائب يُقرأ
/// «التطبيق خربان» فيُتصل بالإدارة، بينما زرٌّ مقفلٌ بسطر تفسير يُقرأ
/// «انتظر خطوةً واحدة» فينتظر.
class _LockedHandoverHint extends StatelessWidget {
  const _LockedHandoverHint();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          const Icon(Icons.lock_clock_rounded,
              size: 18, color: AppColors.textGray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(
                  'زرّ «سلّمتُ الطلب» يفتح فور تسجيل الكابتن وصوله للمطعم — '
                      'فالإقرار لا يسبق الواقعة.',
                  'The "Handed to captain" button unlocks once the captain '
                      'records arriving at the restaurant — confirmation cannot precede the event.'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
            ),
          ),
        ]),
      );
}

/// ختم «سلّمتُه» — يحلّ محل الزر بعد الضغط، بالساعة لا بكلمة مجردة: الوقت
/// هو محل النزاع لا واقعة التسليم نفسها.
class _HandoverStamp extends StatelessWidget {
  final DateTime at;
  const _HandoverStamp({required this.at});

  @override
  Widget build(BuildContext context) {
    final clock =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withOpacity(0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
        const SizedBox(width: 8),
        Text(
            tr('سلّمتَ الطلب للسائق — $clock',
                'You handed the order to the captain — $clock'),
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.success)),
      ]),
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
  Widget build(BuildContext context) {
    // لون المقدّمة يُشتقّ من إضاءة الخلفية لا يُثبَّت أبيض: الأبيض على الذهبي
    // (أهمّ أزرار المطعم: تأكيد الاستلام/جاري التحضير) تباينه ~١٫٦:١ فيكاد لا
    // يُقرأ. الخلفية الفاتحة (كالذهبي) تأخذ نصاً كحلياً (~١٠:١)، والداكنة
    // (القرمزي/الأخضر) تبقى بيضاء.
    final onColor =
        color.computeLuminance() > 0.5 ? AppColors.dark : Colors.white;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: onColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: onColor))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}