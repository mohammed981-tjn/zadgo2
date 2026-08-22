// مزوّد اللغة (دفعة «اللغة الثانية»): العربية أصل التطبيق والإنجليزية ثانية.
//
// لماذا مساعدٌ مضمَّن `tr('عربي', 'English')` لا ملفات ARB وتوليد أكواد؟
// قرارٌ هندسي مقصود: نحو ٢٨٠٠ نصٍّ عربي مثبَّت في الكود، ونقلها لمفاتيح
// مجرّدة (ARB) يفصل النص عن موضعه فيصعب على من يعدّل الشاشة لاحقاً أن يرى
// ما يعرضه — بينما المساعد يُبقي العربي ظاهراً في مكانه والإنجليزي بجانبه،
// والفرق في المراجعة سطرٌ بسطر. ولا حزم جديدة (أ٦): flutter_localizations
// وshared_preferences موجودتان أصلاً.
//
// الاتجاه (RTL/LTR) ينقلب مع اللغة من MaterialApp نفسه، فكل الشاشات تُعاد
// بناؤها عند التبديل لأن التطبيق كله يستمع لهذا المزوّد.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLang extends ChangeNotifier {
  static const _prefsKey = 'app_lang_en';

  /// علمٌ ساكن يقرؤه [tr] من أي مكان — حتى حيث لا context (دوالّ تسمية
  /// المودل والمساعدات الخالصة). يتزامن مع المثيل عند التهيئة والتبديل،
  /// ولا خطر من السكون: التبديل يعيد بناء الشجرة كلها عبر notifyListeners
  /// فلا تبقى شاشة على اللغة القديمة.
  static bool en = false;

  /// تُستدعى في main() قبل runApp حتى يُرسم أول إطار باللغة المحفوظة
  /// مباشرةً — بلا وميض عربي ثم انقلاب.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      en = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      // تعذّر القراءة = الافتراضي العربي؛ لا نعطّل الإقلاع لتفضيل عرض.
    }
  }

  bool get isEn => en;
  Locale get locale => en ? const Locale('en') : const Locale('ar');
  TextDirection get direction => en ? TextDirection.ltr : TextDirection.rtl;

  Future<void> setEnglish(bool value) async {
    if (en == value) return;
    en = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }

  Future<void> toggle() => setEnglish(!en);
}

/// المترجم المضمَّن: يعيد العربي أو الإنجليزي حسب اللغة الحالية.
///
/// العربي أولاً عمداً — هو لغة الأصل في الكود كله، فيبقى أول ما تقع عليه
/// العين عند القراءة. كلا النصّين يُقيَّم دائماً (لا كسل) وهذا مقصود:
/// نصوص واجهة قصيرة لا كلفة لها، والبساطة تسبق التحسين.
String tr(String ar, String en) => AppLang.en ? en : ar;

/// زرّ تبديل اللغة الموحّد — يعرض اسم اللغة **الهدف** لا الحالية (المعيار
/// العالمي: من يقرأ العربية يرى «EN» ليعرف أين يذهب، والعكس)، ويصلح
/// لشريط العنوان في كل النكهات.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLang>();
    return TextButton.icon(
      onPressed: () => context.read<AppLang>().toggle(),
      icon: const Icon(Icons.language_rounded, size: 18),
      label: Text(
        lang.isEn ? 'عربي' : 'EN',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

/// بند قائمة لتبديل اللغة — للأدراج والقوائم (لوحة الإدارة وحساب العميل).
class LanguageToggleTile extends StatelessWidget {
  const LanguageToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLang>();
    return ListTile(
      leading: const Icon(Icons.language_rounded),
      title: Text(tr('اللغة', 'Language')),
      subtitle: Text(lang.isEn ? 'English' : 'العربية',
          style: const TextStyle(fontSize: 12.5)),
      trailing: Text(lang.isEn ? 'عربي' : 'EN',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
      onTap: () => context.read<AppLang>().toggle(),
    );
  }
}
