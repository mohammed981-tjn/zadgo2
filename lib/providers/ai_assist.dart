// lib/providers/ai_assist.dart
//
// مساعد الذكاء الاصطناعي (دفعة الذكاء ١ — 2026-08-15): Gemini داخل
// التطبيق عبر `firebase_ai` — **بلا خادم وبلا مفتاح مكشوف**: الحزمة
// تستدعي Gemini Developer API بهوية مشروع فيربيز نفسه (تعمل على خطة
// Spark المجانية)، فكسرت قيدنا التاريخي «لا ذكاء قبل Blaze».
//
// القرار المعماري: طبقة رقيقة قابلة للتبديل — الشاشات تطلب «اقتراح ردّ»
// ولا تعرف من أجاب. حين يُضاف ALLaM السعودي (عبر Hugging Face + دالة
// Supabase Edge بمفتاح سرّي، بقرار المالك «Gemini وALLaM معاً») يصير
// بديلاً خلف نفس الدالة بلا مسّ أي شاشة.
//
// مبدأ صارم: **الاقتراح لا يُرسل وحده أبداً** — يملأ حقل الردّ ليعدّله
// المدير ثم يرسله بنفسه. الذكاء يقترح والإنسان يقرّر — خاصة في شكوى
// فيها مال وسمعة.
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';

class AiAssist {
  AiAssist._();

  // gemini-2.0-flash: الطراز السريع الرخيص — مهمة الصياغة لا تحتاج أعمق
  // منه، والأسرع أنسب لزرّ يُضغط أثناء معالجة شكوى.
  static GenerativeModel? _model;

  static GenerativeModel get _instance => _model ??= FirebaseAI.googleAI()
      .generativeModel(model: 'gemini-2.0-flash');

  /// يقترح ردّاً عربياً مهذّباً على شكوى — للمدير أن يعدّله ثم يرسله.
  ///
  /// يرمي استثناءً برسالة عربية عند الفشل (لا اتصال، أو لم تُفعَّل واجهة
  /// Gemini من كونسول فيربيز بعد) — والشاشة تعرضها بلا انهيار.
  static Future<String> suggestComplaintReply({
    required Complaint complaint,
    String? resolutionDraft,
  }) async {
    final prompt = '''
أنت مساعد خدمة عملاء لتطبيق توصيل طعام سعودي اسمه «زاد قو».
اكتب ردّاً على شكوى العميل التالية بالعربية الفصحى المبسّطة، بنبرة
محترمة ومتعاطفة وواثقة، في 3 إلى 5 جمل، بلا مقدمات إنشائية طويلة:
- ابدأ بالاعتذار أو التفهّم بحسب نوع الشكوى.
- اذكر الإجراء المتخذ إن وُجد (لا تختلق إجراءً لم يُذكر).
- اختم بجملة تحفظ ثقة العميل.
- لا تعد بمالٍ أو تعويض لم يُذكر في «الإجراء المتخذ».

نوع الشكوى: ${complaint.type.label}
نص الشكوى: ${complaint.description}
${resolutionDraft != null && resolutionDraft.trim().isNotEmpty ? 'الإجراء المتخذ: $resolutionDraft' : 'لم يُتخذ إجراء بعد.'}

أعد الردّ وحده بلا أي شرح أو عناوين.''';

    try {
      final res = await _instance.generateContent([Content.text(prompt)]);
      final text = res.text?.trim();
      if (text == null || text.isEmpty) {
        throw Exception('لم يصل اقتراح — حاول مجدداً');
      }
      return text;
    } catch (e) {
      debugPrint('AiAssist error: $e');
      throw Exception(
          'تعذّر توليد الاقتراح — تأكد من الاتصال، ومن تفعيل Gemini في '
          'كونسول فيربيز (Firebase AI Logic ← Get started) لأول مرة');
    }
  }
}
