// lib/screens/driver/captain_guide_screen.dart
//
// دليل الكابتن — تدريب داخل التطبيق (نمط أكاديمية نينجا/جاهز): خمسة دروس
// قصيرة تغطي رحلة السائق كاملة بمصطلحات تطبيقنا نفسها (العرض، المذكرة،
// العُهدة، النطاق، السحب) — فيتعلم السائق الجديد وحده بدل مكالمات شرح
// متكررة مع الإدارة.
//
// محتوى ثابت بلا أصول ولا شبكة — يعمل حتى بلا اتصال.
import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class CaptainGuideScreen extends StatelessWidget {
  const CaptainGuideScreen({super.key});

  static const _lessons = [
    (
      Icons.wifi_tethering_rounded,
      'الاتصال والعروض',
      [
        'فعّل «متاح» من البطاقة أعلى الطلبات — لن يصلك أي عرض وأنت غير متصل.',
        'عند إسناد طلب لك تظهر بطاقة عرض فيها: أجرتك، مسافة الالتقاط، مسافة التوصيل، ومبلغ التحصيل إن كان نقدياً.',
        'معك 45 ثانية للقرار — انقضاؤها أو الرفض يمرّر الطلب لسائق آخر.',
        'معدل قبولك محفوظ في حسابك ويظهر في «أرباحي» — حافظ عليه مرتفعاً.',
      ],
    ),
    (
      Icons.receipt_long_rounded,
      'الاستلام من المطعم',
      [
        'اضغط «وصلتُ المطعم» عند وصولك — يُسجَّل وقتك وموقعك وهو حجّتك في أي نزاع تأخير.',
        'اعرض «مذكرة الاستلام» لموظف المطعم — رقم الطلب الضخم يقرؤه من بعيد.',
        'القاعدة الذهبية: طابق رقم الطلب على ملصق الكيس وعدد الأصناف قبل المغادرة — تمنع «الطلب الخاطئ» من جذره.',
        'زر «استلمت الطلب» يعمل فقط ضمن 100 متر من المطعم.',
        'الصورة عند الاستلام اختيارية — لكنها تحميك في أي خلاف.',
      ],
    ),
    (
      Icons.delivery_dining_rounded,
      'التوصيل والتسليم',
      [
        '«ابدأ الملاحة» يفتح خرائط جوجل نحو وجهتك الحالية: المطعم قبل الاستلام، والعميل بعده.',
        'الطلب النقدي: لافتة حمراء تذكّرك بالمبلغ — حصّله كاملاً قبل تسليم الكيس.',
        'زر «تأكيد التوصيل» يعمل فقط ضمن 150 متراً من عنوان العميل.',
        'تعذّر الوصول للعميل؟ اتصل به من زر الهاتف، أو راسله من المحادثة — وكل ذلك مسجّل لصالحك.',
      ],
    ),
    (
      Icons.account_balance_wallet_rounded,
      'محفظتك والعُهدة',
      [
        'استلمت طلباً نقدياً؟ تُقيَّد قيمته على محفظتك (عُهدة) لأن البضاعة صارت بيدك — وعند التسليم تقبض كامل المبلغ: قيمة الطلب تسدّ العُهدة وأجرتك ربحك.',
        'الطلب المدفوع إلكترونياً: لا عُهدة، وأجرتك تُضاف لرصيدك.',
        'رصيدك موجب؟ اسحبه بنفسك من زر «اسحب أموالي» — الإدارة تصرف وتقيّد الحركة في سجلّك.',
        'رصيدك سالب (عُهدة بيدك)؟ سدّده بتسليم نقدي أو تحويل للإدارة من «شحن المحفظة».',
        'أُلغي طلب بعد استلامك؟ تُردّ عُهدته لمحفظتك تلقائياً — كل حركة لها سطر في السجلّ.',
      ],
    ),
    (
      Icons.workspace_premium_rounded,
      'التقييم والسلوك',
      [
        'العميل يقيّمك بعد كل توصيلة — التقييم العالي يقدّمك في الإسناد التلقائي.',
        'الإنذارات من الشكاوى المثبتة تتراكم — عند الثالث يُعلَّق حسابك حتى مراجعة الإدارة.',
        'عندك مشكلة مع عميل أو مطعم؟ قدّم شكوى من أيقونة الدعم — تُدرس ويُردّ عليك خلال 24 ساعة.',
        'لا تقبل عرضاً لن تلتزم به — الرفض المبكر أفضل للجميع من طلب معلّق.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;
    return Scaffold(
      appBar: AppBar(title: const Text('دليل الكابتن')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [fc.primary, fc.primaryDark]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(children: [
            Icon(Icons.school_rounded, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'خمسة دروس قصيرة تغطي رحلتك كاملة — من أول عرض إلى سحب أرباحك',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.6),
              ),
            ),
          ]),
        ),
        ...[
          for (final (i, lesson) in _lessons.indexed)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: fc.primary.withOpacity(0.12),
                  child: Icon(lesson.$1, size: 20, color: fc.primaryDark),
                ),
                title: Text('${i + 1}. ${lesson.$2}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  for (final point in lesson.$3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                  top: 5, end: 8),
                              child: Icon(Icons.circle,
                                  size: 7, color: fc.primary),
                            ),
                            Expanded(
                              child: Text(point,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.7)),
                            ),
                          ]),
                    ),
                ],
              ),
            ),
        ],
      ]),
    );
  }
}
