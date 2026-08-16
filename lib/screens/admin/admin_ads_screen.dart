// lib/screens/admin/admin_ads_screen.dart
//
// شاشة «الإعلانات» (دفعة الإعلانات — 2026-08-16): توليد نصوص إعلانية
// عبر بوابة شركاء zol-adcraft — زاد قو شريك مسجَّل فيها بمفتاح وحصة
// شهرية (سُجّل بأمر المالك «اتصل» في نفس اليوم).
//
// القرار المعماري: النداء يخرج من جهاز المدير مباشرة إلى بوابة zol —
// لا خادم وسيطاً عندنا. المفتاح يُلصق مرة واحدة ويسكن مستند
// admin_secrets (للمدير حصراً في القواعد)؛ **لا يُدفن في الكود أبداً**
// لأن أي APK يُفكّ ويُستخرج ما فيه.
//
// البوابة تعيد ثلاث صيغ مرتّبة بدرجات ناقدها — نعرضها كلها بأزرار نسخ
// بدل «أفضل واحدة»: اختيار الصيغة قرار تسويقي بيد المالك لا بيد نموذج.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/firebase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';

class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> {
  // عنوان البوابة ليس سراً (رابط عام) — السرّ هو المفتاح وحده.
  static const _endpoint =
      'https://fbbrkwragezhztffbvxf.supabase.co/functions/v1/ad-copy-partner';

  static const _platforms = [
    ('instagram', 'إنستغرام'),
    ('snapchat', 'سناب شات'),
    ('twitter', 'X / تويتر'),
    ('tiktok', 'تيك توك'),
  ];

