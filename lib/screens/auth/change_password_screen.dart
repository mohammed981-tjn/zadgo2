import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../utils/app_lang.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<app_auth.AuthProvider>();
    final ok = await auth.changePassword(_currentCtrl.text.trim(), _newCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تم تغيير كلمة المرور بنجاح ✅',
              'Password changed successfully ✅')),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? tr('حدث خطأ', 'Something went wrong')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('تغيير كلمة المرور', 'Change password'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(children: [
            const SizedBox(height: 16),
            const Icon(Icons.lock_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 24),
            TextFormField(
              controller: _currentCtrl,
              obscureText: !_showCurrent,
              decoration: InputDecoration(
                labelText: tr('كلمة المرور الحالية', 'Current password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showCurrent ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showCurrent = !_showCurrent),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? tr('أدخل كلمة المرور الحالية', 'Enter your current password')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newCtrl,
              obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: tr('كلمة المرور الجديدة', 'New password'),
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return tr('أدخل كلمة المرور الجديدة', 'Enter a new password');
                }
                if (v.length < 6) {
                  return tr('يجب أن تكون 6 أحرف على الأقل',
                      'Must be at least 6 characters');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: tr('تأكيد كلمة المرور الجديدة', 'Confirm new password'),
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return tr('أعد إدخال كلمة المرور الجديدة',
                      'Re-enter the new password');
                }
                if (v != _newCtrl.text) {
                  return tr('كلمتا المرور غير متطابقتين', 'Passwords do not match');
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.loading ? null : _submit,
                child: auth.loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('تغيير كلمة المرور', 'Change password')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
