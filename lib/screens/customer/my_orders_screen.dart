// lib/screens/customer/my_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/route_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/reorder.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/app_skeletons.dart';
import '../../widgets/complaint_window.dart';
import 'order_receipt_screen.dart';
import 'order_map_screen.dart';
import 'order_chat_screen.dart';
import 'submit_complaint_screen.dart';
import 'cart_screen.dart';

/// شاشة طلبات العميل — مقسّمة إلى تبويبين: «جارية» للطلبات التي تحتاج متابعة
/// لحظية (خريطة/محادثة)، و«السابقة» كسجلّ للتصفّح. الفصل مقصود لأن غرض كل
/// مجموعة مختلف تماماً، فلا تُدفن متابعة طلب جارٍ خلف عشرات الطلبات المنتهية.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final uid = context.read<app_auth.AuthProvider>().user?.uid ?? '';

    return AppStreamBuilder<List<Order>>(
      stream: () => service.streamCustomerOrders(uid),
      loading: const ListCardsSkeleton(),
      builder: (ctx, orders) {
        if (orders.isEmpty) {
          return const AppEmpty(emoji: '📋', title: 'لا يوجد طلبات');
        }
        final active = orders.where((o) => o.status.isActive).toList();
        final past = orders.where((o) => !o.status.isActive).toList();

        return DefaultTabController(
          length: 2,
          initialIndex: active.isEmpty ? 1 : 0,
          child: Column(
            children: [
              TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textGray,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: active.isEmpty ? 'جارية' : 'جارية (${active.length})'),
                  const Tab(text: 'السابقة'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _OrdersList(
                      orders: active,
                      emptyTitle: 'لا يوجد طلبات جارية',
                      // أحدث طلب جارٍ يتصدّر ببطاقة تتبّع حيّة بدل بطاقة
                      // عادية: هذه أكثر شاشة يحدّق فيها العميل، وكانت
                      // تعطيه شريط مراحل مجرداً بينما وعدُ الصفحة الرئيسية
                      // «موقع مندوبك أولاً بأول».
                      heroFirst: true,
                    ),
                    _OrdersList(
                      orders: past,
                      emptyTitle: 'لا يوجد طلبات سابقة',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<Order> orders;
  final String emptyTitle;
  final bool heroFirst;
  const _OrdersList({
    required this.orders,
    required this.emptyTitle,
    this.heroFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return AppEmpty(emoji: '📋', title: emptyTitle);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, i) => heroFirst && i == 0
          ? _LiveTrackingCard(order: orders[i])
          : _OrderCard(order: orders[i]),
    );
  }
}

/// بطاقة التتبّع الحيّة — واجهة الانتظار بنمط التطبيقات العالمية.
///
/// المبدأ: المنتظِر لا يريد اسم حالة، يريد جواب ثلاثة أسئلة — **ماذا يحدث
/// الآن؟ وكم بقي؟ وأين مندوبي؟** فالبطاقة تجيبها بالترتيب:
///   • عنوان بشري بلغة الناس لا بمصطلح النظام.
///   • الوقت المتوقع **مدىً لا رقماً** (وعدٌ بدقيقة بعينها يُخلَف)، ولا
///     يظهر إلا بعد أن يتحرّك الكابتن فعلاً — قبلها تخمينٌ في وقت المطبخ.
///   • شريط طريق يتقدّم فيه رمز الكابتن بنسبة ما قطعه حقيقةً من إحداثياته.
///   • بطاقة الكابتن باسمه وتقييمه (إن قيّمه أحد) وزرَّي الاتصال والمحادثة.
///
/// بلا خريطة داخل البطاقة عمداً: بلاطات الخرائط حِملٌ ثقيل على شبكة جوّال
/// ضعيفة، ومن ينتظر لا يريد شكل الشوارع بل كم بقي — والخريطة الكاملة على
/// بُعد ضغطة لمن أرادها.
class _LiveTrackingCard extends StatelessWidget {
  final Order order;
  const _LiveTrackingCard({required this.order});

  /// ماذا يحدث الآن — بلغة الناس.
  (String, String) get _headline => switch (order.status) {
        OrderStatus.created ||
        OrderStatus.restaurantPending =>
          ('أرسلنا طلبك للمطعم', 'ننتظر تأكيده — عادةً خلال دقائق'),
        // دقائق التحضير (يوم المطعم): المطعم اختارها لحظة القبول، فتحلّ
        // محلّ العبارة العامة — جوابٌ حقيقي على «كم بقي؟» في وقت المطبخ
        // الذي كان أعمى قبل تحرّك الكابتن.
        OrderStatus.restaurantAccepted => (
            'المطعم قَبِل طلبك',
            order.prepMinutes != null
                ? 'التحضير يستغرق نحو ${order.prepMinutes} دقيقة'
                : 'سيبدأ التحضير الآن'
          ),
        OrderStatus.preparing => (
            'طلبك قيد التحضير',
            order.prepMinutes != null
                ? 'نحو ${order.prepMinutes} دقيقة في المطبخ 👨‍🍳'
                : 'رائحته تفوح من المطبخ 👨‍🍳'
          ),
        OrderStatus.readyForPickup ||
        OrderStatus.searchingDriver =>
          ('طلبك جاهز', 'نبحث عن كابتن قريب ليأخذه'),
        OrderStatus.driverAssigned =>
          ('الكابتن في طريقه للمطعم', 'سيستلم طلبك ثم ينطلق إليك'),
        OrderStatus.pickedUp ||
        OrderStatus.onTheWay =>
          ('الكابتن في الطريق إليك', 'استعدّ لاستلام طلبك 🛵'),
        _ => (order.status.label, ''),
      };

  /// نسبة ما قُطع من الطريق — من المسافتين الحقيقيتين لا من الحالة.
  double? _progress(Driver d) {
    if (order.restaurantLat == null ||
        order.deliveryLat == null ||
        d.lat == null ||
        d.lng == null) {
      return null;
    }
    final total = haversineDistanceKm(order.restaurantLat!,
        order.restaurantLng!, order.deliveryLat!, order.deliveryLng!);
    if (total <= 0.05) return 1;
    final left = haversineDistanceKm(
        d.lat!, d.lng!, order.deliveryLat!, order.deliveryLng!);
    return (1 - (left / total)).clamp(0.0, 1.0);
  }

  double? _remainingKm(Driver d) {
    if (order.deliveryLat == null || d.lat == null || d.lng == null) {
      return null;
    }
    return haversineDistanceKm(
        d.lat!, d.lng!, order.deliveryLat!, order.deliveryLng!);
  }

  /// مدى زمني من المسافة — بسرعة مدينية متحفّظة (٢٠ كم/س) وهامش ٥ دقائق
  /// للتسليم. مدىً لا رقم: الدقيقة الواحدة وعدٌ يُخلَف.
  String _eta(double km) {
    final mins = (km / 20 * 60).round();
    final lo = (mins + 2).clamp(3, 90);
    final hi = (mins + 8).clamp(6, 120);
    return '$lo–$hi دقيقة';
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final st = order.status;
    final (title, subtitle) = _headline;
    final hasDriver = (order.driverId ?? '').isNotEmpty;
    final moving =
        st == OrderStatus.pickedUp || st == OrderStatus.onTheWay;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [st.color.withOpacity(0.14), st.color.withOpacity(0.04)],
        ),
        border: Border.all(color: st.color.withOpacity(0.45), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // الطلب المجدول (ح4): موعده أهم معلومة في البطاقة قبل تحرّكه.
          if (order.isScheduled && order.status.index < OrderStatus.preparing.index) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.schedule_rounded,
                    size: 15, color: AppColors.primaryDark),
                const SizedBox(width: 6),
                Text('توصيلك مجدول: ${formatDateTime(order.scheduledFor!)}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark)),
              ]),
            ),
          ],
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: st.color.withOpacity(0.18)),
              child: Icon(st.icon, size: 20, color: st.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: st.color)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textGray)),
                  ]),
            ),
            Text('#${order.orderNumber}',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),

          // الجزء الحيّ — لا يُشترك في تدفّق السائق إلا عند وجوده فعلاً.
          if (hasDriver)
            StreamBuilder<Driver?>(
              stream: service.streamDriver(order.driverId!),
              builder: (ctx, snap) {
                final d = snap.data;
                if (d == null) return const SizedBox.shrink();
                final km = moving ? _remainingKm(d) : null;
                final p = moving ? _progress(d) : null;
                return Column(children: [
                  if (km != null)
                    // المسار الحقيقي (و3): زمن الطريق الفعلي من ORS حين
                    // يتوفر المفتاح، وإلا مدى الخط المستقيم كما كان —
                    // فالبطاقة لا تنتظر شبكةً لترسم، والرقم الأدق يحلّ
                    // محل التقديري لحظة وصوله.
                    FutureBuilder<RouteInfo?>(
                      future: RouteService.isConfigured
                          ? RouteService.drivingRoute(
                              fromLat: d.lat!, fromLng: d.lng!,
                              toLat: order.deliveryLat!,
                              toLng: order.deliveryLng!)
                          : Future.value(null),
                      builder: (ctx3, routeSnap) {
                        final r = routeSnap.data;
                        final showKm = r?.distanceKm ?? km;
                        final etaText = r != null
                            ? '${(r.durationMinutes + 2).round()}–${(r.durationMinutes + 8).round()} دقيقة'
                            : _eta(km);
                        return Row(children: [
                          const Icon(Icons.schedule_rounded,
                              size: 17, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(etaText,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark)),
                          const SizedBox(width: 10),
                          Text(
                              'يبعد عنك ${showKm.toStringAsFixed(1)} كم'
                              '${r != null ? " طريقاً" : ""}',
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textGray)),
                        ]);
                      },
                    ),
                  if (p != null) ...[
                    const SizedBox(height: 10),
                    _RoadBar(progress: p),
                  ],
                  const SizedBox(height: 12),
                  _DriverStrip(driver: d, order: order),
                ]);
              },
            )
          else
            OrderTrackingTimeline(status: st),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OrderMapScreen(order: order))),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('الخريطة'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OrderReceiptScreen(order: order))),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('الفاتورة'),
              ),
            ),
          ]),
          // إلغاء الطلب قبل استلام المطعم (ملاحظة المالك 2026-08-13):
          // الزر كان في البطاقات العادية وغاب عن بطاقة التتبّع — وأحدثُ
          // طلبٍ جارٍ يُعرض فيها حصراً، أي أن الطلب في أَولى لحظات جواز
          // إلغائه («بانتظار الموافقة») كان بلا زر إلغاء أصلاً. نصٌّ لا
          // زرٌّ عريض عمداً: خيار هروب لا دعوة ضغط.
          if (order.canCustomerCancel) ...[
            const SizedBox(height: 10),
            // مصارحة التجاهل (الإنقاذ السلوكي 2026-08-20): طلبٌ ينتظر ردّ
            // المطعم أكثر من خمس دقائق يستحق أن يعرف صاحبه أن التأخر من
            // المطعم لا من التطبيق — وأن بيده مخرجاً مجانياً الآن، بدل
            // انتظارٍ صامت يقتل الثقة من أول تجربة. (الإدارة تلغيه آلياً
            // بعد ضعف المهلة إن بقي متجاهَلاً.)
            if (order.status == OrderStatus.restaurantPending &&
                DateTime.now()
                        .difference(order.statusChangedAt ?? order.createdAt)
                        .inMinutes >=
                    5) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: const Text(
                  'المطعم لم يؤكد طلبك بعد — نتابع الأمر، ويمكنك الإلغاء '
                  'مجاناً الآن إن لم ترغب بالانتظار.',
                  style: TextStyle(fontSize: 12, color: AppColors.textDark),
                ),
              ),
            ],
            // بنمط زرَّي الخريطة والفاتورة نفسه (ملاحظة المالك 2026-08-14:
            // «الزر ليس مطابقاً») — عرض كامل وإطار، والأحمر هويةَ خطورةٍ
            // في اللون وحده لا في الشكل.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelFromCard(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withOpacity(0.6)),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('إلغاء الطلب'),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _cancelFromCard(BuildContext context) async {
    final service = context.read<FirebaseService>();
    final ok = await showConfirmDialog(
      context,
      title: 'إلغاء الطلب',
      content: 'هل تريد إلغاء طلبك #${order.orderNumber}؟',
      confirmLabel: 'إلغاء الطلب',
      confirmColor: AppColors.error,
    );
    if (ok != true || !context.mounted) return;
    try {
      await service.cancelOrderByCustomer(order.id);
      // صدق الرسالة: لو دُفع من المحفظة فالردّ يصرفه المدير (القواعد تمنع
      // زيادة العميل رصيدَه بنفسه) — يُقال ذلك صراحةً لا يُترك مفاجأة.
      if (context.mounted) {
        showSuccess(
            context,
            order.walletUsed > 0
                ? 'تم إلغاء الطلب — رصيد محفظتك (${order.walletUsed.toStringAsFixed(0)} ر.س) يُعيده لك المدير قريباً'
                : 'تم إلغاء الطلب');
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, 'تعذّر الإلغاء — قد يكون التحضير قد بدأ');
      }
    }
  }
}

