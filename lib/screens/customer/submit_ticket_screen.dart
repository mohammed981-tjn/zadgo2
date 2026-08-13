// lib/screens/customer/submit_ticket_screen.dart
//
// تذكرة عامة — طلب دعم بلا ارتباط بطلب توصيل (نمط مركز دعم نينجا/جاهز):
// مالية (مستحقّات/محفظة)، تحديث بيانات، استفسار عام، أخرى. تُخزَّن في
// مجموعة الشكاوى نفسها بـ orderId فارغ، فترث كامل البنية القائمة: القوائم،
// الدردشة مع الإدارة، الحالات، ومهلة الرد — بلا مجموعة جديدة ولا قواعد
// إضافية.
//
// الشاشة مشتركة للأدوار الثلاثة (عميل/سائق/مدير مطعم) كشاشة الشكاوى نفسها.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';

class SubmitTicketScreen extends StatefulWidget {
  final String submittedByUid;
  final String submittedByName;
  final UserRole submittedByRole;

  /// معرّف مطعم المدير — يُسجَّل في التذكرة ليصل استعلام «شكاوى مطعمي»
  /// إليها أيضاً.
  final String? restaurantId;
  final String? restaurantName;

  const SubmitTicketScreen({
    super.key,
    required this.submittedByUid,
    required this.submittedByName,
    required this.submittedByRole,
    this.restaurantId,
    this.restaurantName,
  });

  @override
  State<SubmitTicketScreen> createState() => _SubmitTicketScreenState();
}

class _SubmitTicketScreenState extends State<SubmitTicketScreen> {
  ComplaintType _type = ComplaintType.financial;
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().length < 10) {
      showError(context, 'اشرح طلبك بجملة واحدة على الأقل (10 أحرف)');
      return;
    }
    setState(() => _submitting = true);
    final service = context.read<FirebaseService>();
    try {
      await service.submitComplaint(Complaint(
        id: const Uuid().v4(),
        orderId: '',
        orderNumber: '',
        customerId: widget.submittedByRole == UserRole.customer
            ? widget.submittedByUid
            : '',
        customerName: widget.submittedByRole == UserRole.customer
            ? widget.submittedByName
            : '',
        restaurantId: widget.restaurantId ?? '',
        restaurantName: widget.restaurantName ?? '',
        type: _type,
        description: _descCtrl.text.trim(),
        createdAt: DateTime.now(),
        submittedByUid: widget.submittedByUid,
        submittedByName: widget.submittedByName,
        submittedByRole: widget.submittedByRole,
      ));
      if (mounted) {
        showSuccess(context, 'أُرسلت التذكرة — نرد خلال 24 ساعة، وتابعها من «شكاواي»');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        showError(context, 'تعذّر إرسال التذكرة — حاول مجدداً');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;
    return Scaffold(
      appBar: AppBar(title: const Text('تذكرة جديدة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fc.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'للمشاكل المتعلقة بطلب توصيل معيّن استخدم زر «تقديم شكوى» على '
            'الطلب نفسه — هذه التذكرة للمواضيع العامة.',
            style: TextStyle(fontSize: 12.5, height: 1.6),
          ),
        ),
        const SizedBox(height: 16),
        const Text('نوع التذكرة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: generalTicketTypes.map((t) {
            final selected = _type == t;
            return ChoiceChip(
              label: Text(t.label),
              selected: selected,
              onSelected: (_) => setState(() => _type = t),
              selectedColor: fc.primary.withOpacity(0.15),
              labelStyle: TextStyle(
                color: selected ? fc.primaryDark : AppColors.textDark,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'اشرح طلبك',
            hintText: 'مثال: أرجو تحديث رقم الآيبان في ملفي إلى ...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_submitting ? 'جارٍ الإرسال…' : 'إرسال التذكرة'),
          ),
        ),
      ]),
    );
  }
}
