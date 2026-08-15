// lib/screens/admin/admin_restaurant_requests_screen.dart
//
// لوحة «طلبات المطاعم» (ح5 — من خطة الإطلاق): كل بحثِ عميلٍ خائب تحوّل
// إلى ضغطة «اطلب إضافته»، وهنا تتجمع الضغطات مرتّبةً بالعدد — فتصير
// خريطة مبيعات حرفياً: «٤٠ عميلاً طلبوك هذا الأسبوع» أقوى جملة تدخل
// بها على صاحب مطعم.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

class AdminRestaurantRequestsScreen extends StatelessWidget {
  const AdminRestaurantRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<RestaurantRequest>>(
      stream: service.streamRestaurantRequests,
      builder: (ctx, requests) {
        if (requests.isEmpty) {
          return const AppEmpty(
              emoji: '🗺️',
              title: 'لا طلبات بعد',
              subtitle:
                  'حين يبحث عميل عن مطعم غير موجود ويضغط «اطلب إضافته» يظهر هنا');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (_, i) {
            final r = requests[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text('${r.count}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark)),
                ),
                title: Text(r.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${r.count} ${r.count >= 3 && r.count <= 10 ? "عملاء طلبوه" : "عميلاً طلبه"}'
                    ' — آخرهم ${formatDateTime(r.lastRequestedAt)}',
                    style: const TextStyle(fontSize: 12.5)),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('أُضيف'),
                  onPressed: () async {
                    // «أُضيف» بعد توقيع المطعم فعلاً: يحذف الطلب من
                    // القائمة، وبثُّ الخبر للعملاء («مطعمكم وصل!») من
                    // شاشة البث — خبرٌ يستحق صياغتك لا قالباً آلياً.
                    final ok = await showConfirmDialog(context,
                        title: 'أُضيف «${r.name}»؟',
                        content:
                            'يُحذف من قائمة الطلبات. لا تنسَ بثّ الخبر لعملائك '
                            'من شاشة «بث جماعي» — من طلبوه ينتظرونه.',
                        confirmLabel: 'أُضيف');
                    if (ok == true) {
                      await service.removeRestaurantRequest(r.id);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
