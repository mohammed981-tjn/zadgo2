// lib/screens/admin/order_tracking_tab.dart
//
// شاشة متابعة الطلبات الحية في لوحة المدير: تعرض كل الطلبات النشطة/القادمة
// مع تفاصيلها والسائق المعين، وتتيح للمدير تحويل الطلب لسائق آخر عند الطوارئ
// (عطل مركبة، حادث، إلخ) دون التأثير على آلية استقبال السائق الأول.
//
// ✅ أرقام الجوال وأزرار الاتصال: يعرض جوال العميل دائماً، وجوال السائق إن
// وُجد سائق مُسنَد (وإلا نص توضيحي بدل زر معطل)، مع معالجة صريحة لفشل فتح
// تطبيق الاتصال (رسالة خطأ لا انهيار صامت).
//
// ✅ آليات Timeout للطلبات المعلّقة (client-side فقط، بلا Cloud Functions):
// المُهل الثلاث (استجابة المطعم/بحث السائق/تأخر التوصيل) تُقرأ من مستند
// delivery_settings/config في Firestore، والفحص يتم مرة واحدة عند فتح هذه
// الشاشة اعتماداً على statusChangedAt/createdAt. تحويل الحالة الآلي الوحيد
// هنا هو searchingDriver → noDriverFound بعد انقضاء مهلة بحث السائق؛ البقية
// (تنبيه تأخر المطعم، تعليم الطلب "متأخر") عرض فقط دون كتابة على القاعدة.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/complaint_window.dart' show formatRemaining;
import '../customer/order_map_screen.dart';
import '../customer/order_chat_screen.dart';

/// مُهل معالجة الطلبات العالقة (بالدقائق)، تُحمَّل من مستند
/// delivery_settings/config في Firestore. القيم أدناه افتراضات تُستخدم فقط
/// حين لا يكون المستند أو أحد حقوله موجوداً بعد — لا حاجة لإصدار تطبيق جديد
/// لتغييرها، يكفي تعديل المستند في Firestore مباشرة.
class DeliveryTimeoutSettings {
  /// مهلة عدم استجابة المطعم من دخول الطلب حالة "بانتظار موافقة المطعم".
  final int restaurantResponseMinutes;
  /// مهلة عدم قبول أي سائق من دخول الطلب حالة "جاري البحث عن سائق".
  final int driverSearchMinutes;
  /// السماحية المضافة فوق وقت التوصيل المتوقع (٣٠ دقيقة تقديرية من الإنشاء)
  /// قبل تعليم الطلب "متأخر" في شاشة المتابعة.
  final int lateDeliveryGraceMinutes;

  const DeliveryTimeoutSettings({
    this.restaurantResponseMinutes = 5,
    this.driverSearchMinutes = 10,
    this.lateDeliveryGraceMinutes = 15,
  });

  factory DeliveryTimeoutSettings.fromMap(Map<String, dynamic> map) => DeliveryTimeoutSettings(
        restaurantResponseMinutes:
            (map['restaurantResponseTimeoutMinutes'] as num?)?.toInt() ?? 5,
        driverSearchMinutes: (map['driverSearchTimeoutMinutes'] as num?)?.toInt() ?? 10,
        lateDeliveryGraceMinutes:
            (map['lateDeliveryThresholdMinutes'] as num?)?.toInt() ?? 15,
      );
}

/// تقدير خام لوقت التوصيل الإجمالي المتوقع من إنشاء الطلب (بانتظار بيانات
/// تاريخية أدق لكل مطعم/منطقة)، يُضاف إليه [DeliveryTimeoutSettings.lateDeliveryGraceMinutes]
/// قبل اعتبار الطلب متأخراً — وليس وحده كما كان سابقاً (الخلل المُصلَح هنا).
const int _baselineExpectedDeliveryMinutes = 30;

class OrderTrackingTab extends StatefulWidget {
  const OrderTrackingTab({super.key});

  @override
  State<OrderTrackingTab> createState() => _OrderTrackingTabState();
}

class _OrderTrackingTabState extends State<OrderTrackingTab> {
  DeliveryTimeoutSettings _timeouts = const DeliveryTimeoutSettings();

