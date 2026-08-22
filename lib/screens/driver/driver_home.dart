import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback, SystemSound, SystemSoundType;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/driver_keep_alive.dart';
import '../../providers/local_alerts.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/app_lang.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/complaint_window.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import '../auth/edit_profile_screen.dart';
import '../customer/order_map_screen.dart';
import '../customer/order_chat_screen.dart';
import '../customer/submit_complaint_screen.dart';
import '../customer/my_complaints_screen.dart';
import '../../utils/driver_proof_flow.dart';
import 'pickup_docket_screen.dart';
import 'captain_guide_screen.dart';
import '../../utils/location_guard.dart';
import '../../utils/battery_advice.dart';
import '../../navigator_key.dart';
import '../../widgets/osm_attribution.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});
  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  int _tab = 0;
  Timer? _locationTimer;
  int _driverStreamRetryToken = 0;

  /// هل يجري بثّ موقعٍ الآن؟ يمنع تراكم قراءات GPS متوازية إن تأخرت واحدة
  /// أكثر من دورة المؤقّت.
  bool _pushingLocation = false;

  /// آخر حالة اتصال معروفة للسائق — تُحدَّث من تدفّق مستنده في build. البثّ
  /// يتوقف كلياً وهو «غير متصل»: بلا هذا الشرط كان الجهاز يكتب موقعاً كل
  /// 8 ثوانٍ حتى خارج الدوام (~10 آلاف كتابة/سائق/يوم + استنزاف بطارية).
  bool _isOnline = false;

  /// آخر لقطة لمستند السائق — تغذّي بطاقة العرض بموقعه لحساب مسافة الالتقاط.
  Driver? _driver;

  /// هل بيده طلب جارٍ (أو عرض بانتظار قراره)؟ يحدّد كثافة بثّ الموقع:
  /// التتبّع اللحظي يخدم عميلاً ينتظر، ومن لا طلب لديه يكفيه نبض متباعد
  /// يُبقيه مرشّحاً للإسناد بالمسافة.
  bool _hasActiveOrder = false;

  /// آخر موقع أُرسل فعلاً ووقته — أساس خنق الكتابات.
  double? _sentLat, _sentLng;
  DateTime? _sentAt;

  final Set<String> _acknowledgedNotified = {};
  final Set<String> _autoAssignedNotified = {};
  OverlayEntry? _bannerEntry;

  @override
  void initState() {
    super.initState();
    // طلب إذن الموقع مبكراً حتى لا يصطدم به السائق أول مرة وهو مستعجل
    // على تأكيد استلام. الفشل هنا مقبول بصمت — الحارس سيعيد الطلب عند الحاجة.
    LocationGuard.currentPosition().then((_) {}).catchError((_) {});
    // ت٣: حقن مسجّل واقعة الموقع المُحاكى — كانت الإشارة تتبخّر بمجرد
    // إطفاء الكابتن لتطبيق الموقع الوهمي وإعادة المحاولة.
    LocationGuard.onMockedLocation =
        () => context.read<FirebaseService>().recordMockLocationIncident();
    _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pushLocation());
    // سقف الحمولة من إعدادات الإدارة — يُقرأ مرة عند الفتح لا مع كل تدفّق.
    context.read<FirebaseService>().maxOrdersPerDriver().then((v) {
      if (mounted) _maxLoad = v;
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _bannerEntry?.remove();
    super.dispose();
  }

  /// بثّ موقع السائق الحقيقي دورياً — يغذّي خريطة تتبّع الطلب عند العميل
  /// والإسناد التلقائي لأقرب سائق.
  ///
  /// كان الكود السابق يبثّ موقعاً **محاكى** (نقطة وسط الرياض تهتز عشوائياً)
  /// — بقية من التطوير المبكر جعلت خريطة العميل والإسناد بالمسافة بلا معنى.
  Future<void> _pushLocation() async {
    if (_pushingLocation || !mounted || !_isOnline) return;
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final driverId = auth.user?.uid;
    if (driverId == null) return;
    _pushingLocation = true;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 7),
      );
      if (!_shouldSendLocation(pos.latitude, pos.longitude)) return;
      await service.updateDriverLocation(driverId, pos.latitude, pos.longitude);
      _sentLat = pos.latitude;
      _sentLng = pos.longitude;
      _sentAt = DateTime.now();
    } catch (_) {
      // فشل قراءة دورية لا يستحق إزعاجاً — الدورة التالية بعد ثوانٍ.
    } finally {
      _pushingLocation = false;
    }
  }

  /// هل يستحق هذا الموقع كتابةً؟
  ///
  /// المؤقّت يقرأ الموقع كل 8 ثوانٍ، وكان **كل** قراءة تُكتب في Firestore:
  /// 450 كتابة/ساعة لكل سائق متصل — عشرون سائقاً بعشر ساعات يعني نحو 90
  /// ألف كتابة يومياً، والحصّة المجانية 20 ألفاً. وسائقٌ واقفٌ ينتظر طلباً
  /// كان يكتب موقعه نفسَه مئات المرات بلا فائدة لأحد.
  ///
  /// فتُكتب القراءة فقط إن تحرّك السائق مسافة معتبرة، أو انقضى «نبض»
  /// يُثبت أنه حيّ. والعتبتان أضيق وهو يحمل طلباً (عميل يتابع الخريطة)
  /// وأوسع وهو فارغ (الموقع حينها للإسناد بالمسافة لا للتتبّع).
  bool _shouldSendLocation(double lat, double lng) {
    if (_sentLat == null || _sentLng == null || _sentAt == null) return true;
    final minMeters = _hasActiveOrder ? 30.0 : 150.0;
    final heartbeat = _hasActiveOrder
        ? const Duration(seconds: 45)
        : const Duration(minutes: 5);
    final movedMeters =
        haversineDistanceKm(_sentLat!, _sentLng!, lat, lng) * 1000;
    return movedMeters >= minMeters ||
        DateTime.now().difference(_sentAt!) >= heartbeat;
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

  /// آخر حالة اتصال زُوملت بها الخدمة — حارس يمنع نداءً مع كل إعادة بناء.
  bool? _keepAliveOn;

  void _syncKeepAlive(bool online) {
    if (_keepAliveOn == online) return;
    _keepAliveOn = online;
    if (online) {
      DriverKeepAlive.start();
    } else {
      DriverKeepAlive.stop();
    }
  }

  /// آخر حمولة بُثَّت — حارس يمنع كتابة متكررة بنفس القيم.
  String _lastLoadSignature = '';

  /// سقف الطلبات المتزامنة من إعدادات الإدارة (٣ افتراضاً)، يُقرأ مرة.
  int _maxLoad = 3;

  /// بثّ حمولة الكابتن لمستنده: عددها ومرساة عنقودها وعلم سعته — هي ما
  /// يرشّح عليه تطبيقُ المطعم عند الإسناد (الطلبات المتعددة في نطاق مطاعم
  /// متقاربة). تُكتب من هنا لأن القواعد لا تسمح للمطعم بكتابتها.
  void _publishLoad(String driverId, List<Order> active) {
    if (driverId.isEmpty) return;
    final mine = active
        .where((o) => o.driverId == driverId && !o.needsDriverAcknowledgement)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final anchor = mine.isEmpty ? null : mine.first;
    final sig = '${mine.length}|${anchor?.restaurantLat}|${anchor?.restaurantLng}';
    if (sig == _lastLoadSignature) return;
    _lastLoadSignature = sig;
    context
        .read<FirebaseService>()
        .publishDriverLoad(
          driverId: driverId,
          activeOrders: mine.length,
          hasCapacity: mine.length < _maxLoad,
          clusterLat: anchor?.restaurantLat,
          clusterLng: anchor?.restaurantLng,
        )
        .catchError((_) {});
  }

  void _checkForNotifications(List<Order> orders) {
    // كثافة بثّ الموقع تتبع وجود طلب جارٍ — تُقرأ من نفس التدفّق بلا
    // استعلام إضافي.
    _hasActiveOrder = orders.any((o) => o.status.isActive);
    // طلب خرج من قائمته (رُفض/انقضى/أُلغي) يُمحى من «سبق التنبيه» — فلو عاد
    // إليه لاحقاً (لا سائق غيره متاحاً مثلاً) ظهر العرض من جديد بدل أن يظل
    // الطلب غير مرئي له للأبد.
    final currentIds = orders.map((o) => o.id).toSet();
    _acknowledgedNotified.removeWhere((id) => !currentIds.contains(id));
    _autoAssignedNotified.removeWhere((id) => !currentIds.contains(id));
    for (final o in orders) {
      if (o.needsDriverAcknowledgement) {
        if (!_acknowledgedNotified.contains(o.id)) {
          _acknowledgedNotified.add(o.id);
          _playAssignmentSound();
          // إشعار لوحة النظام (و4): الشريط الداخلي يعيش داخل شاشتنا
          // وحدها — والكابتن الحيّ في الخلفية (بفضل و2) كان يستقبل
          // العرض بلا أي صوت يخرج إليه. هذه هي الحلقة الناقصة.
          LocalAlerts.offerAlert(
            title: tr('🛵 عرض توصيل جديد', '🛵 New delivery offer'),
            body: tr(
                'طلب #${o.orderNumber} من ${o.restaurantName} — افتح للقبول أو الرفض',
                'Order #${o.orderNumber} from ${o.restaurantName} — open to accept or reject'),
          );
          _showDecisionBanner(o);
        }
      } else if (o.driverId != null &&
          o.driverId!.isNotEmpty &&
          o.status == OrderStatus.driverAssigned) {
        if (!_autoAssignedNotified.contains(o.id)) {
          _autoAssignedNotified.add(o.id);
          _playAssignmentSound();
          LocalAlerts.offerAlert(
            title: tr('📦 طلب مُسند إليك', '📦 Order assigned to you'),
            body: tr('طلب #${o.orderNumber} من ${o.restaurantName}',
                'Order #${o.orderNumber} from ${o.restaurantName}'),
          );
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

    void dismiss() {
      if (_bannerEntry == entry) {
        entry.remove();
        _bannerEntry = null;
      }
    }

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 16,
        right: 16,
        child: _OfferBanner(
          order: order,
          driver: _driver,
          onAccept: () async {
            dismiss();
            try {
              await service.acceptAssignedOrder(order.id);
              LocalAlerts.clearOfferAlert();
            } catch (_) {
              if (mounted) {
                showError(
                    context,
                    tr('تعذّر قبول الطلب — ربما أُلغي أو أُعيد إسناده',
                        'Could not accept the order — it may have been canceled or reassigned'));
              }
              return;
            }
            // بعد القبول تُفتح مذكرة الاستلام مباشرةً — هي وجهة السائق
            // التالية بلا بحث في القوائم.
            navigatorKey.currentState?.push(MaterialPageRoute(
                builder: (_) => PickupDocketScreen(orderId: order.id)));
          },
          onReject: () async {
            dismiss();
            try {
              await service.rejectAssignedOrder(order.id);
              LocalAlerts.clearOfferAlert();
            } catch (_) {
              if (mounted) {
                showError(
                    context,
                    tr('تعذّر رفض الطلب — ربما تغيّرت حالته',
                        'Could not reject the order — its status may have changed'));
              }
            }
          },
          onExpired: () {
            // انقضاء عدّاد الشريط يُزيله بصرياً فقط (دفعة ١، عطل السباق ٢):
            // إعادة الإسناد صارت بيد بطاقة العرض وحدها (كلٌّ بعدّادها) فلا
            // يُعاد إسناد العرض الأحدث مرّتين (الشريط + البطاقة). البطاقة في
            // القائمة تُمرّر الطلب عند انقضاء مهلتها.
            dismiss();
          },
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
            child: GestureDetector(
              onTap: () {
                entry.remove();
                _bannerEntry = null;
                navigatorKey.currentState?.push(MaterialPageRoute(
                    builder: (_) => PickupDocketScreen(orderId: order.id)));
              },
              child: Row(children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('طلب جديد #${order.orderNumber} أُسند إليك — اضغط لمذكرة الاستلام',
                        'New order #${order.orderNumber} assigned to you — tap for the pickup memo'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
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
        // تحديث حالة الاتصال لبثّ الموقع — بلا setState: البثّ الدوري وحده
        // من يقرؤها، وbuild هذا سيُعاد أصلاً مع كل تغيّر في المستند.
        _isOnline = driver?.isOnline ?? false;
        _driver = driver;
        // الخدمة الأمامية تتبع **حالة المستند** لا ضغطة الزر: الحالة
        // تتغيّر من ثلاثة مواضع (مفتاح الشريط، بطاقة الحالة، الخروج)،
        // ورَبطُها بكل موضع يعني نسياناً في أحدها يوماً. وهنا نقطة
        // واحدة يمرّ بها كل تغيير مهما كان مصدره.
        _syncKeepAlive(_isOnline);
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('مرحباً ${auth.user?.name ?? ""}',
                'Welcome ${auth.user?.name ?? ""}')),
            actions: [
              // تبديل اللغة (دفعة «اللغة الثانية»).
              const LanguageToggleButton(),
              if (driver != null)
                Row(children: [
                  // تباين حالة الاتصال (دفعة ٤): كان «غير متصل» بـwhite54 غيرَ
                  // مرئيّ على الشريط، و«متصل» بأخضر نيون خارج الهوية (~1.3:1).
                  // ألوان الهوية: أخضر النجاح للمتصل، والرماديّ المقروء لغيره.
                  Text(
                      driver.isOnline
                          ? tr('متصل', 'Online')
                          : tr('غير متصل', 'Offline'),
                      style: TextStyle(
                          color: driver.isOnline
                              ? AppColors.success
                              : AppColors.textGray,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                  Switch(value: driver.isOnline, onChanged: (v) async {
                      await service.setDriverOnline(driverId, v);
                      if (context.mounted) {
                        showSuccess(
                            context,
                            v
                                ? tr('أنت الآن متاح لاستقبال الطلبات — بالتوفيق! 🚀',
                                    'You are now available for orders — good luck! 🚀')
                                : tr('أصبحت غير متصل — لن تصلك طلبات جديدة',
                                    'You are now offline — no new orders will reach you'));
                      }
                    },
                      activeColor: AppColors.success),
                ]),
              IconButton(
                tooltip: tr('دليل الكابتن', 'Captain guide'),
                icon: const Icon(Icons.school_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CaptainGuideScreen()),
                ),
              ),
              IconButton(
                tooltip: tr('الشكاوى', 'Complaints'),
                icon: const Icon(Icons.support_agent_rounded),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyComplaintsScreen(
                        uid: driverId, role: UserRole.driver),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.logout), onPressed: () async {
                // تأكيد قبل الخروج (كما في شاشة العميل): زرّ الخروج كان يُنفَّذ
                // بلمسة واحدة بلا سؤال، ولمسةٌ خاطئة تُخرج الكابتن وسط جولة.
                final ok = await showConfirmDialog(context,
                    title: tr('تسجيل الخروج', 'Sign out'),
                    content: tr('هل تريد تسجيل الخروج من حسابك؟',
                        'Do you want to sign out of your account?'),
                    confirmLabel: tr('خروج', 'Sign out'),
                    confirmColor: AppColors.error);
                if (ok != true || !mounted) return;
                if (driver != null) await service.setDriverOnline(driverId, false);
                // إيقافٌ صريح لا اتّكالاً على تدفّق المستند: الخروج
                // يهدم الشاشة فوراً، فقد لا تصل قراءةُ الحالة الجديدة
                // ويبقى الإشعار معلّقاً لكابتنٍ خرج.
                await DriverKeepAlive.stop();
                await auth.logout();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                }
              }),
            ],
          ),
          body: Column(children: [
            // بانر الحظر (دفعة ٨): كابتنٌ محظور (المدير أو مشغّل أسطوله)
            // لا يُرشَّح للعروض — وصمتُ التطبيق عندها يُقرأ عطلاً، فالبانر
            // يقول السبب وماذا يفعل بدل أن يظل يقلّب شاشةً فارغة.
            if (driver != null && !driver.isActive)
              Container(
                width: double.infinity,
                color: AppColors.error.withOpacity(0.12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.block_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        tr('حسابك موقوف مؤقتاً عن استقبال العروض — تواصل مع إدارتك أو مشغّل أسطولك.',
                            'Your account is temporarily suspended from receiving offers — contact the admin or your fleet operator.'),
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error)),
                  ),
                ]),
              ),
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
                return BroadcastBanner(id: latest.id, title: latest.title, body: latest.body);
              },
            ),
            Expanded(
              child: IndexedStack(index: _tab, children: [
                _MyOrdersTab(
                  driverId: driverId,
                  driver: driver,
                  onOrdersChanged: _checkForNotifications,
                  onLoadChanged: (o) => _publishLoad(driverId, o),
                ),
                _DriverEarningsTab(driver: driver),
              ]),
            ),
          ]),
          bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(icon: const Icon(Icons.delivery_dining_outlined), selectedIcon: const Icon(Icons.delivery_dining), label: tr('الطلبات', 'Orders')),
              NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), selectedIcon: const Icon(Icons.account_balance_wallet), label: tr('أرباحي', 'My earnings')),
            ]),
        );
      },
    );
  }
}

