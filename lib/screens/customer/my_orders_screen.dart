// lib/screens/customer/my_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/cart_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/app_skeletons.dart';
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
  const _OrdersList({required this.orders, required this.emptyTitle});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return AppEmpty(emoji: '📋', title: emptyTitle);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, i) => _OrderCard(order: orders[i]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final auth = context.read<app_auth.AuthProvider>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // رقم الطلب يفتح الفاتورة التفصيلية — أوضح مدخل يبحث عنه
              // العميل («وين أشوف فاتورتي؟»).
              InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => OrderReceiptScreen(order: order))),
                borderRadius: BorderRadius.circular(6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('#${order.orderNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.receipt_long_outlined,
                      size: 16, color: AppColors.textGray),
                ]),
              ),
              const Spacer(),
              if (order.status == OrderStatus.pickedUp ||
                  order.status == OrderStatus.onTheWay) ...[
                // الاتصال بالسائق — متاح بعد استلامه الطلب من المطعم فقط،
                // وهي الفترة التي قد يحتاج فيها الطرفان التواصل المباشر.
                if (order.driverPhone != null && order.driverPhone!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone, color: AppColors.success),
                    onPressed: () => callPhone(context, order.driverPhone),
                    tooltip: 'الاتصال بالسائق',
                  ),
                if (order.driverId != null)
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: AppColors.secondary),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => OrderChatScreen(order: order))),
                    tooltip: 'محادثة السائق',
                  ),
                if (order.restaurantLat != null || order.deliveryLat != null)
                  IconButton(
                    icon: const Icon(Icons.map_outlined, color: AppColors.secondary),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => OrderMapScreen(order: order))),
                    tooltip: 'عرض الخريطة',
                  ),
              ],
              StatusBadge(
                  label: order.status.label,
                  color: order.status.color,
                  icon: order.status.icon),
            ]),
            InfoRow(icon: Icons.restaurant_outlined, text: order.restaurantName),
            InfoRow(
                icon: Icons.access_time,
                text:
                    '${order.createdAt.day}/${order.createdAt.month} ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}'),
            OrderTrackingTimeline(status: order.status),
            const Divider(),
            Text(formatCurrency(order.grandTotal),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
            // إعادة الطلب بضغطة — أرخص ميزة تزيد تكرار الشراء (معيار جاهز/
            // كيتا): تُبنى السلة من القائمة الحالية للمطعم (أسعار وتوفّر
            // اليوم)، ويُبلَّغ العميل بما لم يعد متوفراً بدل فشل صامت.
            if (!order.status.isActive)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('اطلب مجدداً'),
                    onPressed: () => _reorder(context),
                  ),
                ),
              ),
            if (order.status == OrderStatus.delivered && !order.isRated)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showRateDialog(context, service, order),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                    child: const Text('قيّم الطلب'),
                  ),
                ),
              ),
            if (order.isRated && order.customerRating != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text('تقييمك: ${order.customerRating!.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                ]),
              ),
            // إلغاء الطلب — متاح للعميل فقط قبل أن يبدأ المطعم التحضير؛ بعدها
            // يصبح الإلغاء إدارياً (المطعم بدأ يتكبّد التكلفة).
            if (order.canCustomerCancel)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('إلغاء الطلب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: () => _cancelOrder(context, service),
                  ),
                ),
              )
            else if (order.status.isActive)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 15, color: AppColors.textGray),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('بدأ تحضير طلبك — للإلغاء تواصل مع الإدارة',
                        style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                  ),
                ]),
              ),
            // الشكوى: زر واضح بدل أيقونة غامضة. تبقى متاحة بعد التسليم خلال
            // مهلة 24 ساعة (وقت اكتشاف النقص/الخطأ/الجودة)، ثم يُغلق الطلب.
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: order.canSubmitComplaint
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.report_problem_outlined, size: 18),
                        label: Text(_complaintLabel()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                        ),
                        onPressed: () => _openComplaint(context, auth),
                      ),
                    )
                  : Row(children: [
                      const Icon(Icons.lock_outline, size: 15, color: AppColors.textGray),
                      const SizedBox(width: 6),
                      const Text('انتهت مهلة تقديم الشكوى',
                          style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                    ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reorder(BuildContext context) async {
    final service = context.read<FirebaseService>();
    final cart = context.read<CartProvider>();

    // سلة فيها أصناف من مطعم آخر ستُفرَّغ (قاعدة «مطعم واحد للسلة») —
    // بموافقة صريحة لا بمسح صامت.
    if (!cart.isEmpty && cart.restaurantId != order.restaurantId) {
      final ok = await showConfirmDialog(
        context,
        title: 'استبدال السلة؟',
        content:
            'سلتك تحوي أصنافاً من ${cart.restaurantName ?? 'مطعم آخر'} — '
            'ستُستبدل بأصناف هذا الطلب.',
        confirmLabel: 'استبدال',
      );
      if (ok != true || !context.mounted) return;
    }

    try {
      final restaurant = await service.getRestaurantOnce(order.restaurantId);
      if (restaurant == null) {
        if (context.mounted) showError(context, 'هذا المطعم لم يعد متوفراً');
        return;
      }
      if (!restaurant.isOpen) {
        if (context.mounted) {
          showError(context, '${restaurant.name} مغلق حالياً — جرّب لاحقاً');
        }
        return;
      }

      final menu = await service.getMenuItemsOnce(order.restaurantId);
      final byId = {for (final m in menu) m.id: m};

      var added = 0, skipped = 0;
      for (final oi in order.items) {
        final current = byId[oi.menuItemId];
        if (current == null || !current.isAvailable) {
          skipped++;
          continue;
        }
        // استرجاع خيارات الطلب القديم بأسمائها من القائمة الحالية؛ الخيار
        // الذي حُذف من القائمة يسقط، والمجموعة الإلزامية بلا اختيار مسترجَع
        // تأخذ خيارها الأول — فلا يدخل السلة صنفُ خياراتٍ ناقصُ إلزامي.
        final oldNames = (oi.extras ?? '')
            .split(' • ')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        final selections = <ItemOption>[];
        for (final group in current.optionGroups) {
          final matched =
              group.options.where((o) => oldNames.contains(o.name)).toList();
          if (group.multiSelect) {
            selections.addAll(matched);
          } else if (group.options.isNotEmpty) {
            selections.add(matched.isNotEmpty ? matched.first : group.options.first);
          }
        }
        for (var q = 0; q < oi.quantity; q++) {
          cart.add(current, restaurant.id, restaurant.name, restaurant.emoji,
              restaurant.driverShareFee, restaurant.appShareFee, selections);
        }
        added++;
      }

      if (!context.mounted) return;
      if (added == 0) {
        showError(context, 'أصناف هذا الطلب لم تعد متوفرة في القائمة');
        return;
      }
      if (skipped > 0) {
        showSuccess(context,
            'أُضيف $added من الأصناف — و$skipped لم يعد متوفراً فتُرك');
      }
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CartScreen()));
    } catch (_) {
      if (context.mounted) {
        showError(context, 'تعذّر تجهيز السلة — تحقق من اتصالك وحاول مجدداً');
      }
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
      if (context.mounted) showSuccess(context, 'تم إلغاء الطلب');
    } catch (_) {
      if (context.mounted) {
        showError(context, 'تعذّر الإلغاء — قد يكون التحضير قد بدأ');
      }
    }
  }

  /// نص زر الشكوى — يُظهر ما تبقّى من المهلة على الطلبات المنتهية حتى يعرف
  /// العميل أن الوقت محدود، بدل أن يفاجئه الإغلاق.
  String _complaintLabel() {
    final left = order.complaintTimeLeft;
    if (left == null) return 'تقديم شكوى';
    final hours = left.inHours;
    if (hours >= 1) return 'تقديم شكوى (متبقٍ $hours ساعة)';
    return 'تقديم شكوى (متبقٍ ${left.inMinutes} دقيقة)';
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