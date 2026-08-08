// lib/screens/admin/admin_complaint_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

/// تفاصيل شكوى واحدة — بيانات الطرفين، دردشة داخلية مع مقدّم الشكوى،
/// وثلاثة إجراءات حل فعلية (استرداد جزئي / إنذار / نقل لسائق آخر) تُطبَّق
/// معاً عبر resolveComplaint في عملية واحدة.
class AdminComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;
  const AdminComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<AdminComplaintDetailScreen> createState() => _AdminComplaintDetailScreenState();
}

class _AdminComplaintDetailScreenState extends State<AdminComplaintDetailScreen> {
  final _chatCtrl = TextEditingController();
  bool _resolving = false;

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _call(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: trimmed);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) showError(context, 'تعذّر فتح تطبيق الاتصال');
    } catch (_) {
      if (mounted) showError(context, 'تعذّر فتح تطبيق الاتصال');
    }
  }

  Future<void> _sendChatMessage(String adminUid, String adminName) async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();
    final service = context.read<FirebaseService>();
    await service.sendComplaintChatMessage(ChatMessage(
      id: const Uuid().v4(),
      orderId: widget.complaint.id,
      senderId: adminUid,
      senderName: adminName,
      senderRole: UserRole.admin.name,
      text: text,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _showResolveDialog(BuildContext context, Order order) async {
    double? refundPercentage;
    bool warnParty = false;
    Driver? reassignTo;
    final service = context.read<FirebaseService>();
    final auth = context.read<app_auth.AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx2, setDialogState) => AlertDialog(
          title: const Text('حل الشكوى'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('استرداد جزئي (نسبة من قيمة الطلب)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [0, 10, 20, 50, 100].map((pct) {
                final selected = refundPercentage == pct.toDouble();
                return ChoiceChip(
                  label: Text(pct == 0 ? 'بلا استرداد' : '$pct%'),
                  selected: selected,
                  onSelected: (_) => setDialogState(() => refundPercentage = pct == 0 ? null : pct.toDouble()),
                );
              }).toList()),
              if (refundPercentage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'سيُضاف ${(order.grandTotal * (refundPercentage! / 100)).toStringAsFixed(2)} ر.س لمحفظة العميل',
                    style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ),
              const Divider(height: 24),
              if (widget.complaint.againstRole == UserRole.driver) ...[
                CheckboxListTile(
                  value: warnParty,
                  onChanged: (v) => setDialogState(() => warnParty = v ?? false),
                  title: const Text('تسجيل إنذار للسائق', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('3 إنذارات = تعليق تلقائي للسائق', style: TextStyle(fontSize: 11)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(height: 24),
              ],
              const Text('نقل الطلب لسائق آخر (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              AppStreamBuilder<List<Driver>>(
                stream: service.streamDrivers,
                builder: (ctx, drivers) {
                  final others = drivers.where((d) => d.id != order.driverId).toList();
                  if (others.isEmpty) {
                    return const Text('لا يوجد سائقون آخرون', style: TextStyle(fontSize: 12, color: AppColors.textGray));
                  }
                  return DropdownButtonFormField<Driver>(
                    value: reassignTo,
                    isExpanded: true,
                    decoration: const InputDecoration(hintText: 'اختر سائقاً (اختياري)'),
                    items: others.map((d) => DropdownMenuItem(
                          value: d,
                          child: Text('${d.name} ${d.isOnline ? "🟢" : "⚪"}', overflow: TextOverflow.ellipsis),
                        )).toList(),
                    onChanged: (v) => setDialogState(() => reassignTo = v),
                  );
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('تأكيد الحل'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _resolving = true);
    try {
      await service.resolveComplaint(
        complaint: widget.complaint,
        order: order,
        adminUid: auth.user?.uid ?? '',
        refundPercentage: refundPercentage,
        warnAgainstParty: warnParty,
        reassignToDriverId: reassignTo?.id,
        reassignToDriverName: reassignTo?.name,
      );
      if (mounted) {
        showSuccess(context, 'تم حل الشكوى بنجاح');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showError(context, 'تعذّر حل الشكوى، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final service = context.read<FirebaseService>();
    final auth = context.read<app_auth.AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('شكوى #${c.orderNumber}')),
      body: StreamBuilder<Order?>(
        stream: service.streamOrder(c.orderId),
        builder: (ctx, orderSnap) {
          final order = orderSnap.data;
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  StatusBadge(label: c.status.label, color: c.status.color, icon: Icons.circle),
                  const Spacer(),
                  Chip(label: Text(c.type.label)),
                ]),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('تفاصيل الشكوى', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(c.description, style: const TextStyle(fontSize: 13.5)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('الأطراف', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _PartyRow(label: 'مقدّم الشكوى', name: c.submittedByName, role: c.submittedByRole),
                      if (c.againstRole != null) ...[
                        const SizedBox(height: 8),
                        _PartyRow(label: 'الشكوى ضد', name: c.againstRole!.label, role: c.againstRole),
                      ],
                      if (order != null) ...[
                        const Divider(height: 20),
                        InfoRow(icon: Icons.receipt_long_outlined, text: 'قيمة الطلب: ${formatCurrency(order.grandTotal)}'),
                        if (order.customerPhone.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: OutlinedButton.icon(
                              onPressed: () => _call(order.customerPhone),
                              icon: const Icon(Icons.call_outlined, size: 16),
                              label: Text('اتصال بالعميل: ${order.customerPhone}'),
                            ),
                          ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('محادثة مع مقدّم الشكوى', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                StreamBuilder<List<ChatMessage>>(
                  stream: service.streamComplaintChat(c.id),
                  builder: (ctx, chatSnap) {
                    final messages = chatSnap.data ?? [];
                    if (messages.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('لا توجد رسائل بعد', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                      );
                    }
                    return Column(
                      children: messages.map((m) {
                        final isAdmin = m.senderRole == UserRole.admin.name;
                        return Align(
                          alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isAdmin ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m.senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(m.text, style: const TextStyle(fontSize: 13.5)),
                            ]),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ]),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: () => _sendChatMessage(auth.user?.uid ?? '', auth.user?.name ?? 'المدير'),
                  ),
                ]),
              ),
            ),
            if (c.status != ComplaintStatus.resolved && c.status != ComplaintStatus.closed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (order == null || _resolving) ? null : () => _showResolveDialog(context, order),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    icon: _resolving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('حل الشكوى', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  final String label;
  final String name;
  final UserRole? role;
  const _PartyRow({required this.label, required this.name, this.role});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        if (role != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(role!.label, style: const TextStyle(fontSize: 10, color: AppColors.primary)),
          ),
      ]);
}