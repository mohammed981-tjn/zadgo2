// lib/screens/admin/admin_complaint_detail_screen.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../providers/ai_assist.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/app_lang.dart';
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
  void initState() {
    super.initState();
    // التدرج التلقائي (دورة حياة الشكوى — ملاحظة المالك 2026-08-16):
    // فتحُ المدير للشكوى هو بدء معالجتها فعلاً، فتنتقل «قيد المعالجة»
    // وحدها ويراها صاحبها كذلك — بدل زرّ يدوي كان يُنسى فتبقى «مفتوحة»
    // وهي تُعالج. صامت وبلا انتظار: فشله لا يعطّل الشاشة.
    if (widget.complaint.status == ComplaintStatus.open) {
      context.read<FirebaseService>().updateComplaintStatus(
          widget.complaint.id, ComplaintStatus.inProgress);
    }
  }

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
      if (!launched && mounted) showError(
          context, tr('تعذّر فتح تطبيق الاتصال', 'Could not open the phone app'));
    } catch (_) {
      if (mounted) showError(
          context, tr('تعذّر فتح تطبيق الاتصال', 'Could not open the phone app'));
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
    // الخصم على المطعم (سياسة المالك 2026-08-13): شكاوى الجودة والمطابقة
    // يتحمّل المطعم استردادها. الافتراض مسبق التحديد لهذين النوعين تحديداً
    // — والمدير يملك عكسه في كل حال (قد يتبيّن أن التلف من التأخر مثلاً).
    bool chargeRestaurant =
        widget.complaint.type == ComplaintType.badQuality ||
            widget.complaint.type == ComplaintType.wrongOrder;
    Driver? reassignTo;
    // خانة الردّ النصّي (نفذ ٢): كان مقدّم الشكوى يرى نصاً آلياً «تم الحل
    // بلا إجراء إضافي» — جوابٌ يُقرأ استخفافاً. الخانة اختيارية عمداً:
    // الإجراءات (استرداد/إنذار/نقل) تُلخَّص آلياً إن سكت المدير، لكن
    // كلمةً منه تسبقها أفضل أثراً من أدقّ تلخيص آلي.
    final resolutionCtrl = TextEditingController();
    bool aiLoading = false;
    // آخر اقتراح ذكاء في هذا الحوار (دفعة ٣): يُلتقَط عند الحلّ لمقارنته
    // بالنصّ النهائي فتُعرف النتيجة (قُبل/عُدّل/رُفض) — منجم بيانات التدريب.
    String? aiSuggestion;
    final service = context.read<FirebaseService>();
    final auth = context.read<app_auth.AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx2, setDialogState) => AlertDialog(
          title: Text(tr('حل الشكوى', 'Resolve complaint')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: resolutionCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('ردّك على مقدّم الشكوى (اختياري)',
                      'Your reply to the submitter (optional)'),
                  hintText: tr('مثال: تحقّقنا مع الكابتن وأعدنا لك قيمة الوجبة',
                      'e.g. We checked with the captain and refunded your meal'),
                  alignLabelWithHint: true,
                ),
              ),
              // زر الاقتراح (دفعة الذكاء ١): يملأ الخانة ولا يرسل شيئاً —
              // المدير يعدّل ثم يقرّر. يقرأ مسودّته إن كتبها ليذكر الإجراء
              // المتخذ بدل اختلاقه.
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: aiLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(tr('اقترح رداً', 'Suggest a reply'),
                      style: const TextStyle(fontSize: 12.5)),
                  onPressed: aiLoading
                      ? null
                      : () async {
                          setDialogState(() => aiLoading = true);
                          try {
                            final s = await AiAssist.suggestComplaintReply(
                              complaint: widget.complaint,
                              resolutionDraft: resolutionCtrl.text,
                            );
                            aiSuggestion = s;
                            resolutionCtrl.text = s;
                          } catch (e) {
                            if (mounted) {
                              showError(
                                  context,
                                  e
                                      .toString()
                                      .replaceFirst('Exception: ', ''));
                            }
                          }
                          // قد يُغلق الحوار أثناء الانتظار — لا setState
                          // على عنصر مُتخلَّص منه.
                          if (dialogCtx2.mounted) {
                            setDialogState(() => aiLoading = false);
                          }
                        },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                  tr('استرداد جزئي (نسبة من قيمة الطلب)',
                      'Partial refund (share of the order value)'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [0, 10, 20, 50, 100].map((pct) {
                final selected = refundPercentage == pct.toDouble();
                return ChoiceChip(
                  label: Text(pct == 0 ? tr('بلا استرداد', 'No refund') : '$pct%'),
                  selected: selected,
                  onSelected: (_) => setDialogState(() => refundPercentage = pct == 0 ? null : pct.toDouble()),
                );
              }).toList()),
              if (refundPercentage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    tr('سيُضاف ${(refundPercentage! >= 100 ? order.payableTotal : order.itemsTotal * (refundPercentage! / 100)).toStringAsFixed(2)} ر.س لمحفظة العميل',
                        '${(refundPercentage! >= 100 ? order.payableTotal : order.itemsTotal * (refundPercentage! / 100)).toStringAsFixed(2)} SAR will be added to the customer wallet'),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ),
              if (refundPercentage != null)
                CheckboxListTile(
                  value: chargeRestaurant,
                  onChanged: (v) =>
                      setDialogState(() => chargeRestaurant = v ?? false),
                  title: Text(
                      tr('الخصم على المطعم لصالح العميل',
                          "Charge the restaurant for the customer's refund"),
                      style: const TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                      tr('لشكاوى الجودة (رديء/بارد/ناقص): يُطرح الاسترداد من '
                              'مستحقّات المطعم بدل أن تتحمّله المنصّة — بسقف صافي '
                              'المطعم من هذا الطلب',
                          'For quality complaints (bad/cold/missing): the refund '
                              "is deducted from the restaurant's dues instead of "
                              "the platform — capped at the restaurant's net for "
                              'this order'),
                      style: const TextStyle(fontSize: 11.5)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              const Divider(height: 24),
              if (widget.complaint.againstRole == UserRole.driver) ...[
                CheckboxListTile(
                  value: warnParty,
                  onChanged: (v) => setDialogState(() => warnParty = v ?? false),
                  title: Text(tr('تسجيل إنذار للسائق', 'Record a driver warning'),
                      style: const TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                      tr('3 إنذارات = تعليق تلقائي للسائق',
                          '3 warnings = automatic driver suspension'),
                      style: const TextStyle(fontSize: 11.5)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(height: 24),
              ],
              // م٧ (فحص مساعد الويب): الشكاوى تُقدَّم غالباً على طلبات
              // **مُسلَّمة** — نقلُها كان يمحو دَين حامل النقد ويقيّده على
              // بريء. المنتقي يظهر للطلب النشط وحده (والخدمة تحرسه أيضاً).
              if (!order.status.isActive)
                Text(
                    tr('الطلب منتهٍ (${order.status.label}) — لا يُنقل لسائق آخر.',
                        'Order is finished (${order.status.label}) — it can\'t be reassigned.'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textGray))
              else ...[
              Text(
                  tr('نقل الطلب لسائق آخر (اختياري)',
                      'Reassign the order to another driver (optional)'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 6),
              AppStreamBuilder<List<Driver>>(
                stream: service.streamDrivers,
                builder: (ctx, drivers) {
                  final others = drivers.where((d) => d.id != order.driverId).toList();
                  if (others.isEmpty) {
                    return Text(tr('لا يوجد سائقون آخرون', 'No other drivers'),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textGray));
                  }
                  return DropdownButtonFormField<Driver>(
                    value: reassignTo,
                    isExpanded: true,
                    decoration: InputDecoration(
                        hintText: tr('اختر سائقاً (اختياري)',
                            'Pick a driver (optional)')),
                    items: others.map((d) => DropdownMenuItem(
                          value: d,
                          child: Text('${d.name} ${d.isOnline ? "🟢" : "⚪"}', overflow: TextOverflow.ellipsis),
                        )).toList(),
                    onChanged: (v) => setDialogState(() => reassignTo = v),
                  );
                },
              ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(tr('إلغاء', 'Cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(tr('تأكيد الحل', 'Confirm resolution')),
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
        resolution: resolutionCtrl.text.trim().isEmpty
            ? null
            : resolutionCtrl.text.trim(),
        chargeRestaurant:
            chargeRestaurant && (refundPercentage ?? 0) > 0,
      );
      _logAiFeedback(service, aiSuggestion, resolutionCtrl.text.trim());
      if (mounted) {
        showSuccess(
            context, tr('تم حل الشكوى بنجاح', 'Complaint resolved successfully'));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showError(
            context,
            tr('تعذّر حل الشكوى، حاول مرة أخرى',
                'Could not resolve the complaint, try again'));
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  /// يسجّل تغذية الذكاء الراجعة عند الحلّ (دفعة ٣): يقارن النصّ النهائي
  /// بالاقتراح فيصنّف النتيجة — قُبل كما هو، عُدِّل، أو رُفض (فُرِّغ). لا
  /// يُسجَّل شيء إن لم يُستخدَم اقتراحٌ أصلاً. غير حرج (لا يُعطّل الحل).
  void _logAiFeedback(
      FirebaseService service, String? suggestion, String finalText) {
    if (suggestion == null) return;
    final outcome = finalText.isEmpty
        ? 'rejected'
        : (finalText == suggestion.trim() ? 'accepted' : 'edited');
    service.recordAiFeedback(
      feature: 'complaintReply',
      suggestion: suggestion,
      finalText: finalText,
      outcome: outcome,
      context: widget.complaint.type.name,
    );
  }

  /// حل تذكرة عامة: نص قرار يظهر لمقدّمها في «شكاواي» — أي أثر مالي
  /// (صرف/تسوية) يُنفَّذ من شاشته المختصة (طلبات السحب/دفتر السائق) لا هنا.
  Future<void> _showResolveTicketDialog(BuildContext context) async {
    final resolutionCtrl = TextEditingController();
    bool aiLoading = false;
    String? aiSuggestion; // دفعة ٣: التقاط الاقتراح لقياس نتيجته عند الحل.
    final service = context.read<FirebaseService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx2, setDialogState) => AlertDialog(
          title: Text(tr('حل التذكرة', 'Resolve ticket')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: resolutionCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('القرار (يظهر لمقدّم التذكرة)',
                    'Decision (shown to the submitter)'),
                hintText: tr('مثال: حُدّث الآيبان في ملفك — تأكد منه في حسابك',
                    'e.g. The IBAN on your profile was updated — verify it in your account'),
                alignLabelWithHint: true,
              ),
            ),
            // نفس زر الاقتراح في حوار الشكوى — يملأ ولا يرسل.
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                icon: aiLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(tr('اقترح رداً', 'Suggest a reply'),
                    style: const TextStyle(fontSize: 12.5)),
                onPressed: aiLoading
                    ? null
                    : () async {
                        setDialogState(() => aiLoading = true);
                        try {
                          final s = await AiAssist.suggestComplaintReply(
                            complaint: widget.complaint,
                            resolutionDraft: resolutionCtrl.text,
                          );
                          aiSuggestion = s;
                          resolutionCtrl.text = s;
                        } catch (e) {
                          if (mounted) {
                            showError(context,
                                e.toString().replaceFirst('Exception: ', ''));
                          }
                        }
                        if (dCtx2.mounted) {
                          setDialogState(() => aiLoading = false);
                        }
                      },
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: Text(tr('إلغاء', 'Cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: Text(tr('حل التذكرة', 'Resolve ticket'))),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (resolutionCtrl.text.trim().isEmpty) {
      showError(
          context,
          tr('اكتب القرار — مقدّم التذكرة يستحق جواباً',
              'Write the decision — the submitter deserves an answer'));
      return;
    }
    setState(() => _resolving = true);
    try {
      await service.updateComplaintStatus(
        widget.complaint.id,
        ComplaintStatus.resolved,
        resolution: resolutionCtrl.text.trim(),
      );
      _logAiFeedback(service, aiSuggestion, resolutionCtrl.text.trim());
      if (mounted) {
        showSuccess(
            context,
            tr('حُلّت التذكرة وأُبلغ صاحبها',
                'Ticket resolved and the submitter notified'));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showError(
            context,
            tr('تعذّر حل التذكرة، حاول مرة أخرى',
                'Could not resolve the ticket, try again'));
      }
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
      appBar: AppBar(
          title: Text(c.isGeneralTicket
              ? tr('تذكرة ${c.displayNumber}', 'Ticket ${c.displayNumber}')
              : tr('شكوى #${c.orderNumber}', 'Complaint #${c.orderNumber}'))),
      // التذكرة العامة بلا طلب أصلاً — تدفّق ثابت null بدل استعلام مستند
      // بمعرّف فارغ (مسار غير صالح في Firestore يرمي استثناءً).
      body: StreamBuilder<Order?>(
        stream: c.isGeneralTicket
            ? Stream<Order?>.value(null)
            : service.streamOrder(c.orderId),
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
                // ارتدّت من صاحبها: حكم «محلولة» لم يقنعه — أولوية فوق
                // الشكاوى العادية، والمدير يجب أن يعرف أنها جولة ثانية.
                if (c.reopenedBySubmitter)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.replay_circle_filled_rounded,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('أعادها صاحبها بعد الحل — يرى أنها لم تُحل. '
                                  'راجع ردّك السابق قبل حلّها ثانية.',
                              'The submitter reopened it after resolution — they '
                                  "believe it wasn't solved. Review your previous "
                                  'reply before resolving again.'),
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.error,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]),
                  ),
                const SizedBox(height: 8),
                // تاريخ التقديم ومهلة الرد (نفذ ٢): كان المدير يقرّر أولوية
                // الشكاوى بلا أن يرى أيّها أوشك على خرق وعد «نردّ خلال ٢٤
                // ساعة» — فالمتأخرة تُعلَّم بالأحمر لتُقدَّم على غيرها.
                Builder(builder: (_) {
                  final overdue = c.isAwaitingAction &&
                      DateTime.now().isAfter(c.expectedResponseBy);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Icon(overdue ? Icons.alarm_on_rounded : Icons.schedule_rounded,
                            size: 18,
                            color: overdue ? AppColors.error : AppColors.textGray),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('قُدّمت: ${formatDateTime(c.createdAt)}\n'
                                    '${overdue ? "⚠️ تجاوزت مهلة الرد (٢٤ ساعة)" : "مهلة الرد تنتهي: ${formatDateTime(c.expectedResponseBy)}"}',
                                'Submitted: ${formatDateTime(c.createdAt)}\n'
                                    '${overdue ? "⚠️ past the response window (24 h)" : "Response window ends: ${formatDateTime(c.expectedResponseBy)}"}'),
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.6,
                                color: overdue ? AppColors.error : AppColors.textGray,
                                fontWeight: overdue ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                        // (زر «بدء المعالجة» اليدوي أُزيل — التحول صار
                        // تلقائياً بفتح المدير للشكوى، انظر initState.)
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('تفاصيل الشكوى', 'Complaint details'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(c.description, style: const TextStyle(fontSize: 13.5)),
                      // صورة الشكوى المرفقة (2026-08-20): تُعرض مصغّرة
                      // وتُكبَّر بالضغط للفحص — «هل الصنف فعلاً خاطئ؟».
                      if ((c.imageBlob ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Builder(builder: (ctx) {
                          final bytes = base64Decode(c.imageBlob!);
                          return GestureDetector(
                            onTap: () => showDialog<void>(
                              context: ctx,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.black,
                                child: InteractiveViewer(
                                    child: Image.memory(bytes)),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(bytes,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        Text(tr('اضغط الصورة للتكبير', 'Tap the photo to zoom'),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textGray)),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('الأطراف', 'Parties'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _PartyRow(
                          label: tr('مقدّم الشكوى', 'Submitted by'),
                          name: c.submittedByName,
                          role: c.submittedByRole),
                      if (c.againstRole != null) ...[
                        const SizedBox(height: 8),
                        _PartyRow(
                            label: tr('الشكوى ضد', 'Complaint against'),
                            name: c.againstRole!.label,
                            role: c.againstRole),
                      ],
                      if (order != null) ...[
                        const Divider(height: 20),
                        InfoRow(
                            icon: Icons.receipt_long_outlined,
                            text: tr('قيمة الطلب: ${formatCurrency(order.payableTotal)}',
                                'Order value: ${formatCurrency(order.payableTotal)}')),
                        if (order.customerPhone.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: OutlinedButton.icon(
                              onPressed: () => _call(order.customerPhone),
                              icon: const Icon(Icons.call_outlined, size: 16),
                              label: Text(
                                  tr('اتصال بالعميل: ${order.customerPhone}',
                                      'Call the customer: ${order.customerPhone}')),
                            ),
                          ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                // خط الإثبات الزمني: وصول السائق وصورتا الاستلام والتسليم —
                // يحسم «الطلب ناقص» و«لم يصلني» و«من أخّر» في دقيقة بدل
                // مكالمات متضاربة. (لا معنى له في تذكرة بلا طلب.)
                if (!c.isGeneralTicket) ...[
                  _ProofTimeline(orderId: c.orderId),
                  const SizedBox(height: 12),
                ],
                Text(tr('محادثة مع مقدّم الشكوى', 'Chat with the submitter'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14.5)),
                const SizedBox(height: 8),
                StreamBuilder<List<ChatMessage>>(
                  stream: service.streamComplaintChat(c.id),
                  builder: (ctx, chatSnap) {
                    final messages = chatSnap.data ?? [];
                    if (messages.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(tr('لا توجد رسائل بعد', 'No messages yet'),
                            style: const TextStyle(
                                color: AppColors.textGray, fontSize: 12.5)),
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
                              Text(m.senderName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                      decoration: InputDecoration(
                          hintText: tr('اكتب رسالة...', 'Write a message...'),
                          border: const OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: () => _sendChatMessage(auth.user?.uid ?? '', auth.user?.name ?? 'المدير'),
                  ),
                ]),
              ),
            ),
            // إعادة الفتح: للمحلولة/المغلقة — يملكها المدير دائماً (قد
            // يتصل صاحبها هاتفياً بعد الإغلاق التلقائي مثلاً).
            if (c.status == ComplaintStatus.resolved ||
                c.status == ComplaintStatus.closed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: Text(tr('إعادة فتح الشكوى', 'Reopen complaint')),
                    onPressed: _resolving
                        ? null
                        : () async {
                            setState(() => _resolving = true);
                            try {
                              await service.updateComplaintStatus(
                                  c.id, ComplaintStatus.inProgress);
                              if (context.mounted) {
                                showSuccess(
                                    context,
                                    tr('أُعيد فتحها — صارت «قيد المعالجة»',
                                        'Reopened — now "in progress"'));
                                Navigator.pop(context);
                              }
                            } catch (_) {
                              if (context.mounted) {
                                showError(context,
                                    tr('تعذّرت إعادة الفتح', 'Could not reopen'));
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _resolving = false);
                              }
                            }
                          },
                  ),
                ),
              ),
            if (c.status != ComplaintStatus.resolved && c.status != ComplaintStatus.closed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    // التذكرة العامة تُحل بنص قرار فقط (لا استرداد ولا إنذار
                    // طرف — لا طلب أصلاً)؛ شكوى الطلب تحتاج الطلب حاضراً.
                    // موظف الدعم يحلّ بنص القرار وحده (حوار التذكرة) —
                    // الاسترداد المالي والإنذار وإعادة الإسناد يختمها
                    // المدير: «يقترحه ولا يختمه» (roles-design)، وقواعد
                    // Firestore ترفض له مسّ المحافظ أصلاً فلا نعرض له
                    // حواراً كل أزراره سترتد.
                    onPressed: _resolving
                        ? null
                        : (c.isGeneralTicket ||
                                context.read<app_auth.AuthProvider>().user?.role ==
                                    UserRole.support)
                            ? () => _showResolveTicketDialog(context)
                            : (order == null
                                ? null
                                : () => _showResolveDialog(context, order)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    icon: _resolving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(tr('حل الشكوى', 'Resolve complaint'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
        Text('$label: ', style: const TextStyle(fontSize: 13.5, color: AppColors.textGray)),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold))),
        if (role != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(role!.label, style: const TextStyle(fontSize: 10.5, color: AppColors.primary)),
          ),
      ]);
}
/// خط الإثبات الزمني للطلب المشكو بشأنه: زمن وصول السائق للمطعم، وصورة
/// الاستلام، وصورة التسليم — بأزمنتها. تُقرأ من وثيقة order_proofs التي
/// يكتبها تطبيق السائق عند كل محطة (ضمن نطاق ١٠٠ متر وبكاميرا مباشرة).
class _ProofTimeline extends StatelessWidget {
  final String orderId;
  const _ProofTimeline({required this.orderId});

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} '
          '(${d.year}/${d.month}/${d.day})';

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: StreamBuilder<OrderProof?>(
          stream: service.streamOrderProof(orderId),
          builder: (ctx, snap) {
            final proof = snap.data;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('سجلّ الإثبات', 'Proof log'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5)),
              const SizedBox(height: 10),
              if (proof == null)
                Text(
                  tr('لا توثيق لهذا الطلب — استُلم أو سُلّم بنسخة تطبيق سابقة '
                          'لنظام التوثيق، أو لم يبدأ السائق رحلته بعد.',
                      'No proof for this order — it was picked up or delivered '
                          'on an app version predating the proof system, or the '
                          "driver hasn't started the trip yet."),
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textGray),
                )
              else ...[
                InfoRow(
                    icon: Icons.where_to_vote_outlined,
                    text: tr('وصول المطعم: ${_fmt(proof.arrivedAt)}',
                        'Arrived at restaurant: ${_fmt(proof.arrivedAt)}')),
                InfoRow(
                    icon: Icons.shopping_bag_outlined,
                    text: tr('استلام الطلب: ${_fmt(proof.pickupAt)}',
                        'Order pickup: ${_fmt(proof.pickupAt)}')),
                InfoRow(
                    icon: Icons.done_all_rounded,
                    text: tr('تسليم للعميل: ${_fmt(proof.deliveryAt)}',
                        'Delivered to customer: ${_fmt(proof.deliveryAt)}')),
                if ((proof.deliveryDistanceMeters ?? 0) > 100)
                  InfoRow(
                      icon: Icons.social_distance_rounded,
                      text: tr(
                          'سُلّم على بُعد '
                              '${proof.deliveryDistanceMeters! >= 1000 ? "${(proof.deliveryDistanceMeters! / 1000).toStringAsFixed(1)} كم" : "${proof.deliveryDistanceMeters} م"}'
                              ' من موقع العميل المسجّل',
                          'Delivered '
                              '${proof.deliveryDistanceMeters! >= 1000 ? "${(proof.deliveryDistanceMeters! / 1000).toStringAsFixed(1)} km" : "${proof.deliveryDistanceMeters} m"}'
                              " away from the customer's recorded location")),
                const SizedBox(height: 10),
                Row(children: [
                  if (proof.pickupPhoto != null)
                    Expanded(
                        child: _ProofPhoto(
                            label: tr('صورة الاستلام', 'Pickup photo'),
                            bytes: proof.pickupPhoto!)),
                  if (proof.pickupPhoto != null && proof.deliveryPhoto != null)
                    const SizedBox(width: 10),
                  if (proof.deliveryPhoto != null)
                    Expanded(
                        child: _ProofPhoto(
                            label: tr('صورة التسليم', 'Delivery photo'),
                            bytes: proof.deliveryPhoto!)),
                ]),
                if (proof.pickupPhoto == null && proof.deliveryPhoto == null)
                  Text(tr('لا صور محفوظة بعد', 'No photos saved yet'),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textGray)),
              ],
            ]);
          },
        ),
      ),
    );
  }
}

class _ProofPhoto extends StatelessWidget {
  final String label;
  final Uint8List bytes;
  const _ProofPhoto({required this.label, required this.bytes});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          GestureDetector(
            // تكبير الصورة للفحص — تفاصيل «هل الشنطة مغلقة؟ كم صنفاً؟»
            // لا تُرى في مصغّرة.
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(child: Image.memory(bytes)),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(bytes,
                  height: 130, width: double.infinity, fit: BoxFit.cover),
            ),
          ),
        ],
      );
}
