// مركز المساعدة (دفعة ٥ — النمو والاحتفاظ): أسئلة شائعة داخل التطبيق بدل
// إحالة العميل إلى واتساب أو دليل خارجي عند كل سؤال. المعيار العالمي (أوبر
// إيتس/دور داش/هنقرستيشن): مركزٌ مصنَّف يجيب أكثر الأسئلة تكراراً فوراً، ثم
// زرّ «تواصل مع الدعم» لما لا يُجاب هنا — فيقلّ ضغط التذاكر ويرتاح العميل.
//
// لماذا محتوى ثابت لا مستند Firestore؟ الأسئلة الشائعة نصٌّ لا يتغيّر مع كل
// طلب، وتحميله من الشبكة يعني شاشةً بيضاء وانتظاراً وعطلاً محتملاً بلا اتصال
// — بينما المساعدة أحوج ما تكون للعمل ساعةَ العطل. أيّ تحديث نصّ يأتي مع
// تحديث التطبيق (والأدلة الخمس في dev-docs هي المصدر الموسَّع).
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/app_lang.dart';
import 'submit_ticket_screen.dart';

class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}

class _FaqSection {
  final String title;
  final IconData icon;
  final List<_Faq> items;
  const _FaqSection(this.title, this.icon, this.items);
}

