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
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/app_lang.dart';
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

  // getter لا const: التسميات تمرّ بـ tr() فتتبدّل مع تبديل اللغة.
  static List<(String, String)> get _platforms => [
        ('instagram', tr('إنستغرام', 'Instagram')),
        ('snapchat', tr('سناب شات', 'Snapchat')),
        ('twitter', tr('X / تويتر', 'X / Twitter')),
        ('tiktok', tr('تيك توك', 'TikTok')),
      ];

  final _productCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  String? _storedKey; // null = لم يُحمَّل بعد أو غير موجود
  bool _keyChecked = false;
  bool _saving = false;
  bool _generating = false;
  bool _sending = false;
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
      showError(context, tr('المفتاح يبدأ بـ pk_ — انسخه كاملاً كما صدر',
          'The key starts with pk_ — copy it exactly as issued'));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<FirebaseService>().saveZolPartnerKey(key);
      _keyCtrl.clear();
      if (mounted) {
        setState(() => _storedKey = key);
        showSuccess(context, tr('حُفظ المفتاح — جاهز للتوليد',
            'Key saved — ready to generate'));
      }
    } catch (_) {
      if (mounted) {
        showError(context, tr('تعذّر الحفظ، حاول مرة أخرى',
            'Could not save, try again'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generate() async {
    final product = _productCtrl.text.trim();
    if (product.isEmpty) {
      showError(context, tr('اكتب ما تريد الإعلان عنه أولاً',
          'Write what you want to advertise first'));
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
              ? tr('حصتك: بلا حدّ', 'Your quota: unlimited')
              : tr(
                  'حصتك الشهرية: استُخدم ${quota['used'] ?? '؟'} من '
                      '${quota['limit']} — المتبقي ${quota['remaining'] ?? '؟'}',
                  'Monthly quota: used ${quota['used'] ?? '?'} of '
                      '${quota['limit']} — ${quota['remaining'] ?? '?'} remaining');
        });
      } else {
        // رموز البوابة الصادقة تُترجم لكلام المدير — لا تُبتلع (درس
        // زر «اقترح رداً»: رسالة بلا تفاصيل تعمي التشخيص).
        final code = body?['error']?.toString() ?? 'HTTP ${res.statusCode}';
        setState(() {
          _error = switch (code) {
            'invalid_key' => tr(
                'المفتاح مرفوض — تأكد أنك لصقته كاملاً، أو أصدر بديلاً من zol',
                'Key rejected — make sure you pasted it in full, or issue a new one from zol'),
            'quota_exceeded' => tr(
                'نفدت حصة هذا الشهر (${body?['used']}/${body?['quota']}) — '
                    'تُرفع من لوحة zol',
                'This month\'s quota is used up (${body?['used']}/${body?['quota']}) — '
                    'raise it from the zol dashboard'),
            'partner_suspended' => tr('الشراكة موقوفة من طرف zol — راجعهم',
                'Partnership suspended by zol — contact them'),
            _ => tr('تعذّر التوليد ($code) — حاول مجدداً',
                'Generation failed ($code) — try again'),
          };
        });
      }
    } catch (e) {
      setState(() => _error = tr(
          'تعذّر الاتصال بالبوابة — تأكد من الإنترنت ($e)',
          'Could not reach the gateway — check your connection ($e)'));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// إرسال الصيغة **بثاً جماعياً لعملاء التطبيق** — سؤال المالك
  /// 2026-08-16: «أين يظهر الإعلان للعميل؟». كانت الشاشة تولّد نصاً
  /// ينتهي في الحافظة، والقناة المملوكة لنا (البث) على بعد شاشتين —
  /// فوُصلت هنا: من الفكرة إلى شاشة العميل بضغطتين، بلا إنستغرام ولا
  /// نسخ ولصق. (البنر يتطلب صورة إلزاماً فليس قناة نصّ.)
  Future<void> _sendAsBroadcast(Map<String, dynamic> v) async {
    final title = (v['headline'] ?? '').toString().trim();
    final body = [
      if ((v['body'] ?? '').toString().trim().isNotEmpty) v['body'],
      if ((v['cta'] ?? '').toString().trim().isNotEmpty) v['cta'],
    ].join('\n');
    if (title.isEmpty || body.isEmpty) {
      showError(context, tr('الصيغة ناقصة — جرّب صيغة أخرى',
          'This variant is incomplete — try another one'));
      return;
    }

    // تأكيد صريح: البث يصل **كل** العملاء دفعة واحدة ولا يُسترجع.
    final ok = await showConfirmDialog(
      context,
      title: tr('إرسال لكل العملاء؟', 'Send to all customers?'),
      content: tr(
          'سيصل هذا الإعلان إلى كل عملاء زاد قو داخل التطبيق:\n\n'
          '«$title»\n$body\n\nالإرسال فوري ولا يمكن التراجع عنه.',
          'This ad will reach every ZadGo customer inside the app:\n\n'
          '"$title"\n$body\n\nSending is immediate and cannot be undone.'),
      confirmLabel: tr('أرسل الآن', 'Send now'),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    try {
      final auth = context.read<app_auth.AuthProvider>();
      await context.read<FirebaseService>().sendBroadcast(BroadcastMessage(
            id: const Uuid().v4(),
            audience: BroadcastAudience.customers,
            title: title,
            body: body,
            sentBy: auth.user?.name ?? auth.user?.uid ?? 'admin',
            createdAt: DateTime.now(),
          ));
      if (mounted) {
        showSuccess(context, tr('أُرسل الإعلان لكل العملاء ✓',
            'Ad sent to all customers ✓'));
      }
    } catch (_) {
      if (mounted) {
        showError(context, tr('تعذّر الإرسال، حاول مرة أخرى',
            'Could not send, try again'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
                    Text(tr('إعداد لمرة واحدة', 'One-time setup'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14.5)),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                          'الصق مفتاح شريك الإعلانات (يبدأ بـ pk_live) — يُحفظ '
                          'في مستند لا يقرؤه غير المدير، ولا يدخل كود التطبيق.',
                          'Paste the ads partner key (starts with pk_live) — it is stored '
                          'in a document only the admin can read, and never enters the app code.'),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _keyCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: tr('مفتاح الشريك', 'Partner key'),
                        hintText: 'pk_live_...',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(_saving
                          ? tr('جارٍ الحفظ…', 'Saving…')
                          : tr('احفظ المفتاح', 'Save key')),
                      onPressed: _saving ? null : _saveKey,
                    ),
                  ]),
            ),
          ),
        ] else ...[
          const Text(
            'اكتب ما تريد الإعلان عنه (منتج، عرض، مناسبة) واختر أسلوب '
            'المنصة — تصلك ثلاث صيغ: **«أرسله للعملاء»** يصل إعلاناً '
            'لكل عملاء زاد قو داخل التطبيق فوراً، و«انسخ النص» للنشر '
            'في حساباتك الخارجية.',
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
                        const Divider(height: 20),
                        // زرّان صريحان بدل أيقونة نسخ صغيرة لم يلحظها
                        // المالك أصلاً: ميزة لا تُرى كأنها لم تُبنَ.
                        Row(children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success),
                              icon: const Icon(Icons.campaign_outlined,
                                  size: 17),
                              label: const Text('أرسله للعملاء',
                                  style: TextStyle(fontSize: 12.5)),
                              onPressed: _sending
                                  ? null
                                  : () => _sendAsBroadcast(v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.copy_rounded, size: 17),
                              label: const Text('انسخ النص',
                                  style: TextStyle(fontSize: 12.5)),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: _variantText(v)));
                                showSuccess(context,
                                    'نُسخ — الصقه في أي منصة تريدها');
                              },
                            ),
                          ),
                        ]),
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
