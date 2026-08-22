// lib/screens/admin/admin_audit_screen.dart
//
// «سجلّ الإدارة» (نواقص لا-Blaze 2026-08-20): كل فعلٍ إداري حسّاس —
// إلغاء طلب، رفع حظر، صرف استرداد، تعديل حوافز، إنشاء مستخدم — يُختم في
// `admin_audit` من الجوّال والويب معاً. كان يُكتب بأمانة **ولا شاشة
// تقرؤه**، فسجلٌّ لا يُرى لا يردع أحداً ولا يكشف تصرّفاً. هنا يراه المالك:
// من فعل ماذا ومتى، من أي جهاز.
//
// القيود متغايرة الحقول (لكل فعلٍ extra مختلف)، فنعرض المشترك (الفعل،
// الملخّص، الفاعل، الوقت، المصدر) ونتجاهل الباقي بلا كسر.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/firebase_service.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Map<String, dynamic>>>(
      stream: () => service.streamAdminAudit(),
      builder: (ctx, entries) {
        if (entries.isEmpty) {
          return AppEmpty(
              emoji: '📋',
              title: tr('لا قيود بعد', 'No entries yet'),
              subtitle: tr('كل فعلٍ إداري حسّاس يُسجَّل هنا تلقائياً.',
                  'Every sensitive admin action is logged here automatically.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _AuditCard(entry: entries[i]),
        );
      },
    );
  }
}

class _AuditCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _AuditCard({required this.entry});

  String get _who {
    final name = (entry['byName'] ?? '').toString().trim();
    final email = (entry['byEmail'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    return tr('مسؤول', 'Admin');
  }

  String get _when {
    final ts = entry['createdAt'];
    if (ts is Timestamp) return formatDateTime(ts.toDate());
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    // المصدر: الجوّال ('app') أو الويب — تمييزٌ يعرف به المالك من أي
    // لوحةٍ وقع الفعل حين يختلف السلوك بينهما.
    final web = (entry['source'] ?? '') != 'app';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(web ? Icons.language : Icons.smartphone,
                size: 15, color: AppColors.textGray),
            const SizedBox(width: 6),
            Expanded(
              child: Text((entry['action'] ?? tr('فعل', 'Action')).toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
            Text(_when,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textGray)),
          ]),
          if ((entry['summary'] ?? '').toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(entry['summary'].toString(),
                  style: const TextStyle(fontSize: 12.5)),
            ),
          const SizedBox(height: 4),
          Text(tr('بواسطة: $_who${web ? ' • من الويب' : ' • من التطبيق'}',
                  'By: $_who${web ? ' • via web' : ' • via app'}'),
              style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
        ]),
      ),
    );
  }
}
