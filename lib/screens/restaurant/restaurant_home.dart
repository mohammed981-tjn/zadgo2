// lib/screens/restaurant/restaurant_home.dart
//
// شاشة "مدير المطعم" — أساس أُعيد استخدامه من شاشة الطلبات في لوحة المدير
// (admin_home.dart) مع فلترة تلقائية على restaurantId الخاص بالمستخدم فقط.
// هذه الشاشة هي نقطة الانطلاق التي سيُبنى فوقها تطبيق المطعم المنفصل مستقبلاً.
//
// [مرحلة أ]: عرض أصناف الطلب داخل البطاقة، ملاحظة العميل العامة، رقم جواله
// مع زر اتصال مباشر، ووقت انتظار الطلب منذ إنشائه.
//
// [مرحلة ب]: قائمة الطلبات مقسّمة لتبويبين فرعيين بشريط TabBar — "نشطة"
// (الأقدم أولاً) و"منتهية" (الأحدث أولاً).
//
// [مرحلة ج]: تنبيه صوتي (SystemSound، بلا مكتبات أو ملفات صوت إضافية) يتكرر
// 5 مرات عند وصول طلب جديد بينما التطبيق مفتوح، مع ثلاثة مؤشرات بصرية معاً:
// شارة عددية حمراء على تبويب "الطلبات" بالشريط السفلي، وميض لخلفية أول طلب
// جديد لثوانٍ عند ظهوره، وشريط علوي مؤقت (Banner) يظهر حتى لو كان المطعم
// متصفحاً تبويباً آخر (التقارير/الأسعار) وقت وصول الطلب. لا يغطي هذا إشعار
// نظام حين يكون التطبيق مغلقاً تماماً — ذاك يتطلب Cloud Functions، والمشروع
// مبني عمداً على تجنّبها (انظر تعليق أعلى firestore.rules).
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

  /// معرّفات الطلبات الجديدة (restaurantPending) المعروفة من آخر مرة وصلت
  /// فيها بيانات — تُستخدم لاكتشاف وصول طلب جديد فعلياً (id لم يكن موجوداً
  /// سابقاً) بدل الاعتماد على مجرد تغيّر عدد الطلبات، الذي قد يتغيّر أيضاً
  /// عند تحديث حالة طلب موجود مسبقاً.
  Set<String> _knownPendingIds = {};
  bool _firstSnapshot = true;
  int _newOrdersBadgeCount = 0;
  OverlayEntry? _bannerEntry;

  @override
  void dispose() {
    _bannerEntry?.remove();
    super.dispose();
  }

  /// يُستدعى مع كل دفعة جديدة من الطلبات القادمة من Firestore. يقارن
  /// الطلبات الجديدة الحالية (بانتظار تأكيد المطعم) بما كان معروفاً سابقاً،
  /// ويطلق التنبيه الصوتي/البصري فقط عند ظهور معرّف لم يكن موجوداً من قبل.
  void _detectNewOrders(List<Order> allOrders) {
    final pendingNow =
        allOrders.where((o) => o.status == OrderStatus.restaurantPending).map((o) => o.id).toSet();

    if (_firstSnapshot) {
      // أول تحميل للشاشة: لا نُطلق تنبيهات لطلبات كانت موجودة أصلاً قبل
      // فتح التطبيق، فقط نسجّلها كنقطة انطلاق للمقارنة.
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

  /// شريط علوي مؤقت يظهر فوق أي تبويب حالي (حتى لو كان المطعم يتصفّح
  /// التقارير أو الأسعار وقت وصول الطلب)، ويختفي تلقائياً أو بالضغط عليه.
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

/// قائمة طلبات المطعم، مقسّمة لتبويبين فرعيين: نشطة ومنتهية.
///
/// "نشطة" = كل حالة ما زالت جارية (isActive حسب تعريفها في models.dart)،
/// مرتّبة تصاعدياً بوقت الإنشاء (الأقدم أولاً) لأنه الأكثر إلحاحاً على
/// المطعم. "منتهية" = المكتملة/المرفوضة/الملغاة، مرتّبة تنازلياً (الأحدث
/// أولاً) لأنها للمراجعة لا للتنفيذ.
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
            // إبلاغ الشاشة الأم بكل دفعة بيانات جديدة لاكتشاف الطلبات
            // الجديدة فعلياً (بعد انتهاء بناء هذا الإطار، تفادياً لاستدعاء
            // setState أثناء البناء).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onOrdersChanged(orders);
            });

            final active = orders.where((o) => o.status.isActive).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            final finished = orders.where((o) => o.status.isFinished).toList()
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

/// قائمة عرض بسيطة قابلة لإعادة الاستخدام بين تبويبَي "نشطة" و"منتهية"،
/// كل واحد برسالة فراغ مختلفة.
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
        // وميض لخلفية البطاقة يُفعَّل فقط لأول طلب جديد بانتظار التأكيد —
        // أكثر الحالات إلحاحاً وأولها ظهوراً في القائمة (الأقدم أولاً).
        highlightAsNew: i == 0 && orders[i].status == OrderStatus.restaurantPending,
      ),
    );
  }
}

