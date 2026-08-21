// lib/screens/customer/submit_complaint_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/doc_capture_field.dart';

class SubmitComplaintScreen extends StatefulWidget {
  final Order order;
  final String submittedByUid;
  final String submittedByName;
  final UserRole submittedByRole;

  const SubmitComplaintScreen({
    super.key,
    required this.order,
    required this.submittedByUid,
    required this.submittedByName,
    required this.submittedByRole,
  });

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  /// أنواع الشكاوى المتاحة لدور مُقدِّم الشكوى تحديداً — مصدرها الوحيد جدول
  /// الربط في النموذج، فلا يرى العميل أنواع السائق/المطعم أو العكس.
  late final List<ComplaintType> _availableTypes =
      ComplaintTypeScope.typesForRole(widget.submittedByRole);
  late ComplaintType _type = _availableTypes.first;
  String? _selectedAgainstUid;
  UserRole? _selectedAgainstRole;
  final _descriptionCtrl = TextEditingController();
  bool _submitting = false;

  /// صورة اختيارية مرفقة (bytes مضغوطة، تُحوَّل base64 عند الإرسال).
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    // اختيار «الشكوى ضد» المناسب لنوع الشكوى الابتدائي، وتحديث زر الإرسال
    // كلما تغيّر نص التفاصيل.
    _applySuggestedAgainst(_type);
    _descriptionCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  /// يضبط «الشكوى ضد» على الطرف المنطقي لنوع الشكوى، إن كان متاحاً في هذا
  /// الطلب (مثلاً السائق لا يظهر إن لم يُعيَّن بعد)؛ وإلا يسقط إلى «شكوى عامة».
  void _applySuggestedAgainst(ComplaintType type) {
    final suggested = type.suggestedAgainstRole;
    (String, String?, UserRole)? match;
    if (suggested != null) {
      for (final o in _againstOptions) {
        if (o.$3 == suggested && o.$2 != null) {
          match = o;
          break;
        }
      }
    }
    _selectedAgainstUid = match?.$2;
    _selectedAgainstRole = match?.$3 ?? UserRole.admin; // admin = شكوى عامة
  }

  /// زر الإرسال مُفعَّل فقط عند اكتمال الحقول المطلوبة: التفاصيل + طرف محدد.
  bool get _canSubmit =>
      _descriptionCtrl.text.trim().isNotEmpty && _selectedAgainstRole != null;

  List<(String, String?, UserRole)> get _againstOptions {
    final order = widget.order;
    final options = <(String, String?, UserRole)>[];

    if (widget.submittedByRole != UserRole.customer) {
      options.add(('العميل (${order.customerName})', order.customerId, UserRole.customer));
    }
    if (widget.submittedByRole != UserRole.driver &&
        order.driverId != null &&
        order.driverId!.isNotEmpty) {
      options.add(('السائق (${order.driverName ?? "غير معروف"})', order.driverId, UserRole.driver));
    }
    if (widget.submittedByRole != UserRole.restaurantManager) {
      options.add(('المطعم (${order.restaurantName})', order.restaurantId, UserRole.restaurantManager));
    }
    options.add(('شكوى عامة عن الطلب', null, UserRole.admin));

    return options;
  }

  Future<void> _submit() async {
    if (_descriptionCtrl.text.trim().isEmpty) {
      showError(context, 'يرجى كتابة تفاصيل الشكوى');
      return;
    }
    // حارس المهلة عند الإرسال لا عند الفتح: من فتح الشاشة قبل انقضائها ثم
    // أطال الكتابة كان يُرسل شكوى بعد إغلاق النافذة. تُردّ هنا برسالة
    // مفهومة بدل أن تُقبل ثم تُرفض إدارياً.
    if (!widget.order.canSubmitComplaint) {
      showError(context, 'انتهت مهلة تقديم الشكوى على هذا الطلب (٢٤ ساعة)');
      Navigator.pop(context);
      return;
    }
    setState(() => _submitting = true);
    try {
      final service = context.read<FirebaseService>();
      final complaint = Complaint(
        id: const Uuid().v4(),
        orderId: widget.order.id,
        orderNumber: widget.order.orderNumber,
        customerId: widget.order.customerId,
        customerName: widget.order.customerName,
        restaurantId: widget.order.restaurantId,
        restaurantName: widget.order.restaurantName,
        type: _type,
        description: _descriptionCtrl.text.trim(),
        createdAt: DateTime.now(),
        submittedByUid: widget.submittedByUid,
        submittedByName: widget.submittedByName,
        submittedByRole: widget.submittedByRole,
        againstUid: _selectedAgainstUid,
        againstRole: _selectedAgainstRole,
        imageBlob:
            _imageBytes != null ? base64Encode(_imageBytes!) : null,
      );
      await service.submitComplaint(complaint);
      if (mounted) {
        showSuccess(context, 'تم إرسال شكواك بنجاح، سنراجعها قريباً');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showError(context, 'تعذّر إرسال الشكوى، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _againstOptions;

    return Scaffold(
      appBar: AppBar(title: const Text('تقديم شكوى')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('طلب #${widget.order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('نوع الشكوى', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTypes.map((t) {
              final selected = _type == t;
              return ChoiceChip(
                label: Text(t.label),
                selected: selected,
                onSelected: (_) => setState(() {
                  _type = t;
                  _applySuggestedAgainst(t);
                }),
                selectedColor: AppColors.primary.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textDark,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('الشكوى ضد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 8),
          ...options.map((opt) {
            final label = opt.$1;
            final uid = opt.$2;
            final role = opt.$3;
            final selected = _selectedAgainstUid == uid && _selectedAgainstRole == role;
            return RadioListTile<String>(
              value: label,
              groupValue: selected ? label : null,
              onChanged: (_) => setState(() {
                _selectedAgainstUid = uid;
                _selectedAgainstRole = role;
              }),
              title: Text(label),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
            );
          }),
          const SizedBox(height: 12),
          const Text('تفاصيل الشكوى', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'اشرح المشكلة بالتفصيل...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // صورة اختيارية (2026-08-20): شكوى جودةٍ أو صنفٍ خاطئ بلا صورة
          // نصفُ دليل. DocCaptureField نفسه الذي يلتقط مستندات التقديم.
          const Text('أرفق صورة (اختياري)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 8),
          DocCaptureField(
            label: 'صورة توضّح المشكلة — الصنف أو الحالة',
            value: _imageBytes,
            onChanged: (b) => setState(() => _imageBytes = b),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_submitting || !_canSubmit) ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      // كحليّ لا أبيض على الزر الذهبي.
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                  : const Text('إرسال الشكوى', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}