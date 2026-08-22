// lib/screens/driver/captain_guide_screen.dart
//
// دليل الكابتن — تدريب داخل التطبيق (نمط أكاديمية نينجا/جاهز): خمسة دروس
// قصيرة تغطي رحلة السائق كاملة بمصطلحات تطبيقنا نفسها (العرض، المذكرة،
// العُهدة، النطاق، السحب) — فيتعلم السائق الجديد وحده بدل مكالمات شرح
// متكررة مع الإدارة.
//
// محتوى ثابت بلا أصول ولا شبكة — يعمل حتى بلا اتصال.
import 'package:flutter/material.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';

class CaptainGuideScreen extends StatelessWidget {
  const CaptainGuideScreen({super.key});

  // getter لا ثابت: tr() تُقيَّم وقت البناء فتنقلب الدروس مع تبديل اللغة.
  static List<(IconData, String, List<String>)> get _lessons => [
        (
          Icons.wifi_tethering_rounded,
          tr('الاتصال والعروض', 'Going online & offers'),
          [
            tr('فعّل «متاح» من البطاقة أعلى الطلبات — لن يصلك أي عرض وأنت غير متصل.',
                'Turn on "Available" from the card above your orders — no offers reach you while you are offline.'),
            tr('عند إسناد طلب لك تظهر بطاقة عرض فيها: أجرتك، مسافة الالتقاط، مسافة التوصيل، ومبلغ التحصيل إن كان نقدياً.',
                'When an order is assigned to you, an offer card shows: your fee, pickup distance, drop-off distance, and the amount to collect if it is a cash order.'),
            tr('معك 45 ثانية للقرار — انقضاؤها أو الرفض يمرّر الطلب لسائق آخر.',
                'You have 45 seconds to decide — letting it expire or rejecting passes the order to another captain.'),
            tr('معدل قبولك محفوظ في حسابك ويظهر في «أرباحي» — حافظ عليه مرتفعاً.',
                'Your acceptance rate is saved on your account and shown in "My earnings" — keep it high.'),
          ],
        ),
        (
          Icons.receipt_long_rounded,
          tr('الاستلام من المطعم', 'Picking up from the restaurant'),
          [
            tr('اضغط «وصلتُ المطعم» عند وصولك — يُسجَّل وقتك وموقعك وهو حجّتك في أي نزاع تأخير.',
                'Tap "Arrived at restaurant" when you get there — your time and location are recorded, and they are your proof in any delay dispute.'),
            tr('اعرض «مذكرة الاستلام» لموظف المطعم — رقم الطلب الضخم يقرؤه من بعيد.',
                'Show the "Pickup memo" to the restaurant staff — the large order number can be read from a distance.'),
            tr('القاعدة الذهبية: طابق رقم الطلب على ملصق الكيس وعدد الأصناف قبل المغادرة — تمنع «الطلب الخاطئ» من جذره.',
                'The golden rule: match the order number on the bag label and the item count before leaving — it stops "wrong order" at the root.'),
            tr('زر «استلمت الطلب» يعمل فقط ضمن 100 متر من المطعم.',
                'The "Picked up" button only works within 100 meters of the restaurant.'),
            tr('الصورة عند الاستلام اختيارية — لكنها تحميك في أي خلاف.',
                'The pickup photo is optional — but it protects you in any dispute.'),
          ],
        ),
        (
          Icons.delivery_dining_rounded,
          tr('التوصيل والتسليم', 'Delivering & handover'),
          [
            tr('«ابدأ الملاحة» يفتح خرائط جوجل نحو وجهتك الحالية: المطعم قبل الاستلام، والعميل بعده.',
                '"Start navigation" opens Google Maps to your current destination: the restaurant before pickup, the customer after.'),
            tr('الطلب النقدي: لافتة حمراء تذكّرك بالمبلغ — حصّله كاملاً قبل تسليم الكيس.',
                'Cash orders: a red banner reminds you of the amount — collect it in full before handing over the bag.'),
            tr('زر «تأكيد التوصيل» يعمل فقط ضمن 150 متراً من عنوان العميل.',
                'The "Confirm delivery" button only works within 150 meters of the customer address.'),
            tr('تعذّر الوصول للعميل؟ اتصل به من زر الهاتف، أو راسله من المحادثة — وكل ذلك مسجّل لصالحك.',
                "Can't reach the customer? Call them from the phone button or message them in the chat — all of it is logged in your favor."),
          ],
        ),
        (
          Icons.account_balance_wallet_rounded,
          tr('محفظتك والعُهدة', 'Your wallet & cash in hand'),
          [
            tr('استلمت طلباً نقدياً؟ تُقيَّد قيمته على محفظتك (عُهدة) لأن البضاعة صارت بيدك — وعند التسليم تقبض كامل المبلغ: قيمة الطلب تسدّ العُهدة وأجرتك ربحك.',
                'Picked up a cash order? Its value is charged to your wallet (cash in hand) because the goods are now with you — on delivery you collect the full amount: the order value clears the charge and your fee is your profit.'),
            tr('الطلب المدفوع إلكترونياً: لا عُهدة، وأجرتك تُضاف لرصيدك.',
                'Orders paid online: no cash in hand, and your fee is added to your balance.'),
            tr('رصيدك موجب؟ اسحبه بنفسك من زر «اسحب أموالي» — الإدارة تصرف وتقيّد الحركة في سجلّك.',
                'Positive balance? Withdraw it yourself with "Withdraw my money" — the office pays out and logs the transaction in your ledger.'),
            tr('رصيدك سالب (عُهدة بيدك)؟ سدّده بتسليم نقدي أو تحويل للإدارة من «شحن المحفظة».',
                'Negative balance (cash in hand)? Settle it with a cash handover or a bank transfer to the office via "Top up wallet".'),
            tr('أُلغي طلب بعد استلامك؟ تُردّ عُهدته لمحفظتك تلقائياً — كل حركة لها سطر في السجلّ.',
                'Order canceled after pickup? Its cash-in-hand charge is reversed to your wallet automatically — every movement has a line in the ledger.'),
          ],
        ),
        (
          Icons.workspace_premium_rounded,
          tr('التقييم والسلوك', 'Ratings & conduct'),
          [
            tr('العميل يقيّمك بعد كل توصيلة — التقييم العالي يقدّمك في الإسناد التلقائي.',
                'Customers rate you after every delivery — a high rating moves you up in auto-assignment.'),
            tr('الإنذارات من الشكاوى المثبتة تتراكم — عند الثالث يُعلَّق حسابك حتى مراجعة الإدارة.',
                'Warnings from confirmed complaints add up — at the third, your account is suspended pending admin review.'),
            tr('عندك مشكلة مع عميل أو مطعم؟ قدّم شكوى من أيقونة الدعم — تُدرس ويُردّ عليك خلال 24 ساعة.',
                'Trouble with a customer or restaurant? File a complaint from the support icon — it is reviewed and answered within 24 hours.'),
            tr('لا تقبل عرضاً لن تلتزم به — الرفض المبكر أفضل للجميع من طلب معلّق.',
                "Don't accept an offer you won't follow through on — rejecting early is better for everyone than a stuck order."),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;
    return Scaffold(
      appBar: AppBar(title: Text(tr('دليل الكابتن', 'Captain guide'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [fc.primary, fc.primaryDark]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.school_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('خمسة دروس قصيرة تغطي رحلتك كاملة — من أول عرض إلى سحب أرباحك',
                    'Five short lessons covering your whole journey — from your first offer to withdrawing your earnings'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
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
                                      fontSize: 13.5, height: 1.7)),
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