/// بطاقة «عرض توصيل» مكتملة القرار (نمط تويو/جاهز/أوبر): الأجرة المتوقعة،
/// مسافتا الالتقاط والتوصيل، مبلغ التحصيل النقدي إن وُجد، وعدّاد تنازلي —
/// السائق يقرّر بمعلومة كاملة، وانقضاء المهلة يمرّر الطلب للسائق التالي بدل
/// أن يبقى معلّقاً على غافلٍ عن هاتفه.
class _OfferBanner extends StatefulWidget {
  final Order order;
  final Driver? driver;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onExpired;
  const _OfferBanner({
    required this.order,
    required this.driver,
    required this.onAccept,
    required this.onReject,
    required this.onExpired,
  });

  @override
  State<_OfferBanner> createState() => _OfferBannerState();
}

class _OfferBannerState extends State<_OfferBanner> {
  /// مهلة القرار — 45 ثانية توازن بين سائقٍ يقود لحظتها وطلبٍ ساخن لا
  /// يحتمل الانتظار (تويو وجاهز في نطاق 30–60 ثانية).
  static const int _offerSeconds = 45;
  int _secondsLeft = _offerSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final d = widget.driver;
    final isCash = o.paymentMethod == PaymentMethod.cash;

    // المسافتان — إن توفرت الإحداثيات؛ غيابها يحجب السطر لا يعرض صفراً.
    double? pickupKm, dropKm;
    if (d?.lat != null && d?.lng != null &&
        o.restaurantLat != null && o.restaurantLng != null) {
      pickupKm = haversineDistanceKm(
          d!.lat!, d.lng!, o.restaurantLat!, o.restaurantLng!);
    }
    if (o.restaurantLat != null && o.restaurantLng != null &&
        o.deliveryLat != null && o.deliveryLng != null) {
      dropKm = haversineDistanceKm(
          o.restaurantLat!, o.restaurantLng!, o.deliveryLat!, o.deliveryLng!);
    }

