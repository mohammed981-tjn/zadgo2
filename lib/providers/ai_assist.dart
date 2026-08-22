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
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';

class AiAssist {
  AiAssist._();

  // درسُ 2026-08-16: أول اختبار ميداني فشل لأن `gemini-2.0-flash` كان
  // طرازاً **ميتاً** (أطفأته جوجل نهائياً في 2026-06-01) — جوجل تقاعد
  // أجيال Gemini كل بضعة أشهر. الدفاع طبقتان: الطراز المستقر الحالي
  // أولاً، فإن فشل نداؤه جرّبنا الاسم المستعار `gemini-flash-latest`
  // الذي تحوّله جوجل تلقائياً لأحدث إصدار — فيبقى الزر حياً حتى لو
  // تقاعد المستقر قبل أن نحدّث التطبيق.
  static const _primaryModel = 'gemini-3.7-flash';
  static const _fallbackModel = 'gemini-flash-latest';

  static final Map<String, GenerativeModel> _models = {};

  // تمرير appCheck **إلزامي لا اختياري** عندنا (درس 2026-08-16): بدونه
  // لا ترسل الحزمة توكن الحماية أصلاً — فيرفض خادم AI Logic الطلب
  // «App Check token is invalid» مهما فعّلنا الحماية وسجّلنا الرموز.
  static GenerativeModel _modelFor(String name) => _models[name] ??=
      FirebaseAI.googleAI(appCheck: FirebaseAppCheck.instance)
          .generativeModel(model: name);

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

    return _generate([Content.text(prompt)]);
  }

  /// يقرأ صورة منيو ورقي ويعيدها JSON بصيغة شاشة الاستيراد حرفياً —
  /// (دفعة «المنيو من صورة»، 2026-08-16): الناتج يُسكب في خانة اللصق
  /// فيمرّ من نفس خط التحليل والمعاينة والتأكيد البشري — الذكاء يقرأ
  /// والمدير يعتمد، كمبدئنا في كل ميزة.
  static Future<String> menuJsonFromImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    const prompt = '''
هذه صورة قائمة طعام (منيو) لمطعم. استخرج محتواها كاملاً بصيغة JSON
بهذا الشكل حرفياً ولا شيء غيره:
{"categories":[{"name":"اسم التصنيف","items":[{"name":"اسم الصنف","price":25,"description":"وصف قصير إن وُجد"}]}]}

قواعد صارمة:
- السعر رقم فقط بلا عملة. إن ظهر سعران لحجمين فاجعلهما صنفين
  («شاورما - وسط» و«شاورما - كبير»).
- إن لم تظهر تصنيفات في الصورة فاجمع الأصناف تحت تصنيف واحد باسم مناسب.
- لا تخترع أصنافاً ولا أسعاراً غير ظاهرة، وما تعذّرت قراءته أهمله.
- أعد JSON فقط: لا شرح، لا مقدمات، لا علامات تنسيق.''';

    final raw = await _generate([
      Content.multi([TextPart(prompt), InlineDataPart(mimeType, imageBytes)]),
    ]);
    // النماذج تغلّف JSON أحياناً بأسوار ماركداون رغم التعليمات — تُنزع.
    return raw
        .replaceFirst(RegExp(r'^```(json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }

  /// وصف شهي قصير لصنف منيو — «وصف الأصناف بضغطة» (2026-08-16):
  /// يوفر على المطعم الجديد صياغة عشرات الأوصاف، والمدير يعدّل ويحفظ
  /// بنفسه (الاقتراح يملأ الخانة ولا يُحفظ وحده).
  static Future<String> suggestDishDescription({
    required String dishName,
    String? category,
  }) {
    final prompt = '''
اكتب وصفاً شهياً قصيراً لصنف في منيو مطعم سعودي، بالعربية، في 10 إلى
18 كلمة (جملة أو جملتان): يصف الطعم أو القوام أو طريقة التقديم بصدق،
بلا مبالغات فارغة، وبلا سعر وبلا رموز تعبيرية.
قاعدة صارمة: لا تذكر مكوّناً محدداً (ثوم، مخلل، صوص بعينه...) لا يظهر
في اسم الصنف نفسه — وصفة المطعم قد تخلو منه، واختلاق مكوّنٍ في تطبيق
طعام بابُ تحسّسٍ ومسؤولية. صف الانطباع العام لا قائمة مكوّنات مفترضة.
اسم الصنف: $dishName${category != null && category.trim().isNotEmpty ? '\nتصنيفه في المنيو: $category' : ''}
أعد الوصف وحده بلا شرح.''';
    return _generate([Content.text(prompt)]);
  }

  /// حلقة التوليد المشتركة: الطراز المستقر ثم البديل التلقائي، ورسالة
  /// فشل تعرض التفاصيل التقنية — أول اختبار ميداني (2026-08-16) علّمنا
  /// أن رسالة لطيفة بلا تفاصيل تعمي التشخيص، والمدير قناتنا الوحيدة
  /// لقراءة الخطأ (لا سجلات جهاز عن بعد).
  /// الطراز الذي أجاب فعلاً في آخر توليد ناجح — يُختم في سجلّ التغذية
  /// الراجعة (ت٣٢): زوج تدريبٍ بلا اسم طرازه لا يصلح لمقارنة طرازٍ بطراز.
  static String? lastServedModel;

  static Future<String> _generate(List<Content> content) async {
    Object? lastError;
    for (final model in const [_primaryModel, _fallbackModel]) {
      try {
        // ت٣٧: مهلة صريحة — بلا حدٍّ كان الزر يبقى دائراً بلا نهاية على
        // شبكة رديئة فيُظنّ التطبيق متجمّداً، بينما الشاشة الشقيقة
        // (التحقق من الدفع) تضبط مهلتها صراحةً.
        final res = await _modelFor(model)
            .generateContent(content)
            .timeout(const Duration(seconds: 30));
        final text = res.text?.trim();
        if (text == null || text.isEmpty) {
          throw Exception('لم يصل ردّ — حاول مجدداً');
        }
        lastServedModel = model;
        return text;
      } catch (e) {
        debugPrint('AiAssist ($model) error: $e');
        lastError = e;
      }
    }
    final detail = lastError
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceAll('\n', ' ');
    throw Exception(
        'تعذّر التوليد — تأكد من الاتصال ومن تفعيل Gemini في '
        'كونسول فيربيز.\nالتفاصيل التقنية: '
        '${detail.length > 220 ? detail.substring(0, 220) : detail}');
  }
}
