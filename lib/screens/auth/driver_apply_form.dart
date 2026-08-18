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
          'مستندات إلزامية ناقصة: '
          '${missing.map((k) => DriverApplication.docLabels[k]).join('، ')}');
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
        const Text('بياناتك ومركبتك',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('تراجعها الإدارة قبل أن تستقبل أول طلب.',
            style: TextStyle(fontSize: 13, color: AppColors.textGray)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(
              labelText: 'الاسم الكامل — كما في الهوية'),
          validator: (v) => validateRequired(v, 'الاسم'),
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
          controller: _nationalId,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'رقم الهوية / الإقامة'),
          validator: (v) => validateRequired(v, 'رقم الهوية'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _vehicleType,
          decoration: const InputDecoration(labelText: 'نوع المركبة'),
          items: const [
            DropdownMenuItem(value: 'دراجة نارية', child: Text('دراجة نارية')),
            DropdownMenuItem(value: 'سيارة', child: Text('سيارة')),
          ],
          onChanged: (v) => setState(() => _vehicleType = v ?? 'دراجة نارية'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _plate,
          decoration: const InputDecoration(labelText: 'رقم اللوحة'),
          validator: (v) => validateRequired(v, 'رقم اللوحة'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _referrer,
          decoration: const InputDecoration(
            labelText: 'كود الكابتن الداعي (اختياري)',
            helperText: 'إن دعاك كابتن — يُصرف له ولك حافز الإحالة',
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'المستندات — صوّر كل مستند بوضوح'),
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
        const SectionHeader(title: 'صور المركبة — أربع جهات'),
        ...List.generate(_vehicleSides.length, (i) {
          final has = i < _vehiclePhotos.length;
          return DocCaptureField(
            label: 'جهة ${_vehicleSides[i]}',
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
            label: Text(_submitting ? 'يُرسل...' : 'إرسال الطلب'),
          ),
        ),
        const SizedBox(height: 30),
      ]),
    );
  }
}