/// شريط الطريق: المطعم ← رمز الكابتن عند نسبة ما قطعه ← بيتك.
class _RoadBar extends StatelessWidget {
  final double progress;
  const _RoadBar({required this.progress});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (ctx, c) {
          final w = c.maxWidth;
          // الاتجاه من اليمين لليسار: المطعم يمين والبيت يسار، موافقةً
          // لاتجاه القراءة العربية — عكسه يجعل التقدّم يبدو تراجعاً.
          final x = (w - 30) * (1 - progress);
          return SizedBox(
            height: 46,
            child: Stack(children: [
              Positioned(
                top: 13,
                right: 4,
                left: 4,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                top: 13,
                right: 4,
                child: Container(
                  height: 6,
                  width: (w - 8) * progress,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                top: 0,
                left: x,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 8),
                    ],
                  ),
                  child: const Icon(Icons.delivery_dining,
                      size: 18, color: Colors.white),
                ),
              ),
              const Positioned(
                bottom: 0,
                right: 2,
                child: Text('المطعم',
                    style:
                        TextStyle(fontSize: 10.5, color: AppColors.textGray)),
              ),
              const Positioned(
                bottom: 0,
                left: 2,
                child: Text('موقعك',
                    style:
                        TextStyle(fontSize: 10.5, color: AppColors.textGray)),
              ),
            ]),
          );
        },
      );
}

