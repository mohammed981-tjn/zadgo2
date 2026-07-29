if (mode == _CardMode.available) {
  return SizedBox(width: double.infinity, child: ElevatedButton.icon(
    onPressed: () async {
      final ok = await showConfirmDialog(ctx, title: 'قبول الطلب', content: 'هل تريد قبول هذا الطلب والتوجه للمطعم؟', confirmLabel: 'قبول');
      if (ok == true) {
        await service.assignDriver(order.id, auth.user!.uid, auth.user!.name);
        if (ctx.mounted) {
          showSuccess(ctx, 'تم قبول الطلب! توجّه للمطعم');
          // ✅ فتح الخريطة تلقائياً
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => OrderMapScreen(order: order)));
        }
      }
    },
    icon: const Icon(Icons.check_circle_outline),
    label: const Text('قبول الطلب'),
  ));
}