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
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
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
          return const AppEmpty(emoji: '🛰️', title: 'لا يوجد طلبات نشطة حالياً');
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
    if (remaining <= 0) return 'تجاوز الوقت التقديري للتوصيل';
    return 'الوقت المتبقي المتوقع: ~$remaining د';
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
          text:
              'المطعم لم يستجب منذ $minutes د (المهلة ${timeouts.restaurantResponseMinutes} د) — '
              'يمكن إلغاء الطلب يدوياً من الأسفل إن لم يُتوقَّع رد.',
        );
      }
    }
    if (order.status == OrderStatus.noDriverFound) {
      return const _AlertBanner(
        color: Colors.deepOrange,
        icon: Icons.person_off_rounded,
        text: 'تعذّر إيجاد سائق تلقائياً خلال المهلة المحددة — يتطلب إسناد سائق يدوياً الآن.',
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
        showError(context, 'تعذّر فتح تطبيق الاتصال على هذا الجهاز');
      }
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر فتح تطبيق الاتصال');
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
              const StatusBadge(label: 'متأخر', color: AppColors.error, icon: Icons.timer_off_rounded),
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
                style: const TextStyle(fontSize: 13, color: AppColors.textGray),
              ),
            ),
            if (order.customerPhone.trim().isNotEmpty)
              IconButton(
                tooltip: 'الاتصال بالعميل',
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
                final name = order.driverName ?? driver?.name ?? 'سائق';
                return Row(children: [
                  const Icon(Icons.delivery_dining_outlined, size: 15, color: AppColors.textGray),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone.isNotEmpty ? 'السائق: $name — $phone' : 'السائق: $name',
                      style: const TextStyle(fontSize: 13, color: AppColors.textGray),
                    ),
                  ),
                  if (phone.isNotEmpty)
                    IconButton(
                      tooltip: 'الاتصال بالسائق',
                      icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _call(context, phone),
                    ),
                ]);
              },
            )
          else
            const InfoRow(icon: Icons.delivery_dining_outlined, text: 'لم يُعيّن سائق بعد'),
          InfoRow(icon: Icons.timer_outlined, text: _elapsedLabel()),
          OrderTrackingTimeline(status: order.status),
          Text(formatCurrency(order.payableTotal),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('محادثة الطلب'),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => OrderChatScreen(order: order))),
            ),
          ),
          if (order.status == OrderStatus.noDriverFound) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إسناد سائق يدوياً'),
                onPressed: () => _showAssignDriverDialog(context, service, order),
              ),
            ),
          ],
          if ((order.status == OrderStatus.driverAssigned ||
                  order.status == OrderStatus.pickedUp ||
                  order.status == OrderStatus.onTheWay) &&
              order.driverId != null &&
              order.driverId!.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text('تحويل الطلب لسائق آخر'),
                onPressed: () => _showReassignDialog(context, service, order),
              ),
            ),
          ],
          if (order.driverId != null && order.driverId!.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('تتبع موقع السائق على الخريطة'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => OrderMapScreen(order: order))),
              ),
            ),
          ],
          // ✅ إنهاء الطلب أو إلغاؤه مباشرة من شاشة المتابعة الحية دون التنقل
          // بين شاشات أخرى — مفيد للطوارئ (مشكلة اتصال، طلب لن يُستكمل...).
          // «تعذّر إيجاد سائق» ليست حالة نشطة تقنياً، لكنها ليست منتهية أيضاً:
          // الطلب عالق ينتظر قرار المدير (إسناد سائق أو إلغاء). بدون إظهار
          // الأزرار هنا يبقى الطلب بلا مخرج، ويبقى معه رصيد المحفظة محجوزاً.
          if (order.status.isActive ||
              order.status == OrderStatus.noDriverFound) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success)),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('إنهاء الطلب'),
                  onPressed: order.driverId == null || order.driverId!.isEmpty
                      ? null
                      : () async {
                          final ok = await showConfirmDialog(context,
                              title: 'إنهاء الطلب',
                              content: 'هل تم توصيل الطلب فعلياً للعميل؟ سيُعتبر الطلب منتهياً.',
                              confirmLabel: 'إنهاء');
                          if (ok == true) {
                            await service.markOrderDelivered(order.id, order.driverId!);
                            if (context.mounted) showSuccess(context, 'تم إنهاء الطلب');
                          }
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error)),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('إلغاء الطلب'),
                  onPressed: () async {
                    final ok = await showConfirmDialog(context,
                        title: 'إلغاء الطلب',
                        content: 'هل تريد إلغاء هذا الطلب نهائياً؟ (كأنه لم يُطلب)',
                        confirmLabel: 'إلغاء الطلب');
                    if (ok == true) {
                      await service.cancelOrder(order.id);
                      if (context.mounted) showSuccess(context, 'تم إلغاء الطلب');
                    }
                  },
                ),
              ),
            ]),
          ],
        ]),
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
          title: const Text('تحويل الطلب لسائق آخر'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الطلب #${order.orderNumber} — السائق الحالي: ${order.driverName ?? "غير معيّن"}'),
              const SizedBox(height: 14),
              AppStreamBuilder<List<Driver>>(
                stream: service.streamDrivers,
                builder: (ctx, allDrivers) {
                  final drivers = allDrivers
                      .where((d) => d.id != order.driverId && d.isOnline)
                      .toList();
                  if (drivers.isEmpty) {
                    return const Text('لا يوجد سائقون متاحون آخرون حالياً',
                        style: TextStyle(color: Colors.orange));
                  }
                  return DropdownButtonFormField<String>(
                    value: selectedDriverId,
                    decoration: const InputDecoration(labelText: 'السائق الجديد'),
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
                decoration: const InputDecoration(
                    labelText: 'سبب التحويل', hintText: 'مثال: عطل مركبة، حادث، تأخر...'),
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (selectedDriverId == null || reasonCtrl.text.trim().isEmpty) {
                        showError(dialogCtx, 'يرجى اختيار سائق جديد وتوضيح السبب');
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
                        if (dialogCtx.mounted) showError(dialogCtx, 'فشل التحويل: $e');
                      }
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تأكيد التحويل'),
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
          title: const Text('إسناد سائق يدوياً'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الطلب #${order.orderNumber} — تعذّر إيجاد سائق تلقائياً.'),
              const SizedBox(height: 14),
              AppStreamBuilder<List<Driver>>(
                stream: service.streamDrivers,
                builder: (ctx, allDrivers) {
                  final drivers = allDrivers.where((d) => d.isOnline && d.isAvailable).toList();
                  if (drivers.isEmpty) {
                    return const Text('لا يوجد سائقون متاحون حالياً',
                        style: TextStyle(color: Colors.orange));
                  }
                  return DropdownButtonFormField<String>(
                    value: selectedDriverId,
                    decoration: const InputDecoration(labelText: 'السائق'),
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
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (selectedDriverId == null) {
                        showError(dialogCtx, 'يرجى اختيار سائق');
                        return;
                      }
                      setState(() => loading = true);
                      try {
                        await service.assignDriver(order.id, selectedDriverId!, selectedDriverName!);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      } catch (e) {
                        setState(() => loading = false);
                        if (dialogCtx.mounted) showError(dialogCtx, 'فشل الإسناد: $e');
                      }
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تأكيد الإسناد'),
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