// getter لا قائمة const: tr() تُقيَّم وقت التشغيل، فتُبنى القائمة عند كل
// build باللغة الحالية.
List<_FaqSection> get _sections => [
      _FaqSection(
          tr('الطلب والتوصيل', 'Orders & delivery'),
          Icons.delivery_dining_rounded, [
        _Faq(
            tr('كيف أتتبّع طلبي؟', 'How do I track my order?'),
            tr('افتح «طلباتي» من الشريط السفلي، ثم اضغط الطلب الجاري — ترى مرحلته الحالية على شريط التتبّع، وموقع الكابتن على الخريطة حين يتحرّك إليك.',
                'Open "My orders" from the bottom bar, then tap the active order — you\'ll see its current stage on the tracking bar, and the captain\'s location on the map once they head your way.')),
        _Faq(
            tr('كم يستغرق وصول الطلب؟', 'How long does delivery take?'),
            tr('يعتمد على تحضير المطعم والمسافة. يظهر لك زمنٌ تقديريّ على بطاقة المطعم، ويبدأ العدّ من لحظة قبول المطعم للطلب.',
                'It depends on the restaurant\'s prep time and the distance. An estimated time shows on the restaurant card, and the clock starts once the restaurant accepts your order.')),
        _Faq(
            tr('هل أستطيع إلغاء الطلب؟', 'Can I cancel my order?'),
            tr('يمكنك الإلغاء ما دام المطعم لم يبدأ التحضير. بعد بدء التحضير يتعذّر الإلغاء الذاتي — تواصل مع الدعم وسنساعدك حسب حالة الطلب.',
                'You can cancel as long as the restaurant hasn\'t started preparing your order. After that, self-cancellation isn\'t available — contact support and we\'ll help based on the order\'s status.')),
        _Faq(
            tr('كيف أغيّر عنوان التوصيل؟', 'How do I change the delivery address?'),
            tr('تُحدَّد نقطة التوصيل على الخريطة في السلة قبل تأكيد الطلب. عناوينك المحفوظة في «حسابي» تُسرّع ذلك في المرّات القادمة.',
                'You set the delivery point on the map in the cart before confirming the order. Saved addresses in "My account" make it faster next time.')),
      ]),
      _FaqSection(
          tr('الدفع والمحفظة', 'Payment & wallet'),
          Icons.account_balance_wallet_rounded, [
        _Faq(
            tr('ما طرق الدفع المتاحة؟', 'What payment methods are available?'),
            tr('الدفع نقداً عند الاستلام، أو بالبطاقة داخل التطبيق. رصيد محفظتك — إن وُجد — يُخصم أولاً من قيمة الطلب.',
                'Cash on delivery, or card payment in the app. Your wallet balance — if any — is applied to the order total first.')),
        _Faq(
            tr('ما هو رصيد المحفظة وكيف يزيد؟', 'What is the wallet balance and how does it grow?'),
            tr('المحفظة رصيدٌ يُخصم من طلباتك القادمة. يزيد عبر التعويضات عند حلّ الشكاوى، أو مكافآت المنصّة. تُشاهد كل حركاته في «حسابي ← حركات المحفظة».',
                'The wallet is credit applied to your future orders. It grows through compensations when complaints are resolved, or platform rewards. See every transaction in "My account → Wallet transactions".')),
        _Faq(
            tr('متى يُعاد ثمن طلب أُلغي؟', 'When is a cancelled order refunded?'),
            // مطابقة النص للمسار الفعلي (مراجعة 2026-08-22): ردّ البطاقة
            // يُنفَّذ من بوابة الدفع إلى بطاقة العميل نفسها — لا إلى
            // المحفظة؛ الوعد القديم كان يَعِد بما لا يقع فيولّد شكاوى.
            // أما ما دُفع من رصيد المحفظة فيعود إليها فوراً.
            tr('ما دفعتَه من رصيد محفظتك يعود إليها فوراً. وما دفعتَه بالبطاقة يُعيده فريقنا إلى بطاقتك نفسها، ويظهر في كشف بنكك خلال أيام عمل بحسب مصرفك.',
                'Whatever you paid from your wallet balance returns to it immediately. Card payments are refunded by our team to the same card, appearing on your bank statement within a few business days depending on your bank.')),
      ]),
      _FaqSection(
          tr('الكوبونات والخصومات', 'Coupons & discounts'),
          Icons.local_offer_rounded, [
        _Faq(
            tr('كيف أستخدم كوبون خصم؟', 'How do I use a coupon?'),
            tr('في السلة، أدخل رمز الكوبون في خانة «كود الخصم» ثم اضغط تطبيق. يظهر الخصم فوراً على الإجمالي إن كان الكود صالحاً ومستوفياً شروطه.',
                'In the cart, enter the code in the "Promo code" field and tap apply. The discount shows on the total right away if the code is valid and meets its conditions.')),
        _Faq(
            tr('لماذا رُفض الكوبون؟', 'Why was my coupon rejected?'),
            tr('قد يكون الكود منتهياً، أو مخصّصاً لمطعم آخر، أو طلبك أقلّ من الحدّ الأدنى المطلوب، أو استُنفد عدد استخداماته. تأكّد من الشروط أو جرّب كوداً آخر.',
                'The code may be expired, tied to a different restaurant, your order may be below the required minimum, or the code\'s uses may be used up. Check the conditions or try another code.')),
      ]),
      _FaqSection(
          tr('الحساب والخصوصية', 'Account & privacy'), Icons.person_rounded, [
        _Faq(
            tr('كيف أعدّل اسمي أو جوّالي؟', 'How do I edit my name or phone number?'),
            tr('من «حسابي» اضغط أيقونة القلم على بطاقة ملفّك الشخصي، عدّل البيانات ثم احفظ.',
                'From "My account", tap the pencil icon on your profile card, edit your details, then save.')),
        _Faq(
            tr('كيف أحذف حسابي؟', 'How do I delete my account?'),
            tr('من أسفل «حسابي» اختر «حذف الحساب». يُخفى اسمك وبياناتك، وتبقى السجلّات المالية باسمٍ مجهول كما يقتضي النظام. الحذف نهائيّ.',
                'At the bottom of "My account", choose "Delete account". Your name and details are hidden, and financial records remain anonymized as the law requires. Deletion is permanent.')),
        _Faq(
            tr('هل بياناتي آمنة؟', 'Is my data safe?'),
            tr('نعم — لا نشارك بياناتك مع جهات إعلانية. تفاصيل الخصوصية الكاملة في سياسة الخصوصية على موقعنا.',
                'Yes — we don\'t share your data with advertisers. Full details are in the privacy policy on our website.')),
      ]),
    ];

class HelpCenterScreen extends StatelessWidget {
  final AppUser user;
  const HelpCenterScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('مركز المساعدة', 'Help center'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // ترويسة موجزة تطمئن العميل أنّ الجواب هنا غالباً قبل التذكرة.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.support_agent_rounded, color: AppColors.dark, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('كيف نساعدك؟', 'How can we help?'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          for (final section in _sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
              child: Row(children: [
                Icon(section.icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(section.title,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
              ]),
            ),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < section.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ExpansionTile(
                      title: Text(section.items[i].q,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.items[i].a,
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                color: AppColors.textGray)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          // مخرج «لم أجد جوابي» → تذكرة دعم: لا يترك العميل في طريق مسدود.
          Text(tr('لم تجد إجابتك؟', 'Didn\'t find your answer?'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textGray)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(tr('تواصل مع الدعم', 'Contact support')),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubmitTicketScreen(
                    submittedByUid: user.uid,
                    submittedByName: user.name,
                    submittedByRole: UserRole.customer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