    final urgent = _secondsLeft <= 10;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_shipping_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  tr('عرض توصيل — طلب #${o.orderNumber}',
                      'Delivery offer — order #${o.orderNumber}'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5)),
            ),
            // العدّاد: يحمرّ في الثواني الأخيرة — إلحاح مرئي بلا صوت إضافي.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: urgent ? AppColors.error : Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(tr('${_secondsLeft}ث', '${_secondsLeft}s'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5)),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _secondsLeft / _offerSeconds,
              minHeight: 4,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(
                  urgent ? AppColors.error : Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          // ترتيب الأرقام بقرار المالك (٢٠٢٦-٠٨-١١): كامل المبلغ الذي
          // سيستلمه من العميل أولاً (وجبات + توصيل — للنقدي)، وتحته أجرته —
          // بلا أي تفصيل لمكوّنات رسوم العميل أو العمولة، فلا شأن له بها.
          if (isCash)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    tr('نقدي — تستلم من العميل ${formatCurrency(o.cashDueFromCustomer)}',
                        'Cash — you collect ${formatCurrency(o.cashDueFromCustomer)} from the customer'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          Row(children: [
            const Icon(Icons.payments_rounded, color: Colors.white, size: 17),
            const SizedBox(width: 6),
            Text(
                tr('أجرتك ${formatCurrency(o.driverShare)}',
                    'Your fee ${formatCurrency(o.driverShare)}'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5)),
            if (pickupKm != null || dropKm != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  [
                    if (pickupKm != null)
                      tr('الالتقاط ${pickupKm.toStringAsFixed(1)} كم',
                          'Pickup ${pickupKm.toStringAsFixed(1)} km'),
                    if (dropKm != null)
                      tr('التوصيل ${dropKm.toStringAsFixed(1)} كم',
                          'Drop-off ${dropKm.toStringAsFixed(1)} km'),
                  ].join(' • '),
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Text('${o.restaurantName} ← ${o.deliveryAddress}',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  foregroundColor: Colors.white,
                ),
                onPressed: widget.onReject,
                child: Text(tr('رفض', 'Reject')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.warning,
                ),
                onPressed: widget.onAccept,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(tr('قبول العرض', 'Accept offer'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _MyOrdersTab extends StatelessWidget {
  final String driverId;
  final Driver? driver;
  final void Function(List<Order> orders) onOrdersChanged;
  final void Function(List<Order> orders) onLoadChanged;
  const _MyOrdersTab({
    required this.driverId,
    this.driver,
    required this.onOrdersChanged,
    required this.onLoadChanged,
  });

  /// تبديل الاتصال برسالة صريحة (نمط نينجا): «متاح — بالتوفيق» أو «لن تصلك
  /// طلبات» — تأكيدٌ يقطع الشك بدل مفتاح صامت قد لا يلحظ أثره.
  Future<void> _toggleOnline(
      BuildContext context, FirebaseService service, bool goOnline) async {
    HapticFeedback.mediumImpact();
    await service.setDriverOnline(driverId, goOnline);
    if (context.mounted) {
      showSuccess(
          context,
          goOnline
              ? tr('أنت الآن متاح لاستقبال الطلبات — بالتوفيق! 🚀',
                  'You are now available for orders — good luck! 🚀')
              : tr('أصبحت غير متصل — لن تصلك طلبات جديدة',
                  'You are now offline — no new orders will reach you'));
    }
    // نصيحة البطارية عند أول اتصال في عمر التثبيت — هنا لا عند فتح
    // التطبيق: لحظة «متصل» هي اللحظة التي يصير فيها بقاء العملية حيّةً
    // مصلحةً مباشرة للكابتن، فالنص يُقرأ لا يُمرَّر.
    if (goOnline && context.mounted) {
      await showBatteryAdviceOnce(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final isOnline = driver?.isOnline ?? false;

    // زر الحالة البارز (نمط تويو): مفتاح شريط العنوان الصغير يفوت سائقاً
    // مستعجلاً، وهذه البطاقة أول ما تقع عليه عينه — بلونٍ حاسم ونص يشرح
    // أثر الحالة لا اسمها فقط.
    final statusCard = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: driver == null
              ? null
              : () => _toggleOnline(context, service, !isOnline),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isOnline
                    ? [AppColors.success, const Color(0xFF1B7A43)]
                    : [const Color(0xFF616E7C), const Color(0xFF3E4C59)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(isOnline ? Icons.wifi_tethering_rounded : Icons.power_settings_new_rounded,
                  color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          isOnline
                              ? tr('متاح لاستقبال الطلبات', 'Available for orders')
                              : tr('غير متصل', 'Offline'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5)),
                      Text(
                          isOnline
                              ? tr('تصلك العروض تلقائياً — اضغط للتوقف',
                                  'Offers reach you automatically — tap to go offline')
                              : tr('لن تصلك طلبات — اضغط للاتصال',
                                  'No orders will reach you — tap to go online'),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11.5)),
                    ]),
              ),
              Switch(
                value: isOnline,
                onChanged: driver == null
                    ? null
                    : (v) => _toggleOnline(context, service, v),
                activeColor: Colors.white,
                activeTrackColor: Colors.white38,
              ),
            ]),
          ),
        ),
      ),
    );

    // شاشة «نمط أوبر» (قرار المالك ٢٠٢٦-٠٨-١٠): الخريطة هي الشاشة —
    // الكابتن يرى موقعه ومسافة العرض بعينه لا رقماً مجرداً — وبطاقة
    // الحالة تطفو فوقها، والطلبات في لوح سحبٍ سفلي يبقى بمتناول الإبهام.
    return AppStreamBuilder<List<Order>>(
      stream: () => service.streamDriverOrders(driverId),
      builder: (ctx, all) {
        final active = all.where((o) => o.status.isActive).toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onOrdersChanged(active);
          onLoadChanged(active);
        });

        final confirmedActive =
            active.where((o) => !o.needsDriverAcknowledgement).toList();
        // العروض المعلّقة تظهر **في القائمة** لا في الشريط الطافي وحده
        // (بلاغ المالك ٢٠٢٦-٠٨-١١: طلبات لم تصل الكابتن): الشريط يعيش ٤٥
        // ثانية وداخل التطبيق المفتوح فقط، وبلا إشعارات خادم (المسار د) فإن
        // كان الهاتف في الجيب فات العرضُ بلا أثر — والطلب كان مخفياً عن
        // قائمته أصلاً لأنه «غير مُقَر». الآن يبقى العرض ظاهراً بقراره.
        final pendingOffers =
            active.where((o) => o.needsDriverAcknowledgement).toList();

        return Stack(children: [
          Positioned.fill(
            child: _DriverMap(driver: driver, orders: confirmedActive),
          ),
          Positioned(top: 0, left: 0, right: 0, child: statusCard),
          // اللوح السفلي: يبدأ بثلث الشاشة ويُسحب حتى 85% — لا يغطي
          // الخريطة كلياً أبداً فلا يعود «قائمة على أبيض» من جديد.
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.18,
            maxChildSize: 0.85,
            snap: true,
            builder: (context, scroll) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(color: Color(0x33000000), blurRadius: 14),
                ],
              ),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  if (pendingOffers.isNotEmpty) ...[
                    SectionHeader(
                        title: tr('عروض بانتظار قرارك', 'Offers awaiting your decision')),
                    ...pendingOffers.map(
                        (o) => _PendingOfferCard(key: ValueKey(o.id), order: o)),
                    const SizedBox(height: 6),
                  ],
                  if (confirmedActive.isEmpty && pendingOffers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      child: Column(children: [
                        Text(isOnline ? '📦' : '🔌',
                            style: const TextStyle(fontSize: 40)),
                        const SizedBox(height: 10),
                        Text(tr('لا توجد طلبات نشطة حالياً', 'No active orders right now'),
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(
                          isOnline
                              ? tr('سيصلك عرض بأي طلب جديد فور توفره',
                                  'An offer will reach you as soon as a new order is available')
                              : tr('اتصل أولاً ليصلك أي عرض',
                                  'Go online first to receive offers'),
                          style: const TextStyle(
                              fontSize: 13.5, color: AppColors.textGray),
                        ),
                      ]),
                    )
                  else if (confirmedActive.isNotEmpty) ...[
                    SectionHeader(title: tr('طلباتي', 'My orders')),
                    ...confirmedActive.map((o) => _OrderCard(order: o)),
                  ],
                ],
              ),
            ),
          ),
        ]);
      },
    );
  }
}