/// بطاقة طلب واحد — شارة حالة بارزة أعلى البطاقة، قائمة الأصناف المطلوبة
/// فعلياً، ثم زر إجراء واحد بلون كامل أسفلها. تدعم وميضاً اختيارياً لخلفية
/// البطاقة عند تفعيل [highlightAsNew] لجذب الانتباه لطلب وصل للتو.
///
/// القيود على صلاحيات المطعم كما هي دون أي تغيير: لا تتبع سائق، لا إلغاء،
/// لا تأكيد توصيل — تتوقف إجراءات المطعم عند "الطلب جاهز"؛ ما بعدها (بحث
/// سائق، التوصيل الفعلي) من اختصاص السائق ولوحة المدير العام حصراً.
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

  @override
  void initState() {
    super.initState();
    if (widget.highlightAsNew) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      )..repeat(reverse: true, count: 5); // يتوقف الوميض تلقائياً بعد 5 نبضات.
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  /// نص ولون وأيقونة الشارة العلوية حسب حالة الطلب — بلغة موجّهة للمطعم
  /// بدل النص التقني العام المشترك بين كل الأدوار (order.status.label).
  (String, Color, IconData) get _bannerInfo {
    final order = widget.order;
    switch (order.status) {
      case OrderStatus.restaurantPending:
        return ('طلب جديد بانتظار التأكيد', AppColors.warning, Icons.fiber_new_rounded);
      case OrderStatus.restaurantAccepted:
        return ('تم الاستلام — جاري التجهيز', AppColors.primary, Icons.hourglass_top_rounded);
      case OrderStatus.preparing:
        return ('قيد التحضير', AppColors.primary, Icons.restaurant_rounded);
      case OrderStatus.readyForPickup:
        return ('جاهز للاستلام', Colors.teal, Icons.shopping_bag_rounded);
      case OrderStatus.searchingDriver:
        return ('بانتظار سائق', Colors.deepPurple, Icons.manage_search_rounded);
      case OrderStatus.driverAssigned:
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return ('في الطريق إلى العميل', Colors.deepPurple, Icons.delivery_dining_rounded);
      default:
        return (order.status.label, order.status.color, Icons.info_outline_rounded);
    }
  }

  /// نص وقت الانتظار منذ إنشاء الطلب، بصياغة عربية مختصرة (دقائق أو ساعات).
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final service = widget.service;
    final (bannerLabel, bannerColor, bannerIcon) = _bannerInfo;

    final cardContent = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // الشارة العلوية البارزة.
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
        // اسم العميل + وقت الانتظار + زر اتصال (إن توفّر الرقم).
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
        // قائمة الأصناف المطلوبة.
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
        // ملاحظة العميل العامة على الطلب كله (مختلفة عن extras الخاصة بكل
        // صنف على حدة).
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
        // ملاحظة: تم إزالة زر "رفض/إلغاء الطلب" نهائياً من شاشة المطعم بناءً على
        // طلب المنصة — إلغاء الطلب لا يظهر إلا في شاشة الطلبات بلوحة المدير العام.
        // كذلك تتبع السائق وتأكيد إغلاق/تسليم الطلب ليسا من اختصاص المطعم؛ دور
        // المطعم يقتصر على تأكيد الاستلام وتجهيز الطلب وتعليمه جاهزاً، ثم يتولى
        // السائق ولوحة المدير العام بقية دورة الطلب (تتبع الموقع والتسليم).
        if (order.status == OrderStatus.restaurantPending) ...[
          const SizedBox(height: 10),
          _ActionButton(
            label: 'تأكيد استلام الطلب',
            color: AppColors.primary,
            onPressed: () => service.updateOrderStatus(order.id, OrderStatus.restaurantAccepted),
          ),
        ],
        if (order.status == OrderStatus.restaurantAccepted) ...[
          const SizedBox(height: 10),
          _ActionButton(
            label: 'تجهيز الطلب',
            color: AppColors.primary,
            onPressed: () => service.updateOrderStatus(order.id, OrderStatus.preparing),
          ),
        ],
        if (order.status == OrderStatus.preparing) ...[
          const SizedBox(height: 10),
          _ActionButton(
            label: 'الطلب جاهز',
            color: AppColors.success,
            onPressed: () => service.updateOrderStatus(order.id, OrderStatus.readyForPickup),
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

    // البطاقة المميَّزة كطلب جديد: وميض لوني خفيف لخلفيتها عبر AnimatedBuilder
    // بدل تغيير لون الشارة نفسها، حتى لا يتعارض مع لون شارة الحالة.
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

/// زر إجراء بارز بخلفية ملوّنة كاملة العرض — بديل ElevatedButton الافتراضي
/// ليطابق الطابع البصري لزر "تأكيد التوصيل" الأخضر في التصميم المرجعي.
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({required this.label, required this.color, required this.onPressed});

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
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
}