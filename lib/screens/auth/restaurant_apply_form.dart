// lib/screens/auth/restaurant_apply_form.dart
//
// نموذج تسجيل مطعم داخل التطبيق — نظير نموذج الكابتن. المستندات على نمط
// شركاء هنقرستيشن (بحث 2026-08-18): سجل تجاري **أو وثيقة عمل حر** (تقبل
// الأسر المنتجة) + هوية المالك، والبقية اختيارية حتى لا يقف تسجيل مطعم
// جادّ على شهادة تلحق لاحقاً.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/doc_capture_field.dart';

class RestaurantApplyForm extends StatefulWidget {
  final RestaurantApplication? existing;
  final VoidCallback onSubmitted;

  const RestaurantApplyForm(
      {super.key, this.existing, required this.onSubmitted});

  @override
  State<RestaurantApplyForm> createState() => _RestaurantApplyFormState();
}

class _RestaurantApplyFormState extends State<RestaurantApplyForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _restaurantName;
  late final TextEditingController _ownerName;
  late final TextEditingController _phone;
  late final TextEditingController _district;
  late final TextEditingController _description;

  final Map<String, Uint8List> _docs = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final user = context.read<app_auth.AuthProvider>().user;
    _restaurantName = TextEditingController(text: e?.restaurantName ?? '');
    _ownerName = TextEditingController(text: e?.ownerName ?? user?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? user?.phone ?? '');
    _district = TextEditingController(text: e?.district ?? '');
    _description = TextEditingController(text: e?.description ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _restaurantName, _ownerName, _phone, _district, _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final missing = RestaurantApplication.requiredDocs
        .where((k) => !_docs.containsKey(k))
        .toList();
    if (missing.isNotEmpty) {
      showError(
          context,
          'مستندات إلزامية ناقصة: '
          '${missing.map((k) => RestaurantApplication.docLabels[k]).join('، ')}');
      return;
    }

    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final user = auth.user;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await service.submitRestaurantApplication(
        uid: user.uid,
        restaurantName: _restaurantName.text,
        ownerName: _ownerName.text,
        phone: _phone.text,
        email: user.email,
        district: _district.text,
        description: _description.text,
        docImages: _docs,
      );
      if (!mounted) return;
      showSuccess(context, 'وصل طلبك — تراجعه الإدارة');
      widget.onSubmitted();
    } catch (_) {
      if (mounted) {
        showError(context, 'تعذّر إرسال الطلب — تحقق من الاتصال وأعد المحاولة');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('بيانات مطعمك',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
            'تراجعها الإدارة وتتواصل معك قبل تفعيل المطعم وبناء المنيو.',
            style: TextStyle(fontSize: 13, color: AppColors.textGray)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _restaurantName,
          decoration: const InputDecoration(
              labelText: 'اسم المطعم / النشاط التجاري'),
          validator: (v) => validateRequired(v, 'اسم المطعم'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _ownerName,
          decoration: const InputDecoration(labelText: 'اسم المالك'),
          validator: (v) => validateRequired(v, 'اسم المالك'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم الجوال'),
          validator: validatePhone,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _district,
          decoration: const InputDecoration(
            labelText: 'الحي / العنوان المختصر',
            hintText: 'المدينة المنورة — حي العزيزية',
          ),
          validator: (v) => validateRequired(v, 'الحي'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _description,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'وصف قصير (اختياري)',
            hintText: 'مأكولات شعبية — أسرة منتجة',
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'المستندات — صوّر كل مستند بوضوح'),
        ...RestaurantApplication.docLabels.entries.map(
          (e) => DocCaptureField(
            label: e.value,
            required: RestaurantApplication.requiredDocs.contains(e.key),
            value: _docs[e.key],
            onChanged: (bytes) => setState(() {
              if (bytes == null) {
                _docs.remove(e.key);
              } else {
                _docs[e.key] = bytes;
              }
            }),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: Text(_submitting ? 'يُرسل...' : 'إرسال الطلب'),
          ),
        ),
        const SizedBox(height: 30),
      ]),
    );
  }
}