/// خريطة خلفية شاشة الكابتن: موقعه الحي، ودبابيس طلبه النشط (المطعم
/// والعميل) مع خط المسار. التمركز الأولي على موقعه المعروف، وزر التمركز
/// يقرأ GPS طازجاً — أما تحديث الموقع على الخريطة فيتبع مستند السائق
/// نفسه، فلا نضيف أي قراءة GPS أو كتابة Firestore جديدة على خنق الموقع
/// القائم (450 كتابة/ساعة كانت الدرس).
class _DriverMap extends StatefulWidget {
  final Driver? driver;
  final List<Order> orders;
  const _DriverMap({required this.driver, required this.orders});

  @override
  State<_DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<_DriverMap> {
  final _mapController = MapController();

  /// مركز الرياض — بداية معقولة لسائق جديد لم يُسجَّل له موقع بعد.
  static const _fallbackCenter = LatLng(24.7136, 46.6753);

  LatLng get _driverPoint {
    final d = widget.driver;
    if (d?.lat != null && d?.lng != null) return LatLng(d!.lat!, d.lng!);
    return _fallbackCenter;
  }

  Future<void> _recenter() async {
    // GPS طازج إن تيسّر خلال ٤ ثوانٍ، وإلا فآخر موقع معروف — زرٌّ يجب
    // أن يستجيب دائماً لا أن يعلّق بانتظار قمر صناعي داخل مبنى.
    var target = _driverPoint;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      target = LatLng(pos.latitude, pos.longitude);
    } catch (_) {}
    if (mounted) _mapController.move(target, 15.5);
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;

    final markers = <Marker>[
      Marker(
        point: _driverPoint,
        width: 46,
        height: 46,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: fc.primary.withOpacity(0.45),
                  blurRadius: 14,
                  spreadRadius: 3),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: fc.primary),
            child: const Icon(Icons.delivery_dining,
                color: Colors.white, size: 22),
          ),
        ),
      ),
    ];
    final lines = <Polyline>[];

    for (final o in widget.orders) {
      final hasR = o.restaurantLat != null && o.restaurantLng != null;
      final hasD = o.deliveryLat != null && o.deliveryLng != null;
      if (hasR) {
        markers.add(Marker(
          point: LatLng(o.restaurantLat!, o.restaurantLng!),
          width: 56,
          height: 56,
          child: const _MapPin(icon: Icons.restaurant, color: Colors.orange),
        ));
      }
      if (hasD) {
        markers.add(Marker(
          point: LatLng(o.deliveryLat!, o.deliveryLng!),
          width: 56,
          height: 56,
          child:
              const _MapPin(icon: Icons.location_on, color: AppColors.error),
        ));
      }
      if (hasR || hasD) {
        lines.add(Polyline(
          points: [
            _driverPoint,
            if (hasR) LatLng(o.restaurantLat!, o.restaurantLng!),
            if (hasD) LatLng(o.deliveryLat!, o.deliveryLng!),
          ],
          strokeWidth: 4,
          color: fc.primary.withOpacity(0.75),
        ));
      }
    }

    return Stack(children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: _driverPoint, initialZoom: 14.5),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.zadam.delivery',
          ),
          if (lines.isNotEmpty) PolylineLayer(polylines: lines),
          MarkerLayer(markers: markers),
          const OsmAttribution(),
        ],
      ),
      // فوق اللوح السفلي في وضعه الأدنى (18%) بهامش أمان.
      PositionedDirectional(
        bottom: MediaQuery.of(context).size.height * 0.20 + 12,
        end: 14,
        child: FloatingActionButton.small(
          heroTag: 'driver_recenter',
          backgroundColor: Colors.white,
          onPressed: _recenter,
          child: Icon(Icons.my_location, color: fc.primary),
        ),
      ),
    ]);
  }
}

/// دبوس خريطة موحّد — نفس شكل دبابيس خريطة تتبع العميل فلا تختلف لغة
/// الخرائط بين التطبيقين.
class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MapPin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 6),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        Container(
          width: 3,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ]);
}

/// بطاقة عرض معلّق داخل القائمة — النسخة الدائمة من الشريط الطافي: لا
/// تختفي بانقضاء ٤٥ ثانية ولا تحتاج التطبيق مفتوحاً لحظة الإسناد، فالعرض
/// يبقى حتى يقرّر الكابتن. بنفس معلومات القرار: أجرته، ومبلغ التحصيل
/// كاملاً إن كان نقدياً، والمسار.
class _PendingOfferCard extends StatefulWidget {
  final Order order;
  const _PendingOfferCard({super.key, required this.order});

  @override
  State<_PendingOfferCard> createState() => _PendingOfferCardState();
}

class _PendingOfferCardState extends State<_PendingOfferCard> {
  bool _busy = false;

  // مهلة القرار المستقلّة لكل عرض (دفعة ١، عطل السباق ٢): كان العرض الوحيد
  // يملك مؤقّتاً في الشريط الطافي، فإن جاء عرضٌ ثانٍ أزاح الأول (خانةُ الشريط
  // واحدة) فمات مؤقّته ولم ينقضِ أبداً — طلبٌ عالقٌ عند سائقٍ لا ينتبه له.
  // الآن **كل بطاقة عرض** تملك عدّادها الخاص فتُمرّر نفسها تلقائياً عند
  // انقضاء المهلة، والبطاقة هي **صاحبة القرار الوحيد** (الشريط صار تنبيهاً
  // بصرياً لا يعيد الإسناد) فلا إسنادٌ مزدوج للعرض الأحدث.
  static const int _offerSeconds = 45;
  int _secondsLeft = _offerSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _expire();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _expire() async {
    if (_busy) return;
    // انقضت المهلة: يُمرَّر لأقرب سائق آخر تلقائياً؛ وإن لم يوجد بديل بقي
    // العرض قائماً (dueToTimeout) بدل أن يُجرَّد الطلب من سائقه فيصير يتيماً.
    final service = context.read<FirebaseService>();
    try {
      await service.rejectAssignedOrder(widget.order.id, dueToTimeout: true);
      LocalAlerts.clearOfferAlert();
    } catch (_) {
      // قد يكون قُبل أو أُلغي في هذه الأثناء — لا إزعاج.
    }
  }