  @override
  void initState() {
    super.initState();
    // الفحص يتم مرة واحدة فقط عند فتح الشاشة، وليس على كل نبضة من التدفق
    // (Stream) لتفادي إعادة الكتابة على نفس الطلب مراراً.
    _loadSettingsAndCheckTimeouts();
  }

  Future<void> _loadSettingsAndCheckTimeouts() async {
    final service = context.read<FirebaseService>();
    Map<String, dynamic> map = {};
    try {
      map = await service.getDeliverySettings();
    } catch (_) {
      // تعذّر قراءة الإعدادات (مثلاً بلا اتصال) — نكمل بالقيم الافتراضية
      // دون منع عرض الشاشة.
    }
    final timeouts = DeliveryTimeoutSettings.fromMap(map);
    if (!mounted) return;
    setState(() => _timeouts = timeouts);
    await _flagOrdersWithNoDriverFound(service, timeouts);
    // مصالحة توافر السائقين: سائق عَلِق «غير متاح» بعد إلغاء طلبٍ مُسنَد
    // كان يختفي عن كل الطلبات اللاحقة بلا أثر ظاهر. تُشغَّل هنا لأن سرد كل
    // الطلبات — شرط المصالحة — صلاحية إدارية، ولأن هذه أول شاشة يفتحها
    // المدير حين يسأل «لماذا لم يصل الطلب لأي كابتن؟».
    try {
      final freed = await service.reconcileDriverAvailability();
      if (freed > 0 && mounted) {
        showSuccess(context, tr('حُرِّر $freed كابتن كان عالقاً «غير متاح»',
            'Freed $freed captains stuck as "unavailable"'));
      }
    } catch (_) {
      // المصالحة تحسينٌ لا شرط لعمل الشاشة.
    }
    // كنس الطلبات العالقة (الإنقاذ السلوكي 2026-08-20): عروضٌ ميتة تُسترجع
    // ويعاد ترشيحها، وطلباتٌ تجاهلها المطعم طويلاً تُلغى وتُردّ أموالها —
    // التفصيل والمُهل في تعليق reconcileStuckOrders.
    try {
      final swept = await service.reconcileStuckOrders();
      if (mounted &&
          (swept.reclaimedOffers > 0 || swept.cancelledIgnored > 0)) {
        final parts = <String>[
          if (swept.reclaimedOffers > 0)
            tr('أُعيد ترشيح ${swept.reclaimedOffers} طلب كان عرضه معلّقاً على جهاز ميت',
                'Re-dispatched ${swept.reclaimedOffers} orders whose offer was stuck on a dead device'),
          if (swept.cancelledIgnored > 0)
            tr('أُلغي ${swept.cancelledIgnored} طلب تجاهله مطعمه ورُدّت أمواله',
                'Cancelled ${swept.cancelledIgnored} orders ignored by their restaurant and refunded'),
        ];
        showSuccess(context, parts.join(' · '));
      }
    } catch (_) {}
    // كنس أعلام درع النقد: ترقية الموثوقين بعد أول تسليم، وحظر من بلغ
    // حدّ رفض الاستلام (الحد من شاشة الحوافز — صفر يعطّله).
    try {
      final flags = await service.reconcileCashFlags();
      if (mounted && flags.blocked > 0) {
        showSuccess(context,
            tr('دِرع النقد: حُظر الدفع النقدي عن ${flags.blocked} عميل تكرر رفضه للاستلام',
                'Cash shield: cash payment blocked for ${flags.blocked} customers who repeatedly refused delivery'));
      }
    } catch (_) {}
  }

