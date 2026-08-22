// lib/screens/customer/suggestion_screen.dart
//
// «اقتراح أو نصيحة» (2026-08-20، بطلب المالك): قناة صوتٍ عامة يفتحها أي
// أحد — زائراً كان أو مستخدماً — بلا تسجيل. النصّ وحده إلزامي؛ الاسم
// والهاتف اختياريان ليتواصل المدير إن رأى الاقتراح يستحق. صوتُ المستخدم
// المبكر يرصد المشكلة قبل أن تتحوّل لحذف.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/app_lang.dart';

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  final _textCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_textCtrl.text.trim().length < 5) {
      showError(
          context,
          tr('اكتب اقتراحك أو نصيحتك أولاً (٥ أحرف على الأقل)',
              'Write your suggestion first (at least 5 characters)'));
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<FirebaseService>().submitSuggestion(
            _textCtrl.text,
            name: _nameCtrl.text,
            phone: _phoneCtrl.text,
          );
      if (mounted) {
        showSuccess(context,
            tr('وصلنا اقتراحك — شكراً لك 🙌', 'We got your suggestion — thank you 🙌'));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showError(context,
            tr('تعذّر الإرسال، حاول مرة أخرى', 'Couldn\'t send, please try again'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('اقتراح أو نصيحة', 'Suggestion or advice'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('رأيك يهمّنا', 'Your feedback matters'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
            tr('اكتب أي اقتراح لتحسين التطبيق أو الخدمة — نقرؤها كلها.',
                'Share any idea to improve the app or service — we read them all.'),
            style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
        const SizedBox(height: 16),
        TextField(
          controller: _textCtrl,
          maxLines: 5,
          maxLength: 1000,
          decoration: InputDecoration(
            hintText: tr('اقتراحك أو نصيحتك...', 'Your suggestion or advice...'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('لِنتواصل معك إن لزم (اختياري):', 'So we can reach you if needed (optional):'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: tr('الاسم (اختياري)', 'Name (optional)'),
            counterText: '',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: tr('الجوال (اختياري)', 'Phone (optional)'),
            counterText: '',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    // كحليّ لا أبيض: مقدّمة الزر الذهبي كحلية عبر الثيم.
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.dark))
                : Text(tr('إرسال', 'Send'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}
