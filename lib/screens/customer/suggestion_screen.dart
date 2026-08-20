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
      showError(context, 'اكتب اقتراحك أو نصيحتك أولاً (٥ أحرف على الأقل)');
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
        showSuccess(context, 'وصلنا اقتراحك — شكراً لك 🙌');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showError(context, 'تعذّر الإرسال، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اقتراح أو نصيحة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('رأيك يهمّنا',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('اكتب أي اقتراح لتحسين التطبيق أو الخدمة — نقرؤها كلها.',
            style: TextStyle(fontSize: 13, color: AppColors.textGray)),
        const SizedBox(height: 16),
        TextField(
          controller: _textCtrl,
          maxLines: 5,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'اقتراحك أو نصيحتك...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const Text('لِنتواصل معك إن لزم (اختياري):',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'الاسم (اختياري)',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'الجوال (اختياري)',
            counterText: '',
            border: OutlineInputBorder(),
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
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('إرسال',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}
