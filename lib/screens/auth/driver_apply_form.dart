// lib/screens/auth/driver_apply_form.dart
//
// نموذج تقديم الكابتن داخل التطبيق — نفس قائمة صفحة /join (متطلبات الهيئة
// العامة للنقل التي بُحثت هناك): بيانات + ٧ مستندات + صور المركبة. يقدَّم
// وهو مسجَّل بحساب «عميل» مؤقت، ومعرّف الطلب = uid حسابه، فتقرؤه شاشة
// الانتظار مباشرة ويُمنح الدور على نفس الحساب عند الاعتماد.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import '../../utils/app_lang.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/doc_capture_field.dart';

class DriverApplyForm extends StatefulWidget {
  /// طلب سابق (إعادة تقديم بعد رفض): تُملأ الحقول النصية منه، والصور
  /// تُلتقط من جديد — القديمة بقيت عند المدير ولا معنى لإعادة ربطها عمياء.
  final DriverApplication? existing;
  final VoidCallback onSubmitted;

  const DriverApplyForm({super.key, this.existing, required this.onSubmitted});

  @override
  State<DriverApplyForm> createState() => _DriverApplyFormState();
}

class _DriverApplyFormState extends State<DriverApplyForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _nationalId;
  late final TextEditingController _plate;
  late final TextEditingController _referrer;
  String _vehicleType = 'دراجة نارية';

  final Map<String, Uint8List> _docs = {};
  final List<Uint8List> _vehiclePhotos = [];
  bool _submitting = false;

  static const _vehicleSides = ['أمامية', 'خلفية', 'يمين', 'يسار'];
  static const _vehicleSidesEn = ['Front', 'Back', 'Right', 'Left'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final user = context.read<app_auth.AuthProvider>().user;
    _name = TextEditingController(text: e?.name ?? user?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? user?.phone ?? '');
    _nationalId = TextEditingController(text: e?.nationalId ?? '');
    _plate = TextEditingController(text: e?.vehiclePlate ?? '');
    _referrer = TextEditingController(text: e?.referredByCode ?? '');
    if (e != null && e.vehicleType.isNotEmpty) _vehicleType = e.vehicleType;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _nationalId, _plate, _referrer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final missing = DriverApplication.requiredDocs
        .where((k) => !_docs.containsKey(k))
        .toList();
    if (missing.isNotEmpty) {
      showError(
          context,
          '${tr('مستندات إلزامية ناقصة:', 'Missing required documents:')} '
          '${missing.map((k) => DriverApplication.docLabels[k]).join(tr('، ', ', '))}');
      return;
    }

    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final user = auth.user;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await service.submitDriverApplication(
        uid: user.uid,
        name: _name.text,
        phone: _phone.text,
        email: user.email,
        nationalId: _nationalId.text,
        vehicleType: _vehicleType,
        vehiclePlate: _plate.text,
        referredByCode: _referrer.text,
        docImages: _docs,
        vehiclePhotos: _vehiclePhotos,
      );
      if (!mounted) return;
      showSuccess(context,
          tr('وصل طلبك — تراجعه الإدارة', 'Application received — under review'));
      widget.onSubmitted();
    } catch (_) {
      if (mounted) {
        showError(
            context,
            tr('تعذّر إرسال الطلب — تحقق من الاتصال وأعد المحاولة',
                "Couldn't submit — check your connection and try again"));
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
        Text(tr('بياناتك ومركبتك', 'Your details and vehicle'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
            tr('تراجعها الإدارة قبل أن تستقبل أول طلب.',
                'The team reviews them before you receive your first order.'),
            style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _name,
          decoration: InputDecoration(
              labelText:
                  tr('الاسم الكامل — كما في الهوية', 'Full name — as on your ID')),
          validator: (v) => validateRequired(v, tr('الاسم', 'Name')),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration:
              InputDecoration(labelText: tr('رقم الجوال', 'Mobile number')),
          validator: validatePhone,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _nationalId,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: tr('رقم الهوية / الإقامة', 'National ID / Iqama number')),
          validator: (v) => validateRequired(v, tr('رقم الهوية', 'ID number')),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _vehicleType,
          decoration:
              InputDecoration(labelText: tr('نوع المركبة', 'Vehicle type')),
          // قيمتا value تُحفظان في Firestore فتبقيان عربيتين؛ النص المعروض
          // وحده يُترجم.
          items: [
            DropdownMenuItem(
                value: 'دراجة نارية',
                child: Text(tr('دراجة نارية', 'Motorcycle'))),
            DropdownMenuItem(value: 'سيارة', child: Text(tr('سيارة', 'Car'))),
          ],
          onChanged: (v) => setState(() => _vehicleType = v ?? 'دراجة نارية'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _plate,
          decoration: InputDecoration(labelText: tr('رقم اللوحة', 'Plate number')),
          validator: (v) => validateRequired(v, tr('رقم اللوحة', 'Plate number')),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _referrer,
          decoration: InputDecoration(
            labelText: tr('كود الكابتن الداعي (اختياري)',
                "Referring captain's code (optional)"),
            helperText: tr('إن دعاك كابتن — يُصرف له ولك حافز الإحالة',
                'If a captain invited you, you both get the referral bonus'),
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(
            title: tr('المستندات — صوّر كل مستند بوضوح',
                'Documents — photograph each one clearly')),
        ...DriverApplication.docLabels.entries.map(
          (e) => DocCaptureField(
            label: e.value,
            required: DriverApplication.requiredDocs.contains(e.key),
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
        const SizedBox(height: 12),
        SectionHeader(
            title: tr('صور المركبة — أربع جهات',
                'Vehicle photos — all four sides')),
        ...List.generate(_vehicleSides.length, (i) {
          final has = i < _vehiclePhotos.length;
          return DocCaptureField(
            label: tr('جهة ${_vehicleSides[i]}', '${_vehicleSidesEn[i]} side'),
            value: has ? _vehiclePhotos[i] : null,
            onChanged: (bytes) => setState(() {
              if (bytes == null) {
                if (has) _vehiclePhotos.removeAt(i);
              } else if (has) {
                _vehiclePhotos[i] = bytes;
              } else {
                _vehiclePhotos.add(bytes);
              }
            }),
          );
        }),
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
            label: Text(_submitting
                ? tr('يُرسل...', 'Submitting...')
                : tr('إرسال الطلب', 'Submit application')),
          ),
        ),
        const SizedBox(height: 30),
      ]),
    );
  }
}
