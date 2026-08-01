import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import '../driver/driver_home.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  UserRole _role = UserRole.customer;
  bool _obscure = true;

  // Invite code state
  InviteCode? _resolvedCode;
  bool _checkingCode = false;
  String? _codeError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    final raw = _codeCtrl.text.trim().toUpperCase();
    if (raw.isEmpty) {
      setState(() { _resolvedCode = null; _codeError = null; });
      return;
    }
    setState(() { _checkingCode = true; _codeError = null; _resolvedCode = null; });
    final service = context.read<FirebaseService>();
    final code = await service.validateInviteCode(raw);
    if (!mounted) return;
    if (code == null) {
      setState(() { _checkingCode = false; _codeError = 'رمز غير صحيح أو مُستخدَم بالفعل'; });
    } else {
      setState(() { _checkingCode = false; _resolvedCode = code; _role = code.role; });
    }
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;

    // Re-validate invite code if one was entered
    if (_codeCtrl.text.trim().isNotEmpty && _resolvedCode == null) {
      showError(context, 'تحقق من رمز الدعوة أولاً');
      return;
    }

    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();

    final ok = await auth.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passCtrl.text,
      phone: _phoneCtrl.text,
      role: _role,
      bypassApproval: _resolvedCode != null,
    );
    if (!mounted) return;
    if (!ok) { showError(context, auth.error ?? 'فشل التسجيل'); return; }

    // Consume invite code if one was used
    if (_resolvedCode != null) {
      try {
        await service.consumeInviteCode(_resolvedCode!.id, auth.user!.uid);
      } catch (_) {
        // Non-critical — proceed anyway
      }
    }

    if (!mounted) return;
    Widget dest;
    switch (_role) {
      case UserRole.customer:
        dest = const CustomerHome();
        break;
      case UserRole.driver:
        dest = _resolvedCode != null ? const DriverHome() : const DriverPendingScreen();
        break;
      case UserRole.admin:
        dest = const AdminHome();
        break;
    }
    Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => dest), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final hasCode = _resolvedCode != null;

    return Scaffold(
      appBar: AppBar(title: const Text('حساب جديد')),
      body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
        TextFormField(controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => validateRequired(v, 'الاسم')),
        const SizedBox(height: 14),
        TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
            validator: validateEmail),
        const SizedBox(height: 14),
        TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
            validator: validatePhone),
        const SizedBox(height: 14),
        TextFormField(controller: _passCtrl, obscureText: _obscure, textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure))),
            validator: validatePassword),
        const SizedBox(height: 20),

        // ── Invite Code ──────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextFormField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              textDirection: TextDirection.ltr,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: 'رمز الدعوة (اختياري)',
                prefixIcon: const Icon(Icons.key_outlined),
                counterText: '',
                suffixIcon: hasCode
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : (_codeError != null
                        ? const Icon(Icons.cancel, color: AppColors.error)
                        : null),
                errorText: _codeError,
              ),
              onChanged: (_) {
                if (_resolvedCode != null || _codeError != null) {
                  setState(() { _resolvedCode = null; _codeError = null; });
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 56,
            child: _checkingCode
                ? const Center(child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                : ElevatedButton(
                    onPressed: _codeCtrl.text.trim().isEmpty ? null : _validateCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('تحقق'),
                  ),
          ),
        ]),
        if (hasCode)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_user_outlined, color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                'رمز صحيح — سيتم التسجيل كـ ${_role == UserRole.admin ? "مدير" : "سائق"}',
                style: const TextStyle(color: AppColors.success, fontSize: 13),
              ),
            ]),
          ),

        // ── Role selector (hidden when a code is active) ─────────────────────
        if (!hasCode) ...[
          const SizedBox(height: 20),
          const Text('نوع الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            _chip(UserRole.customer, '👤 عميل'), const SizedBox(width: 10),
            _chip(UserRole.driver, '🛵 سائق'),
          ]),
          if (_role == UserRole.driver) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سيتم مراجعة طلبك من قِبل الإدارة قبل تفعيل حسابك كسائق.',
                    style: TextStyle(fontSize: 13, color: AppColors.warning),
                  ),
                ),
              ]),
            ),
          ],
        ],

        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: auth.loading ? null : _register,
            child: auth.loading ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('إنشاء الحساب'))),
      ])),
    );
  }

  Widget _chip(UserRole role, String label) {
    final sel = _role == role;
    return GestureDetector(onTap: () => setState(() => _role = role),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppColors.primary : AppColors.divider)),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textDark))));
  }
}