/// شريط الكابتن: اسمه وتقييمه وتوصيلاته، واتصال ومحادثة. التقييم يظهر فقط
/// إن قيّمه أحد فعلاً — «٥٫٠» لكابتن لم يقيّمه أحد وعدٌ لا يسنده شيء.
class _DriverStrip extends StatelessWidget {
  final Driver driver;
  final Order order;
  const _DriverStrip({required this.driver, required this.order});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: const Icon(Icons.delivery_dining,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                  Text(
                    driver.ratingCount > 0
                        ? '⭐ ${driver.rating.toStringAsFixed(1)} · ${driver.totalDeliveries} توصيلة'
                        : 'كابتن جديد · ${driver.totalDeliveries} توصيلة',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textGray),
                  ),
                ]),
          ),
          IconButton(
            tooltip: 'محادثة',
            icon: const Icon(Icons.chat_bubble_outline,
                color: AppColors.secondary),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => OrderChatScreen(order: order))),
          ),
          if (driver.phone.trim().isNotEmpty)
            IconButton(
              tooltip: 'اتصال',
              icon: const Icon(Icons.phone, color: AppColors.success),
              onPressed: () => callPhone(context, driver.phone),
            ),
        ]),
      );
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final auth = context.read<app_auth.AuthProvider>();
    final st = order.status;
    final time =
        '${order.createdAt.day}/${order.createdAt.month} ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}';

    // بطاقة بمستوى بطاقة عرض الكابتن (ملاحظة المالك «التصميم فقير»):
    // رأس ملوّن بحالة الطلب، ملخص أصناف يحيي البطاقة، والأفعال حبوب
    // مدمجة في صف واحد بدل أزرار عريضة متراصة تُطيل البطاقة وتُفقرها.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: st.color.withOpacity(0.35)),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: st.color.withOpacity(0.10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: st.color.withOpacity(0.18)),
                  child: Icon(st.icon, size: 15, color: st.color),
                ),
                const SizedBox(width: 8),
                Text(st.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: st.color)),
                const Spacer(),
                // رقم الطلب يفتح الفاتورة التفصيلية — أوضح مدخل يبحث عنه
                // العميل («وين أشوف فاتورتي؟»).
                InkWell(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => OrderReceiptScreen(order: order))),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('#${order.orderNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(width: 4),
                    const Icon(Icons.receipt_long_outlined,
                        size: 15, color: AppColors.textGray),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.storefront_rounded,
                        size: 16, color: AppColors.textGray),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(order.restaurantName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(time,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                  ]),
                  if (order.items.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      order.items
                          .map((i) => '${i.name} ×${i.quantity}')
                          .join('، '),
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textGray,
                          height: 1.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  OrderTrackingTimeline(status: order.status),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(formatCurrency(order.payableTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: AppColors.primaryDark)),
                    ),
                    const Spacer(),
                    // أفعال المتابعة الحية — أثناء ما الطلب بيد السائق فقط.
                    if (st == OrderStatus.pickedUp ||
                        st == OrderStatus.onTheWay) ...[
                      if (order.driverPhone != null &&
                          order.driverPhone!.isNotEmpty)
                        _roundAction(Icons.phone, AppColors.success,
                            () => callPhone(context, order.driverPhone)),
                      if (order.driverId != null)
                        _roundAction(
                            Icons.chat_bubble_outline,
                            AppColors.secondary,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        OrderChatScreen(order: order)))),
                      if (order.restaurantLat != null ||
                          order.deliveryLat != null)
                        _roundAction(
                            Icons.map_outlined,
                            AppColors.secondary,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        OrderMapScreen(order: order)))),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    // إعادة الطلب بضغطة — أرخص ميزة تزيد تكرار الشراء.
                    if (!order.status.isActive)
                      _pill(
                        icon: Icons.replay_rounded,
                        label: 'اطلب مجدداً',
                        color: AppColors.dark,
                        filled: true,
                        onTap: () => _reorder(context),
                      ),
                    if (order.status == OrderStatus.delivered &&
                        !order.isRated)
                      _pill(
                        icon: Icons.star_rounded,
                        label: 'قيّم الطلب',
                        color: AppColors.warning,
                        filled: true,
                        onTap: () =>
                            _showRateDialog(context, service, order),
                      ),
                    // الإلغاء متاح قبل بدء التحضير فقط؛ بعدها إداري.
                    if (order.canCustomerCancel)
                      _pill(
                        icon: Icons.cancel_outlined,
                        label: 'إلغاء الطلب',
                        color: AppColors.error,
                        onTap: () => _cancelOrder(context, service),
                      ),
                    // الشكوى بعدّادها الحي — الساعات الأخيرة بالأحمر.
                    ComplaintWindow(
                      order: order,
                      builder: (context, left, canSubmit) {
                        if (!canSubmit) return const SizedBox.shrink();
                        final urgent = left != null && left.inHours < 3;
                        final color =
                            urgent ? AppColors.error : AppColors.warning;
                        return _pill(
                          icon: urgent
                              ? Icons.timer_outlined
                              : Icons.report_problem_outlined,
                          label: left == null
                              ? 'شكوى'
                              : 'شكوى — ${formatRemaining(left)}',
                          color: color,
                          onTap: () => _openComplaint(context, auth),
                        );
                      },
                    ),
                  ]),
                  if (order.isRated && order.customerRating != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                            'تقييمك: ${order.customerRating!.toStringAsFixed(1)}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textGray)),
                      ]),
                    ),
                  // ردّ المطعم على التقييم (يوم المطعم): يظهر تحت تقييم
                  // صاحبه فقط — حوارٌ علني مصغّر يُشعر العميل أن تقييمه
                  // قُرئ، وهو أرخص أدوات استرجاع عميلٍ غاضب.
                  if (order.isRated &&
                      (order.restaurantReply ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                            'ردّ المطعم: ${order.restaurantReply!.trim()}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textDark)),
                      ),
                    ),
                  if (order.status.isActive && !order.canCustomerCancel)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                          'بدأ تحضير طلبك — للإلغاء تواصل مع الإدارة',
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.textGray)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// زر دائري مصغّر لأفعال المتابعة الحية — بدل IconButton الافتراضي
  /// الفضفاض الذي يوسّع الصف بلا داع.
  Widget _roundAction(IconData icon, Color color, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color.withOpacity(0.12)),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );

  /// حبّة فعل مدمجة — أفعال البطاقة كلها بهذا الشكل فلا تتكدس أزرار
  /// عريضة تحت بعضها (سبب «التصميم الفقير» الذي لاحظه المالك).
  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) =>
      Material(
        color: filled ? color : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: filled ? Colors.white : color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: filled ? Colors.white : color)),
            ]),
          ),
        ),
      );

  Future<void> _reorder(BuildContext context) async {
    // المنطق مشترك مع شريحة «اطلب مجدداً» في الرئيسية (utils/reorder.dart) —
    // ينجح فينقلنا للسلة، ويفشل بعد أن يعرض سببه بنفسه.
    final ok = await reorderIntoCart(context, order);
    if (ok && context.mounted) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CartScreen()));
    }
  }

  Future<void> _cancelOrder(BuildContext context, FirebaseService service) async {
    final ok = await showConfirmDialog(
      context,
      title: 'إلغاء الطلب',
      content: 'هل تريد إلغاء طلبك #${order.orderNumber}؟',
      confirmLabel: 'إلغاء الطلب',
      confirmColor: AppColors.error,
    );
    if (ok != true || !context.mounted) return;
    try {
      await service.cancelOrderByCustomer(order.id);
      // صدق الرسالة: لو دُفع من المحفظة فالردّ يصرفه المدير (القواعد تمنع
      // زيادة العميل رصيدَه بنفسه) — يُقال ذلك صراحةً لا يُترك مفاجأة.
      if (context.mounted) {
        showSuccess(
            context,
            order.walletUsed > 0
                ? 'تم إلغاء الطلب — رصيد محفظتك (${order.walletUsed.toStringAsFixed(0)} ر.س) يُعيده لك المدير قريباً'
                : 'تم إلغاء الطلب');
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, 'تعذّر الإلغاء — قد يكون التحضير قد بدأ');
      }
    }
  }

  void _openComplaint(BuildContext context, app_auth.AuthProvider auth) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmitComplaintScreen(
          order: order,
          submittedByUid: auth.user?.uid ?? '',
          submittedByName: auth.user?.name ?? '',
          submittedByRole: UserRole.customer,
        ),
      ),
    );
  }

  void _showRateDialog(BuildContext context, FirebaseService service, Order o) {
    double orderRating = 5, driverRating = 5;
    final reviewCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => AlertDialog(
          title: const Text('قيّم تجربتك'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('جودة الطلب'),
              RatingBar.builder(
                initialRating: 5,
                itemCount: 5,
                itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (r) => orderRating = r,
              ),
              const SizedBox(height: 12),
              const Text('أداء السائق'),
              RatingBar.builder(
                initialRating: 5,
                itemCount: 5,
                itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (r) => driverRating = r,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reviewCtrl,
                decoration: const InputDecoration(labelText: 'تعليقك (اختياري)'),
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                await service.rateOrder(
                  orderId: o.id,
                  driverId: o.driverId ?? '',
                  orderRating: orderRating,
                  driverRating: driverRating,
                  review: reviewCtrl.text.trim().isEmpty ? null : reviewCtrl.text.trim(),
                  restaurantId: o.restaurantId,
                );
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}