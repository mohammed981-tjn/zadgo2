// lib/screens/restaurant/restaurant_reviews_tab.dart
//
// «التقييمات» لمدير المطعم (يوم المطعم 2026-08-20): كان المطعم أعمى عن
// تقييماته — تُجمع على مستنده متوسطاً صامتاً ولا يرى نصاً ولا نجمة ولا
// يملك رداً. هنا يراها كلها ويردّ **مرة واحدة لكل تقييم**، وردُّه يظهر
// للعميل تحت تقييمه في «طلباتي»: الردّ العلني المهذّب يكسب قارئَه حتى
// حين يعتذر — وهو أرخص أدوات استرجاع عميلٍ غاضب.
//
// المصدر طلبات المطعم المُقيَّمة (نافذة آخر ٢٠٠ طلب — التقييم حديثُ
// العهد بطبيعته، والتاريخ الأقدم في التقارير لا هنا).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/app_lang.dart';
import '../../widgets/common_widgets.dart';

class RestaurantReviewsTab extends StatelessWidget {
  final String restaurantId;
  const RestaurantReviewsTab({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Order>>(
      stream: () => service.streamRestaurantOrders(restaurantId),
      builder: (ctx, orders) {
        final rated = orders
            .where((o) => o.isRated && o.customerRating != null)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (rated.isEmpty) {
          return AppEmpty(
              emoji: '⭐',
              title: tr('لا تقييمات بعد', 'No reviews yet'),
              subtitle: tr(
                  'حين يقيّم عملاؤك طلباتهم تظهر هنا وتستطيع الرد عليها.',
                  'When customers rate their orders, reviews appear here and you can reply.'));
        }
        final avg = rated.fold(0.0, (s, o) => s + (o.customerRating ?? 0)) /
            rated.length;
        return ListView(padding: const EdgeInsets.all(12), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.warning, size: 28),
                const SizedBox(width: 8),
                Text(avg.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(
                    tr('من ${rated.length} تقييم ضمن آخر ${orders.length} طلب',
                        'from ${rated.length} reviews across the last ${orders.length} orders'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textGray)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          ...rated.map((o) => _ReviewCard(order: o)),
        ]);
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Order order;
  const _ReviewCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final rating = o.customerRating ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (var i = 1; i <= 5; i++)
              Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: i <= rating ? AppColors.warning : AppColors.divider),
            const SizedBox(width: 8),
            Text('#${o.orderNumber}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textGray)),
            const Spacer(),
            Text(formatDateTime(o.createdAt),
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.textGray)),
          ]),
          if ((o.customerReview ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('«${o.customerReview!.trim()}»',
                  style: const TextStyle(fontSize: 13.5)),
            ),
          const SizedBox(height: 8),
          if ((o.restaurantReply ?? '').trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                  tr('ردّكم: ${o.restaurantReply}',
                      'Your reply: ${o.restaurantReply}'),
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textDark)),
            )
          else
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: Text(tr('ردّ على التقييم', 'Reply to review'),
                    style: const TextStyle(fontSize: 12.5)),
                onPressed: () => _reply(context),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _reply(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(tr('الردّ على تقييم #${order.orderNumber}',
            'Reply to review #${order.orderNumber}')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 300,
          decoration: InputDecoration(
            hintText: tr(
                'ردٌّ مهذّب يظهر للعميل تحت تقييمه — ولا يُعدَّل بعد الإرسال',
                'A polite reply shown to the customer under their review — cannot be edited after sending'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr('إلغاء', 'Cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(tr('إرسال', 'Send'))),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty || !context.mounted) return;
    try {
      await context
          .read<FirebaseService>()
          .replyToOrderReview(order.id, ctrl.text);
      if (context.mounted) {
        showSuccess(
            context,
            tr('أُرسل ردّكم وسيراه العميل',
                'Your reply was sent and the customer will see it'));
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر إرسال الرد', 'Failed to send reply'));
      }
    }
  }
}