  Future<void> _decide(bool accept) async {
    if (_busy) return;
    _timer?.cancel(); // القرار اليدوي يوقف العدّاد فلا ينقضي بعده
    setState(() => _busy = true);
    final service = context.read<FirebaseService>();
    try {
      if (accept) {
        await service.acceptAssignedOrder(widget.order.id);
              LocalAlerts.clearOfferAlert();
        if (mounted) {
          navigatorKey.currentState?.push(MaterialPageRoute(
              builder: (_) => PickupDocketScreen(orderId: widget.order.id)));
        }
      } else {
        await service.rejectAssignedOrder(widget.order.id);
      }
    } catch (_) {
      if (mounted) {
        showError(
            context,
            tr('تعذّر تنفيذ القرار — ربما تغيّرت حالة الطلب',
                'Could not apply your decision — the order status may have changed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final isCash = o.paymentMethod == PaymentMethod.cash;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning, width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_shipping_rounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                tr('عرض توصيل — طلب #${o.orderNumber}',
                    'Delivery offer — order #${o.orderNumber}'),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: Color(0xFF8A6508))),
          ),
          // عدّاد المهلة (عطل السباق ٢): يحمرّ في آخر ١٠ ثوانٍ حثّاً على القرار.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (_secondsLeft <= 10 ? AppColors.error : AppColors.warning)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
                tr('${_secondsLeft > 0 ? _secondsLeft : 0} ث',
                    '${_secondsLeft > 0 ? _secondsLeft : 0} s'),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: _secondsLeft <= 10
                        ? AppColors.error
                        : const Color(0xFF8A6508))),
          ),
        ]),
        const SizedBox(height: 8),
        if (isCash)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
                tr('نقدي — تستلم من العميل ${formatCurrency(o.cashDueFromCustomer)}',
                    'Cash — you collect ${formatCurrency(o.cashDueFromCustomer)} from the customer'),
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        Text(
            tr('أجرتك ${formatCurrency(o.driverShare)}',
                'Your fee ${formatCurrency(o.driverShare)}'),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('${o.restaurantName} ← ${o.deliveryAddress}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _decide(false),
              child: Text(tr('رفض', 'Reject')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
              onPressed: _busy ? null : () => _decide(true),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(tr('قبول العرض', 'Accept offer'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// سطر «زمن الطلب» — يعيد بناء نفسه كل دقيقة فيبقى العمر صادقاً بلا تحديث
/// يدوي، ويحمرّ بعد نصف ساعة: طلبٌ تجاوزها يستحق استعجالاً أو اتصالاً.
class _AgeRow extends StatefulWidget {
  final DateTime createdAt;
  const _AgeRow({required this.createdAt});

  @override
  State<_AgeRow> createState() => _AgeRowState();
}

class _AgeRowState extends State<_AgeRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
        const Duration(minutes: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.createdAt;
    final clock =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final age = DateTime.now().difference(t);
    final late = age.inMinutes >= 30;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(late ? Icons.timer_off_outlined : Icons.schedule_rounded,
            size: 15, color: late ? AppColors.error : AppColors.textGray),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr('وقت الطلب $clock — منذ ${formatRemaining(age)}',
                'Ordered at $clock — ${formatRemaining(age)} ago'),
            style: TextStyle(
                fontSize: 13.5,
                color: late ? AppColors.error : AppColors.textGray,
                fontWeight: late ? FontWeight.w700 : FontWeight.normal),
          ),
        ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  /// يفتح الملاحة الخارجية نحو وجهة المرحلة. الإحداثيات من لقطة الطلب —
  /// وهي محدَّثة لأن تعديل المدير للموقع ينشرها على الطلبات الجارية.
  Future<void> _navigate(BuildContext context) async {
    final toCustomer = order.status == OrderStatus.pickedUp ||
        order.status == OrderStatus.onTheWay;
    final lat = toCustomer ? order.deliveryLat : order.restaurantLat;
    final lng = toCustomer ? order.deliveryLng : order.restaurantLng;
    if (lat == null || lng == null) {
      showError(
          context,
          toCustomer
              ? tr('لا يوجد موقع محفوظ للعميل', 'No saved location for the customer')
              : tr('لا يوجد موقع محفوظ للمطعم', 'No saved location for the restaurant'));
      return;
    }
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        showError(context,
            tr('تعذّر فتح تطبيق الخرائط', 'Could not open the maps app'));
      }
    }
  }

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
                tooltip: tr('الاتصال بالعميل', 'Call the customer'),
              ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.secondary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderChatScreen(order: order))),
            ),
            // ملاحة خارجية مباشرة (بلاغ المالك: «لا أستطيع التوجه للمطعم
            // إلا بالخريطة الداخلية»): زرٌّ يفتح خرائط جوجل فوراً نحو
            // الوجهة الصحيحة بحسب المرحلة — المطعم قبل الاستلام والعميل
            // بعده — بلا مرور بشاشة الخريطة ثم زر «ابدأ الملاحة».
            IconButton(
              tooltip: order.status == OrderStatus.pickedUp ||
                      order.status == OrderStatus.onTheWay
                  ? tr('الملاحة إلى العميل', 'Navigate to customer')
                  : tr('الملاحة إلى المطعم', 'Navigate to restaurant'),
              icon: const Icon(Icons.navigation_rounded,
                  color: AppColors.primary),
              onPressed: () => _navigate(context),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, color: AppColors.secondary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderMapScreen(order: order, readOnly: false))),
            ),
            // ✅ زر الشكوى — يفتح شاشة تقديم شكوى مشتركة، مع تحديد السائق
            // كمُقدِّم الشكوى (submittedByRole: driver) لتظهر له خيارات
            // "ضد العميل" أو "ضد المطعم" فقط (لا يمكنه الشكوى ضد نفسه).
            // يختفي في لحظة انتهاء مهلة الشكوى (24 ساعة من إنهاء الطلب)،
            // والمتبقّي في التلميح — والساعات الثلاث الأخيرة بالأحمر.
            ComplaintWindow(
              order: order,
              builder: (context, left, canSubmit) {
                if (!canSubmit) return const SizedBox.shrink();
                final urgent = left != null && left.inHours < 3;
                return IconButton(
                  icon: Icon(
                      urgent
                          ? Icons.timer_outlined
                          : Icons.report_problem_outlined,
                      color: urgent ? AppColors.error : AppColors.warning),
                  tooltip: left == null
                      ? tr('تقديم شكوى', 'File a complaint')
                      : tr('تقديم شكوى — يتبقّى ${formatRemaining(left)}',
                          'File a complaint — ${formatRemaining(left)} left'),
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
                );
              },
            ),
            StatusBadge(label: order.status.label, color: order.status.color, icon: order.status.icon),
          ]),
          const SizedBox(height: 10),
          InfoRow(icon: Icons.restaurant_outlined, text: order.restaurantName),
          InfoRow(icon: Icons.person_outline, text: '${order.customerName} — ${order.customerPhone}'),
          InfoRow(icon: Icons.location_on_outlined, text: order.deliveryAddress),
          // زمن الطلب (بلاغ المالك ٢٠٢٦-٠٨-١١): البطاقة كانت بلا أي وقت،
          // فلا يعرف الكابتن أطلبٌ للتوّ أم ينتظر نصف ساعة — وهو أول ما
          // يرتّب به أولوياته حين يحمل أكثر من طلب. الساعة **وعمر الطلب**
          // معاً: الساعة وحدها تحتاج حساباً ذهنياً، والعمر وحده يضيع منه
          // وقت الاستلام حين يراجع.
          _AgeRow(createdAt: order.createdAt),
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(formatCurrency(order.payableTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
            Text(order.paymentMethod.label, style: const TextStyle(color: AppColors.textGray, fontSize: 12.5)),
          ]),
          const SizedBox(height: 12),
          _buildAction(context, service),
        ]),
      ),
    );
  }

  Widget _buildAction(BuildContext ctx, FirebaseService service) {
    // المذكرة تبقى في متناوله من لحظة الإسناد لا من لحظة الجهوزية فقط
    // (طلب المالك ٢٠٢٦-٠٨-١١، نمط تويو): الكابتن يفتحها ليقرأ الأصناف
    // ومبلغ التحصيل ويتحرك نحو المطعم قبل أن يجهز الطعام — وحجبها كان
    // يتركه بسطرٍ نصّي واحد بلا أي فعل ممكن.
    if (order.status == OrderStatus.restaurantPending ||
        order.status == OrderStatus.restaurantAccepted ||
        order.status == OrderStatus.preparing) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            tr('الطلب قيد التحضير عند المطعم — سنُعلمك فور جهوزيته',
                'The restaurant is preparing the order — we will notify you once it is ready'),
            style: const TextStyle(
                color: AppColors.textGray, fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => navigatorKey.currentState?.push(MaterialPageRoute(
              builder: (_) => PickupDocketScreen(orderId: order.id))),
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: Text(tr('مذكرة الاستلام', 'Pickup memo')),
        ),
      ]);
    }
    if (order.status == OrderStatus.readyForPickup ||
        order.status == OrderStatus.searchingDriver ||
        order.status == OrderStatus.driverAssigned) {
      // مذكرة الاستلام هي مركز ما قبل الاستلام كله: رقم الطلب الضخم
      // للمطابقة أمام المطعم، الأصناف، شريط الدفع، وأزرار «وصلتُ» و«استلمت»
      // بحارس النطاق والعُهدة — بدل توزيعها أزراراً متفرقة على البطاقة.
      return SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () => navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => PickupDocketScreen(orderId: order.id))),
        icon: const Icon(Icons.receipt_long_rounded),
        label: Text(tr('مذكرة الاستلام — اعرضها للمطعم',
            'Pickup memo — show it to the restaurant')),
      ));
    }
    if (order.status == OrderStatus.onTheWay) {
      return SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () async {
          final done = await DriverProofFlow.confirmDelivery(ctx, service, order);
          if (done && ctx.mounted) {
            // النقدي: أجرته ضمن النقد الذي بيده لا قيداً في المحفظة —
            // رسالة «+أرباح» كانت ستوهمه بإضافة لن يجدها في سجلّه.
            showSuccess(
                ctx,
                order.paymentMethod == PaymentMethod.cash
                    ? tr('تم التوصيل! أجرتك ${order.driverShare.toStringAsFixed(2)} ر.س ضمن المبلغ الذي حصّلته',
                        'Delivered! Your ${order.driverShare.toStringAsFixed(2)} SAR fee is part of the cash you collected')
                    : tr('تم التوصيل! +${order.driverShare.toStringAsFixed(2)} ر.س أُضيفت لمحفظتك',
                        'Delivered! +${order.driverShare.toStringAsFixed(2)} SAR added to your wallet'));
          }
        },
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
        icon: const Icon(Icons.done_all_rounded),
        label: Text(tr('تأكيد التوصيل', 'Confirm delivery')),
      ));
    }
    return const SizedBox.shrink();
  }
}

class _DriverEarningsTab extends StatefulWidget {
  final Driver? driver;
  const _DriverEarningsTab({this.driver});

