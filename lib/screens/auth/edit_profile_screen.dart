// lib/screens/auth/edit_profile_screen.dart
//
// الملف الشخصي — عرض وتعديل الاسم ورقم الجوال لكل الأدوار (ملاحظة المالك:
// لم يكن للعميل ولا للسائق أي وسيلة لتعديل بياناتهما).
//
// البريد يُعرض ولا يُعدَّل: هو هوية تسجيل الدخول في Firebase وتغييره عملية
// حساسة (إعادة مصادقة + تحقق) تُبنى لاحقاً إن طُلبت. اسم السائق وجواله
// يُحدَّثان في مستند drivers أيضاً — العميل يقرؤهما في تتبّع الطلب.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<app_auth.AuthProvider>().user;
    _name = TextEditingController(text: u?.name ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final u = auth.user;
    if (u == null) return;
    setState(() => _saving = true);
    try {
      await service.updateUserProfile(
        uid: u.uid,
        name: _name.text,
        phone: _phone.text,
        alsoDriver: u.role == UserRole.driver,
      );
      auth.applyProfile(name: _name.text, phone: _phone.text);
      if (mounted) {
        showSuccess(context, 'حُفظ ملفك الشخصي');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, 'تعذّر الحفظ — حاول مجدداً');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<app_auth.AuthProvider>().user;
    if (u == null) {
      return const Scaffold(body: Center(child: Text('سجّل الدخول أولاً')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: CircleAvatar(
              radius: 38,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(
                u.name.trim().isEmpty ? '؟' : u.name.trim().substring(0, 1),
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(u.role.label,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textGray)),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'الاسم', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'أدخل اسمك' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'رقم الجوال',
                hintText: '05xxxxxxxx',
                prefixIcon: Icon(Icons.phone_outlined)),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return digits.length < 9 ? 'أدخل رقم جوال صحيح' : null;
            },
          ),
          const SizedBox(height: 12),
          // البريد للعرض فقط — هوية الدخول.
          TextFormField(
            initialValue: u.email,
            enabled: false,
            decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني (هوية الدخول — لا يُعدَّل)',
                prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
            ),
          ),
        ]),
      ),
    );
  }
}
