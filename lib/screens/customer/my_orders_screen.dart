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
                              fontWeight: FontWeight.w700, fontSize: 14),
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
                          fontSize: 12,
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
                                fontSize: 12, color: AppColors.textGray)),
                      ]),
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