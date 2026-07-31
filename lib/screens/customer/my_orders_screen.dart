// lib/screens/customer/my_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'order_map_screen.dart';
import 'order_chat_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final uid = context.read<app_auth.AuthProvider>().user?.uid ?? '';

    return StreamBuilder<List<Order>>(
      stream: service.streamCustomerOrders(uid),
      builder: (ctx, snap) {
        if (!snap.hasData) return const AppLoading();
        final orders = snap.data!;
        if (orders.isEmpty) {
          return const AppEmpty(emoji: '📋', title: 'لا يوجد طلبات');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (_, i) => _OrderCard(order: orders[i]),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('#${order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (order.driverId != null)
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: AppColors.secondary),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => OrderChatScreen(order: order))),
                  tooltip: 'محادثة السائق',
                ),
              IconButton(
                  icon: const Icon(Icons.report_problem_outlined, color: AppColors.restaurantAccent),
                  onPressed: () => _showComplaintDialog(context, service, order),
                  tooltip: 'إرسال شكوى',
              ),
              if (order.restaurantLat != null || order.deliveryLat != null)                IconButton(
                  icon: const Icon(Icons.map_outlined, color: AppColors.secondary),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => OrderMapScreen(order: order))),
                  tooltip: 'عرض الخريطة',
                ),
              StatusBadge(
                  label: order.status.label,
                  color: order.status.color,
                  icon: order.status.icon),
            ]),
            InfoRow(icon: Icons.restaurant, text: order.restaurantName),
            InfoRow(
                icon: Icons.access_time,
                text:
                    '${order.createdAt.day}/${order.createdAt.month} ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}'),
            const Divider(),
            Text(formatCurrency(order.grandTotal),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
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
          ],
        ),
      ),
    );
  }

  void _showComplaintDialog(BuildContext context, FirebaseService service, Order o) {
    final descriptionCtrl = TextEditingController();
    ComplaintType selectedType = ComplaintType.other;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => AlertDialog(
          title: const Text('إرسال شكوى'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('اختر نوع الشكوى', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: ComplaintType.values.map((type) {
                final selected = type == selectedType;
                return ChoiceChip(
                  label: Text(type.label),
                  selected: selected,
                  onSelected: (_) => setState(() => selectedType = type),
                );
              }).toList()),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'وصف المشكلة'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final text = descriptionCtrl.text.trim();
                if (text.isEmpty) {
                  if (context.mounted) showError(context, 'اكتب وصفاً للشكوى');
                  return;
                }
                final complaint = Complaint(
                  id: const Uuid().v4(),
                  orderId: o.id,
                  orderNumber: o.orderNumber,
                  customerId: o.customerId,
                  customerName: o.customerName,
                  restaurantId: o.restaurantId,
                  restaurantName: o.restaurantName,
                  type: selectedType,
                  description: text,
                  createdAt: DateTime.now(),
                );
                await service.submitComplaint(complaint);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  showSuccess(context, 'تم إرسال الشكوى بنجاح');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.restaurantAccent),
              child: const Text('إرسال'),
            ),
          ],
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
