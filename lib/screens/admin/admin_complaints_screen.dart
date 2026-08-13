// lib/screens/admin/admin_complaints_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'admin_complaint_detail_screen.dart';

/// شاشة إدارة الشكاوى — تعرض شكاوى الأطراف الثلاثة (عميل/سائق/مطعم) معاً،
/// مرتّبة افتراضياً بالأولوية: مفتوحة أولاً ← قيد المعالجة ← محلولة/مغلقة
/// أخيراً، مع فلتر يدوي اختياري فوقها.
class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  ComplaintStatus? _filter;

  /// ترتيب أولوية العرض الافتراضي: مفتوحة (الأكثر إلحاحاً) أولاً، ثم قيد
  /// المعالجة، ثم المحلولة/المغلقة أخيراً — بصرف النظر عن تاريخ التقديم،
  /// حتى لا تُدفن شكوى عاجلة قديمة خلف شكاوى محلولة حديثة.
  int _statusPriority(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.open:
        return 0;
      case ComplaintStatus.inProgress:
        return 1;
      case ComplaintStatus.resolved:
        return 2;
      case ComplaintStatus.closed:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return AppStreamBuilder<List<Complaint>>(
      stream: service.streamComplaints,
      builder: (ctx, all) {
        final filtered = _filter == null
            ? all
            : all.where((c) => c.status == _filter).toList();

        filtered.sort((a, b) {
          final priorityDiff = _statusPriority(a.status).compareTo(_statusPriority(b.status));
          if (priorityDiff != 0) return priorityDiff;
          return b.createdAt.compareTo(a.createdAt);
        });

        // عدد شكاوى كل طرف "متَّهم" — يُستخدم لعرض مؤشر التكرار على كل
        // بطاقة ("هذا الطرف عليه X شكوى أخرى")، بغض النظر عن الفلتر الحالي
        // (نحسبه من all وليس filtered لعرض الصورة الكاملة دائماً).
        final againstCounts = <String, int>{};
        for (final c in all) {
          if (c.againstUid != null) {
            againstCounts[c.againstUid!] = (againstCounts[c.againstUid!] ?? 0) + 1;
          }
        }

        return Column(children: [
          _FilterBar(
            current: _filter,
            onChanged: (s) => setState(() => _filter = s),
            openCount: all.where((c) => c.status == ComplaintStatus.open).length,
          ),
          Expanded(
            child: filtered.isEmpty
                ? const AppEmpty(emoji: '✅', title: 'لا يوجد شكاوى مطابقة')
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final repeatCount = c.againstUid != null ? (againstCounts[c.againstUid!] ?? 0) : 0;
                      return _ComplaintCard(complaint: c, repeatCount: repeatCount);
                    },
                  ),
          ),
        ]);
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final ComplaintStatus? current;
  final ValueChanged<ComplaintStatus?> onChanged;
  final int openCount;
  const _FilterBar({required this.current, required this.onChanged, required this.openCount});

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip(context, label: 'الكل', value: null),
            const SizedBox(width: 8),
            _chip(context, label: openCount > 0 ? 'مفتوحة ($openCount)' : 'مفتوحة', value: ComplaintStatus.open),
            const SizedBox(width: 8),
            _chip(context, label: 'قيد المعالجة', value: ComplaintStatus.inProgress),
            const SizedBox(width: 8),
            _chip(context, label: 'محلولة', value: ComplaintStatus.resolved),
            const SizedBox(width: 8),
            _chip(context, label: 'مغلقة', value: ComplaintStatus.closed),
          ]),
        ),
      );

  Widget _chip(BuildContext context, {required String label, required ComplaintStatus? value}) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textDark,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final int repeatCount;
  const _ComplaintCard({required this.complaint, required this.repeatCount});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminComplaintDetailScreen(complaint: c)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              StatusBadge(label: c.status.label, color: c.status.color, icon: Icons.circle),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c.type.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              ),
              Text(c.isGeneralTicket ? 'تذكرة ${c.displayNumber}' : '#${c.orderNumber}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(_roleIcon(c.submittedByRole), size: 15, color: AppColors.textGray),
              const SizedBox(width: 4),
              Text(c.submittedByName, style: const TextStyle(fontSize: 13.5)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_back_rounded, size: 13, color: AppColors.textGray),
              const SizedBox(width: 6),
              if (c.againstRole != null) ...[
                Icon(_roleIcon(c.againstRole), size: 15, color: AppColors.error),
                const SizedBox(width: 4),
                Text(c.againstRole!.label, style: const TextStyle(fontSize: 13.5, color: AppColors.error)),
              ] else
                const Text('عام (بلا طرف محدد)', style: TextStyle(fontSize: 13.5, color: AppColors.textGray)),
            ]),
            if (repeatCount > 1) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.repeat_rounded, size: 13, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text('هذا الطرف عليه $repeatCount شكوى',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.warning, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
            const SizedBox(height: 6),
            Text(c.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
          ]),
        ),
      ),
    );
  }

  IconData _roleIcon(UserRole? role) {
    switch (role) {
      case UserRole.customer:
        return Icons.person_outline;
      case UserRole.driver:
        return Icons.delivery_dining_outlined;
      case UserRole.restaurantManager:
        return Icons.restaurant_outlined;
      case UserRole.admin:
      case null:
        return Icons.info_outline;
    }
  }
}