  /// يحوّل آلياً أي طلب "جاري البحث عن سائق" تجاوز مهلة البحث دون أن يقبله
  /// أي سائق إلى حالة "تعذر إيجاد سائق" (noDriverFound)، ليصبح مرئياً بتنبيه
  /// فوري في هذه الشاشة ويتيح للمدير إسناد سائق يدوياً.
  Future<void> _flagOrdersWithNoDriverFound(
      FirebaseService service, DeliveryTimeoutSettings timeouts) async {
    try {
      final orders = await service.streamActiveOrders().first;
      final now = DateTime.now();
      for (final order in orders) {
        if (order.status != OrderStatus.searchingDriver) continue;
        final since = order.statusChangedAt ?? order.createdAt;
        if (now.difference(since).inMinutes >= timeouts.driverSearchMinutes) {
          try {
            await service.updateOrderStatus(order.id, OrderStatus.noDriverFound);
          } catch (_) {
            // تجاهل: حالة تسابق نادرة (قَبِل سائق الطلب بين القراءة والكتابة).
          }
        }
      }
    } catch (_) {
      // تعذّر جلب الطلبات لفحص المُهل — لا نمنع عرض الشاشة نفسها.
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Order>>(
      stream: service.streamActiveOrders,
      builder: (ctx, orders) {
        if (orders.isEmpty) {
          return AppEmpty(
              emoji: '🛰️',
              title: tr('لا يوجد طلبات نشطة حالياً', 'No active orders right now'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (_, i) => _TrackedOrderCard(order: orders[i], timeouts: _timeouts),
        );
      },
    );
  }
}

class _TrackedOrderCard extends StatelessWidget {
  final Order order;
  final DeliveryTimeoutSettings timeouts;
  const _TrackedOrderCard({required this.order, required this.timeouts});

  String _elapsedLabel() {
    final elapsed = DateTime.now().difference(order.createdAt);
    final remaining = _baselineExpectedDeliveryMinutes - elapsed.inMinutes;
    if (remaining <= 0) {
      return tr('تجاوز الوقت التقديري للتوصيل',
          'Past the estimated delivery time');
    }
    return tr('الوقت المتبقي المتوقع: ~$remaining د',
        'Expected time remaining: ~$remaining min');
  }

  /// وقت دخول الطلب — كان غائباً عن بطاقة المتابعة كلها (بلاغ المالك
  /// ٢٠٢٦-٠٨-١١)، فلا يعرف المدير متى دخل الطلب إلا بحساب عكسي من
  /// «المتبقي المتوقع». التاريخ والساعة والعمر معاً: الأول للمراجعة،
  /// والثاني للمطابقة مع شاشتَي المطعم والكابتن، والثالث لقرار اللحظة.
  String _placedLabel() {
    final t = order.createdAt;
    final clock =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return tr(
        'دخل الطلب ${t.day}/${t.month} — $clock '
            '(منذ ${formatRemaining(DateTime.now().difference(t))})',
        'Order placed ${t.day}/${t.month} — $clock '
            '(${formatRemaining(DateTime.now().difference(t))} ago)');
  }

  /// ✅ الخلل المُصلَح: كانت كل الطلبات (حتى الجديدة منها) تُحسب أحياناً
  /// "متأخرة" لأن الحد لم يتضمن أي سماحية فوق التقدير الخام، فكانت أي مرحلة
  /// لاحقة لمراحل الطلب (تحضير+بحث سائق+استلام+توصيل) تتجاوز الـ٣٠ دقيقة
  /// بسهولة وتُعلَّم "متأخرة" فوراً بلا هامش. الآن: العتبة = التقدير الخام
  /// + مهلة السماحية القابلة للتعديل من delivery_settings (افتراضياً ١٥ د)،
  /// ولا تُحتسب أصلاً على الطلبات المنتهية (تم التوصيل/أُلغيت/رُفضت...).
  bool get _isLate {
    if (!(order.status.isActive || order.status == OrderStatus.noDriverFound)) return false;
    final elapsedMinutes = DateTime.now().difference(order.createdAt).inMinutes;
    return elapsedMinutes > (_baselineExpectedDeliveryMinutes + timeouts.lateDeliveryGraceMinutes);
  }

  /// تنبيه بارز حين لم يستجب المطعم خلال المهلة، أو حين تعذّر إيجاد سائق
  /// تلقائياً ويتطلب الأمر تعييناً يدوياً من المدير.
  Widget? _buildAlertBanner() {
    final now = DateTime.now();
    if (order.status == OrderStatus.restaurantPending) {
      final since = order.statusChangedAt ?? order.createdAt;
      final minutes = now.difference(since).inMinutes;
      if (minutes >= timeouts.restaurantResponseMinutes) {
        return _AlertBanner(
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          text: tr(
              'المطعم لم يستجب منذ $minutes د (المهلة ${timeouts.restaurantResponseMinutes} د) — '
                  'يمكن إلغاء الطلب يدوياً من الأسفل إن لم يُتوقَّع رد.',
              'The restaurant has not responded for $minutes min (limit ${timeouts.restaurantResponseMinutes} min) — '
                  'you can cancel the order manually below if no reply is expected.'),
        );
      }
    }
    if (order.status == OrderStatus.noDriverFound) {
      return _AlertBanner(
        color: Colors.deepOrange,
        icon: Icons.person_off_rounded,
        text: tr(
            'تعذّر إيجاد سائق تلقائياً خلال المهلة المحددة — يتطلب إسناد سائق يدوياً الآن.',
            'No driver was found automatically within the set limit — assign a driver manually now.'),
      );
    }
    return null;
  }

  Future<void> _call(BuildContext context, String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: trimmed);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        showError(context, tr('تعذّر فتح تطبيق الاتصال على هذا الجهاز',
            'Could not open the phone app on this device'));
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر فتح تطبيق الاتصال',
            'Could not open the phone app'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final isLate = _isLate;
    final alertBanner = _buildAlertBanner();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLate ? const BorderSide(color: AppColors.error, width: 1.2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (isLate) ...[
              StatusBadge(label: tr('متأخر', 'Late'), color: AppColors.error, icon: Icons.timer_off_rounded),
              const SizedBox(width: 6),
            ],
            StatusBadge(label: order.status.label, color: order.status.color),
          ]),
          if (alertBanner != null) ...[
            const SizedBox(height: 8),
            alertBanner,
          ],
          InfoRow(icon: Icons.restaurant_outlined, text: order.restaurantName),
          const SizedBox(height: 2),
          // ✅ رقم جوال العميل + زر اتصال مباشر (tel:).
          Row(children: [
            const Icon(Icons.person_outline, size: 15, color: AppColors.textGray),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order.customerPhone.trim().isNotEmpty
                    ? '${order.customerName} — ${order.customerPhone}'
                    : order.customerName,
                style: const TextStyle(fontSize: 13.5, color: AppColors.textGray),
              ),
            ),
            if (order.customerPhone.trim().isNotEmpty)
              IconButton(
                tooltip: tr('الاتصال بالعميل', 'Call the customer'),
                icon: const Icon(Icons.call_outlined, color: AppColors.success, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => _call(context, order.customerPhone),
              ),
          ]),
          // ✅ رقم جوال السائق (إن وُجد سائق مُسنَد) + زر اتصال مباشر؛
          // وإلا نص توضيحي بدل زر معطل بلا تفسير.
          if (order.driverId != null && order.driverId!.isNotEmpty)
            StreamBuilder<Driver?>(
              stream: service.streamDriver(order.driverId!),
              builder: (ctx, snap) {
                final driver = snap.data;
                final phone = driver?.phone.trim() ?? '';
                final name = order.driverName ?? driver?.name ?? tr('سائق', 'Driver');
                return Row(children: [
                  const Icon(Icons.delivery_dining_outlined, size: 15, color: AppColors.textGray),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone.isNotEmpty
                          ? tr('السائق: $name — $phone', 'Driver: $name — $phone')
                          : tr('السائق: $name', 'Driver: $name'),
                      style: const TextStyle(fontSize: 13.5, color: AppColors.textGray),
                    ),
                  ),
                  if (phone.isNotEmpty)
                    IconButton(
                      tooltip: tr('الاتصال بالسائق', 'Call the driver'),
                      icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _call(context, phone),
                    ),
                ]);
              },
            )
          else
            InfoRow(
                icon: Icons.delivery_dining_outlined,
                text: tr('لم يُعيّن سائق بعد', 'No driver assigned yet')),
          InfoRow(icon: Icons.event_available_outlined, text: _placedLabel()),
          InfoRow(icon: Icons.timer_outlined, text: _elapsedLabel()),
          // بلاغ «تعذّر التسليم» من الكابتن (درع النقد): أعلى أولوية في
          // البطاقة — كابتنٌ واقف بطعامٍ وعُهدة ينتظر قرارك: إلغاء
          // (بمساراته المالية) أو تحويل أو إعادة محاولة — الأزرار أدناه.
          if (order.deliveryFailed)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.5)),
              ),
              child: Text(
                tr(
                    '⛔ تعذّر التسليم — ${order.undeliveredReason ?? 'بلا سبب'}\n'
                        'الكابتن ينتظر قرارك: إلغاء أو إعادة محاولة.',
                    '⛔ Delivery failed — ${order.undeliveredReason ?? 'no reason'}\n'
                        'The captain is waiting for your decision: cancel or retry.'),
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600),
              ),
            ),
          OrderTrackingTimeline(status: order.status),
          const SizedBox(height: 8),
          // المبلغ حبّة بارزة، والأفعال كلها حبوب مدمجة في صفّ ملتفّ —
          // كانت خمسة أزرار عريضة متراصّة تُطيل البطاقة وتدفن المهم
          // (ملاحظة المالك «التصميم فقير» على شاشات القوائم).
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(
              icon: Icons.chat_bubble_outline,
              label: tr('محادثة الطلب', 'Order chat'),
              color: AppColors.secondary,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => OrderChatScreen(order: order))),
            ),
            // الإسناد اليدوي متاح لأي طلب بلا سائق لا لحالة «تعذّر إيجاد
            // سائق» وحدها: طلبٌ عالق في «جاهز للاستلام» بلا سائق كان بلا
            // مخرج حتى تنقضي مهلة البحث (بلاغ المالك ٢٠٢٦-٠٨-١١).
            if ((order.driverId ?? '').isEmpty &&
                (order.status.isActive ||
                    order.status == OrderStatus.noDriverFound))
              _pill(
                icon: Icons.person_add_alt_1,
                label: tr('إسناد سائق يدوياً', 'Assign driver manually'),
                color: Colors.deepOrange,
                filled: order.status == OrderStatus.noDriverFound,
                onTap: () => _showAssignDriverDialog(context, service, order),
              ),
            if ((order.status == OrderStatus.driverAssigned ||
                    order.status == OrderStatus.pickedUp ||
                    order.status == OrderStatus.onTheWay) &&
                order.driverId != null &&
                order.driverId!.isNotEmpty &&
                // التحويل يمسّ عُهدة السائقَين ودفترَيهما (مال) — للمدير
                // وحده؛ الدعم يرصد المتعثر ويبلّغ. القاعدة ترفضه له أصلاً.
                context.read<app_auth.AuthProvider>().user?.role !=
                    UserRole.support)
              _pill(
                icon: Icons.swap_horiz,
                label: tr('تحويل لسائق آخر', 'Reassign to another driver'),
                color: AppColors.secondary,
                onTap: () => _showReassignDialog(context, service, order),
              ),
            if (order.driverId != null && order.driverId!.isNotEmpty)
              _pill(
                icon: Icons.map_outlined,
                label: tr('الخريطة', 'Map'),
                color: AppColors.secondary,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => OrderMapScreen(order: order))),
              ),
            // إنهاء الطلب أو إلغاؤه مباشرة من المتابعة الحية — للطوارئ.
            // «تعذّر إيجاد سائق» ليست نشطة تقنياً لكنها ليست منتهية: الطلب
            // عالق ينتظر قرار المدير، وبلا الزرّين يبقى بلا مخرج ورصيد
            // المحفظة محجوزاً.
            if (order.status.isActive ||
                order.status == OrderStatus.noDriverFound) ...[
              _pill(
                icon: Icons.check_circle_outline,
                label: tr('إنهاء الطلب', 'Complete order'),
                color: AppColors.success,
                onTap: order.driverId == null || order.driverId!.isEmpty
                    ? null
                    : () async {
                        final ok = await showConfirmDialog(context,
                            title: tr('إنهاء الطلب', 'Complete order'),
                            content: tr(
                                'هل تم توصيل الطلب فعلياً للعميل؟ سيُعتبر الطلب منتهياً.',
                                'Was the order actually delivered to the customer? It will be marked as completed.'),
                            confirmLabel: tr('إنهاء', 'Complete'));
                        if (ok == true) {
                          await service.markOrderDelivered(
                              order.id, order.driverId!);
                          if (context.mounted) {
                            showSuccess(context, tr('تم إنهاء الطلب', 'Order completed'));
                          }
                        }
                      },
              ),
              _pill(
                icon: Icons.cancel_outlined,
                label: tr('إلغاء الطلب', 'Cancel order'),
                color: AppColors.error,
                onTap: () async {
                  // مصارحة بالأثر المالي قبل الضغط لا بعده: الإلغاء بعد
                  // بدء التحضير يُقيّد تعويضاً للمطعم على المنصّة.
                  final cooked = order.status == OrderStatus.preparing ||
                      order.status == OrderStatus.readyForPickup ||
                      order.status == OrderStatus.searchingDriver ||
                      order.status == OrderStatus.driverAssigned ||
                      order.status == OrderStatus.pickedUp ||
                      order.status == OrderStatus.onTheWay;
                  final ok = await showConfirmDialog(context,
                      title: tr('إلغاء الطلب', 'Cancel order'),
                      content: cooked
                          ? tr(
                              'المطعم بدأ التحضير — سيُقيَّد له تعويض بقيمة '
                                  '${formatCurrency(order.itemsTotal)} تتحمّله المنصّة، '
                                  'ويُعاد للعميل ما خُصم من محفظته.\n\nإلغاء الطلب؟'
                              ,
                              'The restaurant has started preparing — a compensation of '
                                  '${formatCurrency(order.itemsTotal)} will be recorded for them, borne by the platform, '
                                  'and whatever was deducted from the customer\'s wallet is refunded.\n\nCancel the order?')
                          : tr('هل تريد إلغاء هذا الطلب نهائياً؟ (كأنه لم يُطلب)',
                              'Cancel this order for good? (as if it was never placed)'),
                      confirmLabel: tr('إلغاء الطلب', 'Cancel order'));
                  if (ok == true) {
                    await service.cancelOrder(order.id);
                    if (context.mounted) {
                      showSuccess(context, tr('تم إلغاء الطلب', 'Order cancelled'));
                    }
                  }
                },
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  /// حبّة فعل مدمجة — onTap فارغ يعرضها رمادية معطّلة (إنهاء بلا سائق).
  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final c = onTap == null ? AppColors.textGray : color;
    return Material(
      color: filled && onTap != null ? c : c.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 16, color: filled && onTap != null ? Colors.white : c),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: filled && onTap != null ? Colors.white : c)),
          ]),
        ),
      ),
    );
  }

  void _showReassignDialog(BuildContext context, FirebaseService service, Order order) {
    final auth = context.read<app_auth.AuthProvider>();
    final reasonCtrl = TextEditingController();
    String? selectedDriverId;
    String? selectedDriverName;
    bool loading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: Text(tr('تحويل الطلب لسائق آخر', 'Reassign order to another driver')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(
                  'الطلب #${order.orderNumber} — السائق الحالي: ${order.driverName ?? "غير معيّن"}',
                  'Order #${order.orderNumber} — current driver: ${order.driverName ?? "unassigned"}')),
              const SizedBox(height: 14),
              AppStreamBuilder<List<Driver>>(
                stream: service.streamDrivers,
                builder: (ctx, allDrivers) {
                  final drivers = allDrivers
                      .where((d) => d.id != order.driverId && d.isOnline)
                      .toList();
                  if (drivers.isEmpty) {
                    return Text(tr('لا يوجد سائقون متاحون آخرون حالياً',
                            'No other drivers available right now'),
                        style: const TextStyle(color: Colors.orange));
                  }
                  return DropdownButtonFormField<String>(
                    value: selectedDriverId,
                    decoration: InputDecoration(
                        labelText: tr('السائق الجديد', 'New driver')),
                    items: drivers
                        .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                        .toList(),
                    onChanged: (v) {
                      selectedDriverId = v;
                      selectedDriverName = drivers.firstWhere((d) => d.id == v).name;
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                    labelText: tr('سبب التحويل', 'Reassignment reason'),
                    hintText: tr('مثال: عطل مركبة، حادث، تأخر...',
                        'Example: vehicle breakdown, accident, delay...')),
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(tr('إلغاء', 'Cancel'))),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (selectedDriverId == null || reasonCtrl.text.trim().isEmpty) {
                        showError(dialogCtx, tr('يرجى اختيار سائق جديد وتوضيح السبب',
                            'Please pick a new driver and state the reason'));
                        return;
                      }
                      setState(() => loading = true);
                      try {
                        await service.reassignDriver(
                          order: order,
                          newDriverId: selectedDriverId!,
                          newDriverName: selectedDriverName!,
                          reason: reasonCtrl.text.trim(),
                          performedBy: auth.user?.name ?? auth.user?.uid ?? 'admin',
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      } catch (e) {
                        setState(() => loading = false);
                        if (dialogCtx.mounted) {
                          showError(dialogCtx, tr('فشل التحويل: $e',
                              'Reassignment failed: $e'));
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr('تأكيد التحويل', 'Confirm reassignment')),
            ),
          ],
        ),
      ),
    );
  }

  /// إسناد سائق يدوياً لطلب في حالة "تعذّر إيجاد سائق" (لا سائق مُسنَد أصلاً
  /// بخلاف [_showReassignDialog] الذي يستبدل سائقاً موجوداً بآخر).
  void _showAssignDriverDialog(BuildContext context, FirebaseService service, Order order) {
    String? selectedDriverId;
    String? selectedDriverName;
    bool loading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: Text(tr('إسناد سائق يدوياً', 'Assign driver manually')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('الطلب #${order.orderNumber} — تعذّر إيجاد سائق تلقائياً.',
                  'Order #${order.orderNumber} — no driver was found automatically.')),
              const SizedBox(height: 14),
              // كل السائقين المتصلين لا المتاحين وحدهم: «غير متاح» قد يكون
              // عالقاً من طلبٍ أُلغي، وحصر القائمة فيه كان يترك المدير بلا
              // مخرج أمام رسالة «لا يوجد سائقون» بينما الكباتن متصلون.
              AppStreamBuilder<List<Driver>>(
                stream: service.streamDrivers,
                builder: (ctx, allDrivers) {
                  final drivers = allDrivers.where((d) => d.isOnline).toList()
                    ..sort((a, b) => a.activeOrders.compareTo(b.activeOrders));
                  if (drivers.isEmpty) {
                    return Text(tr('لا يوجد كابتن متصل الآن', 'No captain online right now'),
                        style: const TextStyle(color: Colors.orange));
                  }
                  return DropdownButtonFormField<String>(
                    value: selectedDriverId,
                    decoration: InputDecoration(labelText: tr('السائق', 'Driver')),
                    items: drivers
                        .map((d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d.activeOrders == 0
                                ? d.name
                                : tr('${d.name} — ${d.activeOrders} طلب بيده',
                                    '${d.name} — ${d.activeOrders} orders in hand'))))
                        .toList(),
                    onChanged: (v) {
                      selectedDriverId = v;
                      selectedDriverName = drivers.firstWhere((d) => d.id == v).name;
                    },
                  );
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(tr('إلغاء', 'Cancel'))),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (selectedDriverId == null) {
                        showError(dialogCtx, tr('يرجى اختيار سائق', 'Please pick a driver'));
                        return;
                      }
                      setState(() => loading = true);
                      try {
                        await service.assignDriver(order.id, selectedDriverId!, selectedDriverName!);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      } catch (e) {
                        setState(() => loading = false);
                        if (dialogCtx.mounted) {
                          showError(dialogCtx, tr('فشل الإسناد: $e',
                              'Assignment failed: $e'));
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr('تأكيد الإسناد', 'Confirm assignment')),
            ),
          ],
        ),
      ),
    );
  }
}

/// تنبيه بارز أعلى بطاقة الطلب (مطعم لم يستجب / تعذّر إيجاد سائق).
class _AlertBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _AlertBanner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