  @override
  State<_DriverEarningsTab> createState() => _DriverEarningsTabState();
}

/// مجموعات فلترة سجلّ الحركات — قائمة مسطحة واحدة كانت تخلط عُهدة الطلبات
/// بإيداعات الإدارة فيضيع تتبّع أي خانة (نمط فلاتر تويو: طلبات/مكافآت/...).
enum _TxFilter { all, orders, bonuses, settlements, adjustments }

class _DriverEarningsTabState extends State<_DriverEarningsTab> {
  _TxFilter _filter = _TxFilter.all;

  bool _txMatches(DriverTransaction tx) => switch (_filter) {
        _TxFilter.all => true,
        _TxFilter.orders => const {
            DriverTransactionType.orderCustody,
            DriverTransactionType.custodyReversal,
            DriverTransactionType.deliveryCash,
            DriverTransactionType.deliveryOnline,
          }.contains(tx.type),
        _TxFilter.bonuses => tx.type == DriverTransactionType.bonus,
        _TxFilter.settlements => tx.type == DriverTransactionType.deposit ||
            tx.type == DriverTransactionType.payout,
        _TxFilter.adjustments => tx.type == DriverTransactionType.adjustment,
      };

  @override
  Widget build(BuildContext context) {
    if (widget.driver == null) return const AppLoading();
    final d = widget.driver!;
    // الرصيد بإشارة: سالب يعني أن بيد السائق مالاً ليس له (حصيلة الطلبات
    // النقدية)، وموجب يعني أن للتطبيق مستحقّات عليه للسائق. عرضه برقم مجرّد
    // كان سيوهم السائق بأن الدَّين ربح.
    final owesPlatform = d.balance < 0;
    final amount = d.balance.abs();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // الأحمر الدلالي عند الدَّين يتقدّم على هوية النكهة — إشارة مالية
          // لا زخرفة؛ وفي الحالة الطبيعية تدرّج أزرق الكابتن.
          gradient: LinearGradient(
            colors: owesPlatform
                ? [AppColors.error, const Color(0xFFB71C1C)]
                : [context.flavorColors.primary, context.flavorColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(
                owesPlatform
                    ? tr('محفظتك — مبلغ عليك', 'Your wallet — amount you owe')
                    : tr('محفظتك — رصيدك', 'Your wallet — your balance'),
                style: const TextStyle(color: Colors.white70, fontSize: 14.5)),
          ]),
          const SizedBox(height: 6),
          Text(formatCurrency(amount),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            owesPlatform
                ? tr('عُهدة طلبات نقدية بيدك — تُسدَّد بالشحن أو التسليم للإدارة',
                    'Cash in hand from cash orders — settle by top-up or handing it to the office')
                : tr('مستحقّاتك من الطلبات المدفوعة إلكترونياً',
                    'Your dues from orders paid online'),
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Row(children: [
            // الفعل يتبع إشارة الرصيد: مدينٌ للتطبيق → يشحن؛ دائنٌ له →
            // يسحب مستحقّاته بنفسه (نمط نينجا/تويو) بدل انتظار الإدارة.
            Expanded(
              child: d.balance > 0
                  ? ElevatedButton.icon(
                      onPressed: () => _showWithdrawSheet(context, d),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: context.flavorColors.primaryDark,
                      ),
                      icon: const Icon(Icons.savings_rounded, size: 18),
                      label: Text(tr('اسحب أموالي', 'Withdraw my money'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _showTopUpSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: owesPlatform
                            ? AppColors.error
                            : context.flavorColors.primaryDark,
                      ),
                      icon: const Icon(Icons.add_card_rounded, size: 18),
                      label: Text(tr('شحن المحفظة', 'Top up wallet'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: tr('كيف تعمل المحفظة؟', 'How does the wallet work?'),
              onPressed: () => _showHowItWorksSheet(context),
              icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
            ),
          ]),
        ]),
      ),
      // حالة آخر طلب سحب — يظهر ما دام قيد المعالجة، وبعد البتّ لأسبوع
      // (ليقرأ السائق سبب الرفض أو تأكيد الصرف) ثم يختفي تلقائياً.
      AppStreamBuilder<List<PayoutRequest>>(
        stream: () =>
            context.read<FirebaseService>().streamMyPayoutRequests(d.id),
        loading: const SizedBox.shrink(),
        builder: (ctx, requests) {
          if (requests.isEmpty) return const SizedBox.shrink();
          final r = requests.first;
          final recent = r.processedAt == null ||
              DateTime.now().difference(r.processedAt!).inDays < 7;
          if (r.status != PayoutRequestStatus.pending && !recent) {
            return const SizedBox.shrink();
          }
          final (color, icon) = switch (r.status) {
            PayoutRequestStatus.pending => (
                AppColors.warning,
                Icons.hourglass_top_rounded
              ),
            PayoutRequestStatus.paid => (
                AppColors.success,
                Icons.check_circle_outline_rounded
              ),
            PayoutRequestStatus.rejected => (
                AppColors.error,
                Icons.cancel_outlined
              ),
          };
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Row(children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            tr('طلب سحب ${formatCurrency(r.amount)} — ${r.status.label}',
                                'Withdrawal request ${formatCurrency(r.amount)} — ${r.status.label}'),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: color)),
                        if ((r.adminNote ?? '').isNotEmpty)
                          Text(r.adminNote!,
                              style: const TextStyle(fontSize: 11.5)),
                      ]),
                ),
              ]),
            ),
          );
        },
      ),
      // لا تنبيه دَين هنا: كفاية رصيد السائق لتغطية عُهد طلباته اتفاقٌ
      // تشغيلي بينه وبين الإدارة خارج التطبيق (قرار المالك) — فالتطبيق
      // يعرض رصيده وحركاته بشفافية ولا يُملي عليه قاعدة ولا يطالبه.
      const SizedBox(height: 14),
      // دخل اليوم والأسبوع (نمط مركز دخل تويو) — من الطلبات المُسلَّمة لا من
      // دفتر الحركات: أجرة الطلب النقدي تبقى بيد السائق ولا تمرّ بالدفتر
      // أصلاً، فجمع الدفتر وحده كان سيُظهر دخلاً أنقص من الحقيقة.
      AppStreamBuilder<List<Order>>(
        stream: () =>
            context.read<FirebaseService>().streamDriverOrders(d.id),
        builder: (ctx, orders) {
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final weekStart = todayStart.subtract(const Duration(days: 6));
          double today = 0, week = 0;
          int todayCount = 0, weekCount = 0;
          for (final o in orders) {
            if (o.status != OrderStatus.delivered) continue;
            final t = o.statusChangedAt ?? o.updatedAt ?? o.createdAt;
            if (!t.isBefore(weekStart)) {
              // الإكرامية دخلٌ للكابتن كاملة (ح3) — تُجمع مع الأجرة.
              week += o.driverShare + o.driverTip;
              weekCount++;
              if (!t.isBefore(todayStart)) {
                today += o.driverShare + o.driverTip;
                todayCount++;
              }
            }
          }
          // المكافآت تُحسب في الدخل (نفذ ٣): كانت تظهر سطراً في الدفتر
          // فقط، فمكافأة ٥٠ ر.س لا تحرّك «دخل اليوم» — والسائق يقيس
          // يومه بهذا الرقم لا بسطور الدفتر. تُجمع من نفس دفتر الحركات
          // (نوع bonus وحده) على نفس النافذتين الزمنيتين.
          return AppStreamBuilder<List<DriverTransaction>>(
            stream: () => context
                .read<FirebaseService>()
                .streamDriverTransactions(d.id),
            loading: const SizedBox.shrink(),
            builder: (ctx2, txs) {
              double bonusToday = 0, bonusWeek = 0;
              for (final tx in txs) {
                if (tx.type != DriverTransactionType.bonus) continue;
                if (!tx.createdAt.isBefore(weekStart)) {
                  bonusWeek += tx.amount.abs();
                  if (!tx.createdAt.isBefore(todayStart)) {
                    bonusToday += tx.amount.abs();
                  }
                }
              }
              return Column(children: [
                Row(children: [
                  Expanded(
                      child: _incomeCard(tr('دخل اليوم', "Today's income"),
                          today + bonusToday,
                          todayCount, Icons.today_rounded,
                          context.flavorColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _incomeCard(tr('آخر ٧ أيام', 'Last 7 days'),
                          week + bonusWeek,
                          weekCount, Icons.date_range_rounded,
                          AppColors.success)),
                ]),
                if (bonusWeek > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      tr(
                          'منها مكافآت: ${formatCurrency(bonusWeek)} هذا الأسبوع'
                          '${bonusToday > 0 ? " (${formatCurrency(bonusToday)} اليوم)" : ""} 🎁',
                          'Includes bonuses: ${formatCurrency(bonusWeek)} this week'
                          '${bonusToday > 0 ? " (${formatCurrency(bonusToday)} today)" : ""} 🎁'),
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textGray),
                    ),
                  ),
              ]);
            },
          );
        },
      ),
      const SizedBox(height: 14),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
        _stat(tr('التوصيلات', 'Deliveries'), '${d.totalDeliveries}', Icons.local_shipping_outlined, context.flavorColors.primary),
        _stat(tr('استلمته فعلياً', 'Actually received'), formatCurrency(d.totalEarnings), Icons.savings_outlined, AppColors.success),
        _stat(tr('التقييم', 'Rating'), d.rating.toStringAsFixed(1), Icons.star_rounded, Colors.amber),
        // معدل القبول (نمط تويو) — من عدّادات المستند الدائمة، و«—» قبل
        // أول عرض حتى لا يظهر صفر ظالم.
        _stat(
            tr('معدل القبول', 'Acceptance rate'),
            d.acceptanceRate == null
                ? '—'
                : tr('${(d.acceptanceRate! * 100).round()}٪',
                    '${(d.acceptanceRate! * 100).round()}%'),
            Icons.thumb_up_alt_outlined,
            (d.acceptanceRate ?? 1) >= 0.8
                ? AppColors.success
                : AppColors.warning),
      ]),
      const SizedBox(height: 12),
      // الإحالة والتحدي — بمبالغ وشروط الإدارة اللحظية لا أرقام مبرمَجة،
      // فما يراه السائق هو ما سيُصرف له فعلاً.
      _IncentivesCards(driver: d),
      const SizedBox(height: 8),
      Card(
        child: Column(children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline, size: 20),
            title: Text(tr('الملف الشخصي — الاسم والجوال', 'Profile — name & phone'),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_left_rounded, size: 20),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EditProfileScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.lock_outline, size: 20),
            title: Text(tr('تغيير كلمة المرور', 'Change password'),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_left_rounded, size: 20),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen())),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      SectionHeader(title: tr('سجلّ الحركات', 'Transaction log')),
      // فلاتر السجلّ — تصفية محلية على التدفّق القائم بلا استعلامات إضافية.
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (f, label) in [
              (_TxFilter.all, tr('الكل', 'All')),
              (_TxFilter.orders, tr('الطلبات', 'Orders')),
              (_TxFilter.bonuses, tr('مكافآت', 'Bonuses')),
              (_TxFilter.settlements, tr('إيداع وصرف', 'Deposits & payouts')),
              (_TxFilter.adjustments, tr('تسويات', 'Adjustments')),
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor:
                      context.flavorColors.primary.withOpacity(0.15),
                  backgroundColor: Colors.white,
                  // chipTheme العام بلا لون نص — بدون لون صريح ورثت التسميات
                  // أبيض فاختفت على الخلفية البيضاء (ملاحظة المالك بالصورة).
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    color: _filter == f
                        ? context.flavorColors.primaryDark
                        : AppColors.textDark,
                    fontWeight:
                        _filter == f ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 320,
        child: AppStreamBuilder<List<DriverTransaction>>(
          stream: () => context.read<FirebaseService>().streamDriverTransactions(d.id),
          builder: (ctx, txs) {
            final filtered = txs.where(_txMatches).toList();
            if (filtered.isEmpty) {
              return AppEmpty(
                  emoji: '🧾',
                  title: tr('لا توجد حركات هنا', 'No transactions here'));
            }
            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) => _TransactionTile(tx: filtered[i]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _incomeCard(
          String label, double amount, int count, IconData icon, Color color) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textGray)),
            ]),
            const SizedBox(height: 6),
            Text(formatCurrency(amount),
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            Text(tr('$count توصيلة', '$count deliveries'),
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.textGray)),
          ]),
        ),
      );

  Widget _stat(String label, String value, IconData icon, Color color) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 28),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 12.5)),
    ])));

  /// طلب سحب المستحقّات — السائق يحدّد المبلغ (حتى رصيده) وطريقة الاستلام،
  /// والإدارة تبتّ فيه من شاشتها. الخصم الفعلي يحدث عند الصرف لا هنا.
  void _showWithdrawSheet(BuildContext context, Driver d) {
    final amountCtrl =
        TextEditingController(text: d.balance.toStringAsFixed(2));
    final methodCtrl = TextEditingController();
    final service = context.read<FirebaseService>();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('طلب سحب المستحقّات', 'Withdrawal request'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    tr('رصيدك المتاح: ${formatCurrency(d.balance)}',
                        'Available balance: ${formatCurrency(d.balance)}'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textGray)),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr('المبلغ (ر.س)', 'Amount (SAR)'),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: methodCtrl,
                  decoration: InputDecoration(
                    labelText: tr('طريقة الاستلام', 'Payout method'),
                    hintText: tr('آيبان للتحويل، أو «نقداً من الإدارة»',
                        'IBAN for a transfer, or "cash from the office"'),
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: submitting
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(amountCtrl.text.trim()) ?? 0;
                            if (methodCtrl.text.trim().isEmpty) {
                              showError(sheetCtx,
                                  tr('اكتب طريقة الاستلام', 'Enter a payout method'));
                              return;
                            }
                            setSheetState(() => submitting = true);
                            try {
                              await service.submitPayoutRequest(
                                driverId: d.id,
                                driverName: d.name,
                                amount: amount,
                                method: methodCtrl.text,
                              );
                              if (sheetCtx.mounted) {
                                Navigator.pop(sheetCtx);
                                showSuccess(
                                    context,
                                    tr('أُرسل طلب السحب — ستجد نتيجته هنا في محفظتك',
                                        'Withdrawal request sent — you will find its result here in your wallet'));
                              }
                            } catch (e) {
                              setSheetState(() => submitting = false);
                              if (sheetCtx.mounted) {
                                showError(
                                    sheetCtx,
                                    e
                                        .toString()
                                        .replaceFirst('Exception: ', ''));
                              }
                            }
                          },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(submitting
                        ? tr('جارٍ الإرسال…', 'Sending…')
                        : tr('إرسال الطلب', 'Send request')),
                  ),
                ),
              ]),
        ),
      ),
    // ت٥٤: التخلّص من متحكّمَي الورقة بعد إغلاقها — كانا يتسرّبان مع
    // كل فتحٍ لطلب السحب.
    ).whenComplete(() {
      amountCtrl.dispose();
      methodCtrl.dispose();
    });
  }

  /// قنوات شحن المحفظة في المرحلة الحالية: تسليم نقدي أو تحويل بنكي تقيّده
  /// الإدارة. الشحن الذاتي بالبطاقة يُبنى لاحقاً على الخادم الموثوق —
  /// قيده من التطبيق مباشرةً كان سيسمح لنسخة معدَّلة بشحن بلا دفع.
  void _showTopUpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('شحن المحفظة', 'Top up wallet'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.payments_outlined, color: AppColors.primary),
              title: Text(tr('تسليم نقدي للإدارة', 'Cash handover to the office'),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  tr('سلّم المبلغ وتقيّده الإدارة فوراً — يظهر في سجلّك «شحن / إيداع»',
                      'Hand over the amount and the office records it immediately — it shows in your log as "Top-up / deposit"'),
                  style: const TextStyle(fontSize: 12.5)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_outlined, color: AppColors.primary),
              title: Text(tr('تحويل بنكي', 'Bank transfer'),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  tr('حوّل لحساب الإدارة ثم أرسل الإيصال لها ليُقيَّد الرصيد',
                      "Transfer to the office's account then send them the receipt so the balance is recorded"),
                  style: const TextStyle(fontSize: 12.5)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tr('الشحن المباشر بالبطاقة من داخل التطبيق قادم قريباً.',
                    'Direct card top-up from inside the app is coming soon.'),
                style: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showHowItWorksSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('كيف تعمل محفظتك؟', 'How does your wallet work?'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
                tr('📦  عند استلامك طلباً نقدياً من المطعم تُقيَّد قيمته على محفظتك '
                    '(عُهدة) — لأن الطلب صار بيدك حتى تسليمه.',
                    '📦  When you pick up a cash order from the restaurant, its value is '
                    'charged to your wallet (cash in hand) — the order is with you until delivery.'),
                style: const TextStyle(fontSize: 13.5, height: 1.7)),
            const SizedBox(height: 8),
            Text(
                tr('💵  عند تسليمه تقبض من العميل كامل المبلغ نقداً: قيمة الطلب '
                    'تسدّ العُهدة، وأجرة التوصيل ربحك تبقى بيدك.',
                    '💵  On delivery you collect the full amount in cash: the order value '
                    'clears the charge, and the delivery fee is your profit to keep.'),
                style: const TextStyle(fontSize: 13.5, height: 1.7)),
            const SizedBox(height: 8),
            Text(
                tr('💳  الطلبات المدفوعة إلكترونياً: لا عُهدة عليك، وتُضاف أجرتك '
                    'لرصيدك وتُصرف لك من الإدارة.',
                    '💳  Orders paid online: no cash in hand, your fee is added to your '
                    'balance and paid out by the office.'),
                style: const TextStyle(fontSize: 13.5, height: 1.7)),
            const SizedBox(height: 8),
            Text(
                tr('🚫  أُلغي الطلب بعد استلامك له؟ تُردّ العُهدة لمحفظتك تلقائياً.',
                    '🚫  Order canceled after you picked it up? The charge is reversed to your wallet automatically.'),
                style: const TextStyle(fontSize: 13.5, height: 1.7)),
            const SizedBox(height: 8),
            Text(
                tr('🧾  كل حركة مسجّلة في «سجلّ الحركات» برصيدك بعدها — '
                    'لا خصم ولا إضافة بلا سطر يفسّرها.',
                    '🧾  Every movement is recorded in the "Transaction log" with your balance after it — '
                    'no deduction or addition without a line explaining it.'),
                style: const TextStyle(fontSize: 13.5, height: 1.7)),
          ]),
        ),
      ),
    );
  }
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
      title: Text(tx.type.label, style: const TextStyle(fontSize: 13.5)),
      subtitle: Text(
        [
          if (tx.orderNumber != null)
            tr('طلب #${tx.orderNumber}', 'Order #${tx.orderNumber}'),
          if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
          '${tx.createdAt.day}/${tx.createdAt.month}',
        ].join(' • '),
        style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
      ),
      trailing: Text(
        '${positive ? '+' : '−'}${formatCurrency(tx.amount.abs())}',
        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13.5),
      ),
    );
  }
}

