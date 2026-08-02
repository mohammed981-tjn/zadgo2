// lib/screens/admin/order_tracking_tab.dart
//
// شاشة متابعة الطلبات الحية في لوحة المدير: تعرض كل الطلبات النشطة/القادمة
// مع تفاصيلها والسائق المعين، وتتيح للمدير تحويل الطلب لسائق آخر عند الطوارئ
// (عطل مركبة، حادث، إلخ) دون التأثير على آلية استقبال السائق الأول.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../customer/order_map_screen.dart';

class OrderTrackingTab extends StatelessWidget {
  const OrderTrackingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Order>>(
      stream: service.streamActiveOrders(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const AppLoading();
        final orders = snap.data!;
        if (orders.isEmpty) {
          return const AppEmpty(emoji: '🛰️', title: 'لا يوجد طلبات نشطة حالياً');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (_, i) => _TrackedOrderCard(order: orders[i]),
        );
      },
    );
  }
}

class _TrackedOrderCard extends StatelessWidget {
  final Order order;
  const _TrackedOrderCard({required this.order});

  String _elapsedLabel() {
    final elapsed = DateTime.now().difference(order.createdAt);
    // تقدير تقريبي لوقت التسليم المتوقع (30 دقيقة من إنشاء الطلب) حتى تتوفر بيانات تاريخية أدق.
    const expectedMinutes = 30;
    final remaining = expectedMinutes - elapsed.inMinutes;
    if (remaining <= 0) return 'متأخر عن الوقت المتوقع';
    return 'الوقت المتبقي المتوقع: ~$remaining د';
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final isLate = DateTime.now().difference(order.createdAt).inMinutes > 30;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLate ? const BorderSide(color: Colors.redAccent, width: 1.2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            StatusBadge(label: order.status.label, color: order.status.color),
          ]),
          InfoRow(icon: Icons.restaurant, text: order.restaurantName),
          InfoRow(icon: Icons.person, text: order.customerName),
          InfoRow(
              icon: Icons.delivery_dining,
              text: order.driverName != null && order.driverName!.isNotEmpty
                  ? 'السائق: ${order.driverName}'
                  : 'لم يُعيّن سائق بعد'),
          InfoRow(icon: Icons.timer_outlined, text: _elapsedLabel()),
          OrderTrackingTimeline(status: order.status),
          Text(formatCurrency(order.grandTotal),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          if (order.status == OrderStatus.outForDelivery) ...[
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
          if (order.status.isActive) ...[
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
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent)),
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
              StreamBuilder<List<Driver>>(
                stream: service.streamDrivers(),
                builder: (ctx, dSnap) {
                  final drivers = (dSnap.data ?? [])
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
}
