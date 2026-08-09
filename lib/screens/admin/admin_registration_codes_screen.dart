// lib/screens/admin/admin_registration_codes_screen.dart
//
// إدارة أكواد التسجيل — كانت الأكواد تُولَّد ثم تختفي عن العين: لا شاشة
// تعرض المتاح منها ولا وسيلة لإلغاء كودٍ أُرسل بالخطأ (دالة الإلغاء كانت
// موجودة بلا واجهة). هنا: كل الأكواد بحالاتها (متاح/مستخدَم/منتهٍ)، مع
// نسخ المتاح وإلغائه.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminRegistrationCodesScreen extends StatelessWidget {
  const AdminRegistrationCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<RegistrationCode>>(
      stream: () => service.streamAllRegistrationCodes(),
      builder: (ctx, codes) {
        if (codes.isEmpty) {
          return const AppEmpty(
              emoji: '🔑',
              title: 'لا توجد أكواد تسجيل',
              subtitle: 'ولّدها من شاشة المستخدمين — زر «توليد كود تسجيل»');
        }
        final available =
            codes.where((c) => !c.isUsed && !c.isExpired).toList();
        final finished =
            codes.where((c) => c.isUsed || c.isExpired).toList();

        return ListView(padding: const EdgeInsets.all(12), children: [
          if (available.isNotEmpty) ...[
            SectionHeader(title: 'متاحة (${available.length})'),
            ...available.map((c) => _CodeCard(code: c)),
            const SizedBox(height: 12),
          ],
          if (finished.isNotEmpty) ...[
            const SectionHeader(title: 'السجلّ'),
            ...finished.map((c) => _CodeCard(code: c)),
          ],
        ]);
      },
    );
  }
}

class _CodeCard extends StatelessWidget {
  final RegistrationCode code;
  const _CodeCard({required this.code});

  String _fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = code;
    final service = context.read<FirebaseService>();
    final (statusLabel, statusColor) = c.isUsed
        ? ('مستخدَم', AppColors.textGray)
        : c.isExpired
            ? ('منتهٍ', AppColors.error)
            : ('متاح', AppColors.success);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(c.code,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 15,
                      color: statusColor)),
            ),
            const SizedBox(width: 8),
            Text(c.role.label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            StatusChip(label: statusLabel, color: statusColor),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              if (c.restaurantName.isNotEmpty) 'مطعم: ${c.restaurantName}',
              'أُنشئ ${_fmt(c.createdAt)}',
              if (c.expiresAt != null)
                '${c.isExpired ? 'انتهى' : 'ينتهي'} ${_fmt(c.expiresAt!)}',
              if (c.isUsed && (c.usedByName ?? '').isNotEmpty)
                'استخدمه: ${c.usedByName}',
            ].join(' • '),
            style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
          ),
          if (!c.isUsed) ...[
            const SizedBox(height: 4),
            Row(children: [
              if (!c.isExpired)
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: c.code));
                    if (context.mounted) showSuccess(context, 'نُسخ الكود');
                  },
                  icon: const Icon(Icons.copy_outlined, size: 15),
                  label: const Text('نسخ', style: TextStyle(fontSize: 12)),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () async {
                  final ok = await showConfirmDialog(context,
                      title: 'إلغاء الكود',
                      content:
                          'حذف ${c.code} نهائياً؟ لن يستطيع أحد استخدامه بعدها.',
                      confirmLabel: 'إلغاء الكود',
                      confirmColor: AppColors.error);
                  if (ok == true) {
                    await service.revokeRegistrationCode(c.code);
                    if (context.mounted) showSuccess(context, 'أُلغي الكود');
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('إلغاء', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