/// بطاقتا الحوافز في تبويب «أرباحي»: كود الإحالة ودعوة زميل، وتقدّم تحدي
/// نهاية الأسبوع.
///
/// كل الأرقام تأتي من إعدادات الإدارة اللحظية (IncentiveSettings) لا من
/// ثوابت في الكود — فلو رفع المالك مكافأة الإحالة اليوم رآها السائق فوراً
/// بلا تحديث للتطبيق، ولا يَعِد التطبيق بمبلغ يخالف ما سيُصرف.
///
/// البطاقتان تختفيان كلياً حين يوقف المالك البرنامج، فلا يبقى وعدٌ معلّق.
class _IncentivesCards extends StatelessWidget {
  final Driver driver;
  const _IncentivesCards({required this.driver});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<IncentiveSettings>(
      stream: service.streamIncentiveSettings,
      loading: const SizedBox.shrink(),
      builder: (ctx, s) => Column(children: [
        if (s.referralEnabled) _referralCard(context, s),
        if (s.referralEnabled && s.challengeEnabled)
          const SizedBox(height: 8),
        if (s.challengeEnabled) _challengeCard(context, s),
      ]),
    );
  }

  Widget _referralCard(BuildContext context, IncentiveSettings s) {
    final fc = context.flavorColors;
    final code = driver.referralCode;
    // الرابط يحمل الكود، فلا يعتمد وصول الإحالة على تذكّر المدعوّ كتابته:
    // يفتح صفحة التسجيل، يملأ بياناته ويرفق مستنداته، ويصل الكود معها.
    final link = s.inviteLinkFor(code);
    final invite = [
      tr('انضم لكباتن ZadGo — أجرة واضحة لكل طلب واشتراطات مرنة.',
          'Join ZadGo captains — a clear fee for every order and flexible requirements.'),
      if (link.isNotEmpty)
        tr('سجّل من هنا (المستندات تُرفع في الصفحة نفسها):\n$link',
            'Sign up here (documents are uploaded on the same page):\n$link')
      else
        tr('اكتب كود الدعوة «$code» عند التسجيل.',
            'Enter the invite code "$code" when signing up.'),
      tr('وتنال ${s.refereeBonus.toStringAsFixed(0)} ر.س ترحيباً بعد '
              '${s.referralDeliveries} توصيلة 🎁',
          'You get a ${s.refereeBonus.toStringAsFixed(0)} SAR welcome bonus after '
              '${s.referralDeliveries} deliveries 🎁'),
    ].join('\n');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: fc.primary.withOpacity(0.12),
              child: Icon(Icons.group_add_outlined, color: fc.primaryDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('ادعُ كابتناً واكسب', 'Invite a captain and earn'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text(
                        tr('لك ${s.referrerBonus.toStringAsFixed(0)} ر.س وله '
                                '${s.refereeBonus.toStringAsFixed(0)} ر.س — بعد إكماله '
                                '${s.referralDeliveries} توصيلة خلال '
                                '${s.referralWindowDays} يوماً',
                            '${s.referrerBonus.toStringAsFixed(0)} SAR for you and '
                                '${s.refereeBonus.toStringAsFixed(0)} SAR for them — after they complete '
                                '${s.referralDeliveries} deliveries within '
                                '${s.referralWindowDays} days'),
                        style: const TextStyle(fontSize: 11.5)),
                  ]),
            ),
          ]),
          const SizedBox(height: 10),
          // الكود هو مرجع الإحالة الوحيد — يُبرز ويُنسخ بضغطة، فلا يعتمد
          // البرنامج على تذكّر المدعوّ اسمَ من دعاه.
          Row(children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: fc.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: fc.primary.withOpacity(0.35)),
                ),
                child: Row(children: [
                  Text(tr('كودك:', 'Your code:'),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textGray)),
                  const SizedBox(width: 6),
                  Text(code,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: fc.primaryDark)),
                  const Spacer(),
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        showSuccess(
                            context, tr('نُسخ كودك', 'Your code was copied'));
                      }
                    },
                    child: const Icon(Icons.copy_outlined,
                        size: 18, color: AppColors.textGray),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => Share.share(invite),
              icon: const Icon(Icons.share_outlined, size: 17),
              label: Text(tr('دعوة', 'Invite')),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _challengeCard(BuildContext context, IncentiveSettings s) {
    final service = context.read<FirebaseService>();
    final now = DateTime.now();
    final window = s.currentWindow(now);
    final fc = context.flavorColors;

    // خارج أيام التحدي: تُعرض القاعدة مختصرةً كتشويق، بلا عدّاد كاذب.
    if (window == null) {
      return Card(
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.emoji_events_outlined,
              color: AppColors.textGray),
          title: Text(
              tr('تحدي ${s.weekdaysLabel}', '${s.weekdaysLabel} challenge'),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13.5)),
          subtitle: Text(
              s.tiers
                  .map((t) => tr(
                      '${t.deliveries} توصيلة = ${t.bonus.toStringAsFixed(0)} ر.س',
                      '${t.deliveries} deliveries = ${t.bonus.toStringAsFixed(0)} SAR'))
                  .join(' • '),
              style: const TextStyle(fontSize: 11.5)),
        ),
      );
    }

    final (start, end) = window;
    return AppStreamBuilder<List<Order>>(
      stream: () => service.streamDriverOrders(driver.id),
      loading: const SizedBox.shrink(),
      builder: (ctx, orders) {
        final count = orders
            .where((o) =>
                o.status == OrderStatus.delivered &&
                !o.createdAt.isBefore(start) &&
                !o.createdAt.isAfter(end))
            .length;
        final reached = s.tierFor(count);
        final next = s.nextTierFor(count);
        final target = next?.deliveries ?? reached?.deliveries ?? 1;
        final progress = (count / target).clamp(0.0, 1.0);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.emoji_events_rounded,
                    color: reached != null ? Colors.amber : fc.primary,
                    size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      tr('تحدي ${s.weekdaysLabel} — جارٍ الآن',
                          '${s.weekdaysLabel} challenge — live now'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                ),
                Text('$count',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: fc.primaryDark)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: fc.primary.withOpacity(0.12),
                  color: reached != null ? Colors.amber.shade700 : fc.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                next != null
                    ? tr('أنجزتَ $count — بقيت ${next.deliveries - count} توصيلة '
                            'لمكافأة ${next.bonus.toStringAsFixed(0)} ر.س',
                        'You did $count — ${next.deliveries - count} deliveries left '
                            'for a ${next.bonus.toStringAsFixed(0)} SAR bonus')
                    : tr('بلغتَ أعلى مستوى — مكافأة '
                            '${reached!.bonus.toStringAsFixed(0)} ر.س 🎉',
                        'You reached the top tier — a '
                            '${reached!.bonus.toStringAsFixed(0)} SAR bonus 🎉'),
                style: const TextStyle(fontSize: 12.5),
              ),
              if (reached != null) ...[
                const SizedBox(height: 4),
                Text(
                    tr('مستحقّ الآن: ${reached.bonus.toStringAsFixed(0)} ر.س — '
                            'تُضاف لدفترك بعد مراجعة الإدارة',
                        'Earned so far: ${reached.bonus.toStringAsFixed(0)} SAR — '
                            'added to your ledger after admin review'),
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.success,
                        fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 4),
              Text(
                  tr('المستويات: ${s.tiers.map((t) => '${t.deliveries}=${t.bonus.toStringAsFixed(0)}').join(' • ')}'
                          ' — تنتهي ${end.day}/${end.month}',
                      'Tiers: ${s.tiers.map((t) => '${t.deliveries}=${t.bonus.toStringAsFixed(0)}').join(' • ')}'
                          ' — ends ${end.day}/${end.month}'),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textGray)),
            ]),
          ),
        );
      },
    );
  }
}