  final _productCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  String? _storedKey; // null = لم يُحمَّل بعد أو غير موجود
  bool _keyChecked = false;
  bool _saving = false;
  bool _generating = false;
  String _platform = 'instagram';
  String? _error;
  List<Map<String, dynamic>> _variants = const [];
  String? _quotaLine;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await context.read<FirebaseService>().getZolPartnerKey();
    if (mounted) {
      setState(() {
        _storedKey = key;
        _keyChecked = true;
      });
    }
  }

  @override
  void dispose() {
    _productCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final key = _keyCtrl.text.trim();
    if (!key.startsWith('pk_')) {
      showError(context, 'المفتاح يبدأ بـ pk_ — انسخه كاملاً كما صدر');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<FirebaseService>().saveZolPartnerKey(key);
      _keyCtrl.clear();
      if (mounted) {
        setState(() => _storedKey = key);
        showSuccess(context, 'حُفظ المفتاح — جاهز للتوليد');
      }
    } catch (_) {
      if (mounted) showError(context, 'تعذّر الحفظ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generate() async {
    final product = _productCtrl.text.trim();
    if (product.isEmpty) {
      showError(context, 'اكتب ما تريد الإعلان عنه أولاً');
      return;
    }
    final key = _storedKey;
    if (key == null) return;

    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'X-Partner-Key': key,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'product': product, 'platform': _platform}),
          )
          .timeout(const Duration(seconds: 90));

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && body?['ok'] == true) {
        final variants = (body['variants'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final quota = body['quota'] as Map<String, dynamic>? ?? const {};
        setState(() {
          _variants = variants;
          _quotaLine = quota['limit'] == null
              ? 'حصتك: بلا حدّ'
              : 'حصتك الشهرية: استُخدم ${quota['used'] ?? '؟'} من '
                  '${quota['limit']} — المتبقي ${quota['remaining'] ?? '؟'}';
        });
      } else {
        // رموز البوابة الصادقة تُترجم لكلام المدير — لا تُبتلع (درس
        // زر «اقترح رداً»: رسالة بلا تفاصيل تعمي التشخيص).
        final code = body?['error']?.toString() ?? 'HTTP ${res.statusCode}';
        setState(() {
          _error = switch (code) {
            'invalid_key' =>
              'المفتاح مرفوض — تأكد أنك لصقته كاملاً، أو أصدر بديلاً من zol',
            'quota_exceeded' =>
              'نفدت حصة هذا الشهر (${body?['used']}/${body?['quota']}) — '
                  'تُرفع من لوحة zol',
            'partner_suspended' => 'الشراكة موقوفة من طرف zol — راجعهم',
            _ => 'تعذّر التوليد ($code) — حاول مجدداً',
          };
        });
      }
    } catch (e) {
      setState(
          () => _error = 'تعذّر الاتصال بالبوابة — تأكد من الإنترنت ($e)');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// نص الصيغة كاملاً للنسخ — جاهز للصق في المنصة مباشرة.
  String _variantText(Map<String, dynamic> v) {
    final hashtags = (v['hashtags'] as List? ?? const []).join(' ');
    return [
      if ((v['headline'] ?? '').toString().isNotEmpty) v['headline'],
      if ((v['body'] ?? '').toString().isNotEmpty) v['body'],
      if ((v['cta'] ?? '').toString().isNotEmpty) v['cta'],
      if (hashtags.isNotEmpty) hashtags,
    ].join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    if (!_keyChecked) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (_storedKey == null) ...[
          // إعداد لمرة واحدة: لصق المفتاح.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إعداد لمرة واحدة',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14.5)),
                    const SizedBox(height: 6),
                    const Text(
                      'الصق مفتاح شريك الإعلانات (يبدأ بـ pk_live) — يُحفظ '
                      'في مستند لا يقرؤه غير المدير، ولا يدخل كود التطبيق.',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _keyCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'مفتاح الشريك',
                        hintText: 'pk_live_...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(_saving ? 'جارٍ الحفظ…' : 'احفظ المفتاح'),
                      onPressed: _saving ? null : _saveKey,
                    ),
                  ]),
            ),
          ),
        ] else ...[
          const Text(
            'اكتب ما تريد الإعلان عنه (منتج، عرض، مناسبة) واختر المنصة — '
            'تصلك ثلاث صيغ مرتّبة، تنسخ ما يعجبك وتنشره.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textGray),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ماذا نعلن؟',
              hintText: 'مثال: عرض فطيرة الجمعة — قطعتان بسعر واحدة، توصيل مجاني فوق ٥٠ ريالاً',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _platforms
                .map((p) => ChoiceChip(
                      label: Text(p.$2),
                      selected: _platform == p.$1,
                      onSelected: (_) => setState(() => _platform = p.$1),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_generating ? 'جارٍ التوليد…' : 'ولّد إعلاناً ✨'),
              onPressed: _generating ? null : _generate,
            ),
          ),
          if (_quotaLine != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_quotaLine!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textGray)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Card(
                color: AppColors.errorLight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.error)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          ..._variants.map((v) => Card(
                margin: const EdgeInsets.only(top: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                AppColors.primary.withOpacity(0.15),
                            child: Text('${v['rank'] ?? '؟'}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${v['angle'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGray)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'انسخ الإعلان كاملاً',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _variantText(v)));
                              showSuccess(context, 'نُسخ — الصقه في المنصة');
                            },
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text('${v['headline'] ?? ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text('${v['body'] ?? ''}',
                            style:
                                const TextStyle(fontSize: 13.5, height: 1.6)),
                        const SizedBox(height: 6),
                        Text('${v['cta'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                        if ((v['hashtags'] as List? ?? const [])
                            .isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                              (v['hashtags'] as List).join(' '),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textGray)),
                        ],
                      ]),
                ),
              )),
          const SizedBox(height: 18),
          // تبديل المفتاح — للطوارئ (تسريب/إبطال): يعيد شاشة اللصق.
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.key_off_outlined, size: 16),
              label: const Text('تبديل المفتاح',
                  style: TextStyle(fontSize: 12.5)),
              onPressed: () => setState(() => _storedKey = null),
            ),
          ),
        ],
      ],
    );
  }
}
