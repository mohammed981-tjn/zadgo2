// lib/screens/admin/admin_suggestions_screen.dart
//
// «اقتراحات ونصائح» (2026-08-20، بطلب المالك): يقرأ المدير هنا ما يكتبه
// الزوّار والمستخدمون في قناة الصوت العامة — كلٌّ بنصّه ووقته، ومعلومات
// التواصل إن تركها صاحبها. يحذف المزعج، ويتّصل بصاحب الفكرة الجيدة.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminSuggestionsScreen extends StatelessWidget {
  const AdminSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Suggestion>>(
      stream: () => service.streamSuggestions(),
      builder: (ctx, items) {
        if (items.isEmpty) {
          return AppEmpty(
              emoji: '💡',
              title: tr('لا اقتراحات بعد', 'No suggestions yet'),
              subtitle: tr('ما يكتبه الزوّار من اقتراحات ونصائح يظهر هنا.',
                  'Suggestions and tips written by visitors show up here.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _SuggestionCard(item: items[i]),
        );
      },
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Suggestion item;
  const _SuggestionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasContact =
        (item.name ?? '').isNotEmpty || (item.phone ?? '').isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(formatDateTime(item.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textGray)),
            ),
            IconButton(
              tooltip: tr('حذف', 'Delete'),
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final ok = await showConfirmDialog(context,
                    title: tr('حذف الاقتراح؟', 'Delete this suggestion?'),
                    content: tr('يُحذف نهائياً من السجلّ.',
                        'It will be permanently removed from the log.'),
                    confirmLabel: tr('حذف', 'Delete'),
                    confirmColor: AppColors.error);
                if (ok == true && context.mounted) {
                  await context
                      .read<FirebaseService>()
                      .deleteSuggestion(item.id);
                }
              },
            ),
          ]),
          Text(item.text, style: const TextStyle(fontSize: 13.5)),
          if (hasContact) ...[
            const Divider(height: 16),
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.textGray),
              const SizedBox(width: 4),
              Text(
                  '${item.name ?? '—'}'
                  '${(item.phone ?? '').isNotEmpty ? '  •  ${item.phone}' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textDark)),
            ]),
          ],
        ]),
      ),
    );
  }
}
