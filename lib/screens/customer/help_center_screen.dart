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

const List<_FaqSection> _sections = [
  _FaqSection('الطلب والتوصيل', Icons.delivery_dining_rounded, [
    _Faq('كيف أتتبّع طلبي؟',
        'افتح «طلباتي» من الشريط السفلي، ثم اضغط الطلب الجاري — ترى مرحلته الحالية على شريط التتبّع، وموقع الكابتن على الخريطة حين يتحرّك إليك.'),
    _Faq('كم يستغرق وصول الطلب؟',
        'يعتمد على تحضير المطعم والمسافة. يظهر لك زمنٌ تقديريّ على بطاقة المطعم، ويبدأ العدّ من لحظة قبول المطعم للطلب.'),
    _Faq('هل أستطيع إلغاء الطلب؟',
        'يمكنك الإلغاء ما دام المطعم لم يبدأ التحضير. بعد بدء التحضير يتعذّر الإلغاء الذاتي — تواصل مع الدعم وسنساعدك حسب حالة الطلب.'),
    _Faq('كيف أغيّر عنوان التوصيل؟',
        'تُحدَّد نقطة التوصيل على الخريطة في السلة قبل تأكيد الطلب. عناوينك المحفوظة في «حسابي» تُسرّع ذلك في المرّات القادمة.'),
  ]),
  _FaqSection('الدفع والمحفظة', Icons.account_balance_wallet_rounded, [
    _Faq('ما طرق الدفع المتاحة؟',
        'الدفع نقداً عند الاستلام، أو بالبطاقة داخل التطبيق. رصيد محفظتك — إن وُجد — يُخصم أولاً من قيمة الطلب.'),
    _Faq('ما هو رصيد المحفظة وكيف يزيد؟',
        'المحفظة رصيدٌ يُخصم من طلباتك القادمة. يزيد عبر التعويضات عند حلّ الشكاوى، أو مكافآت المنصّة. تُشاهد كل حركاته في «حسابي ← حركات المحفظة».'),
    _Faq('متى يُعاد ثمن طلب أُلغي؟',
        'إن كنت دفعت بالبطاقة وأُلغي الطلب قبل التحضير، يُعاد المبلغ إلى محفظتك ليُستخدم في طلبك التالي — يظهر كحركة «استرداد».'),
  ]),
  _FaqSection('الكوبونات والخصومات', Icons.local_offer_rounded, [
    _Faq('كيف أستخدم كوبون خصم؟',
        'في السلة، أدخل رمز الكوبون في خانة «كود الخصم» ثم اضغط تطبيق. يظهر الخصم فوراً على الإجمالي إن كان الكود صالحاً ومستوفياً شروطه.'),
    _Faq('لماذا رُفض الكوبون؟',
        'قد يكون الكود منتهياً، أو مخصّصاً لمطعم آخر، أو طلبك أقلّ من الحدّ الأدنى المطلوب، أو استُنفد عدد استخداماته. تأكّد من الشروط أو جرّب كوداً آخر.'),
  ]),
  _FaqSection('الحساب والخصوصية', Icons.person_rounded, [
    _Faq('كيف أعدّل اسمي أو جوّالي؟',
        'من «حسابي» اضغط أيقونة القلم على بطاقة ملفّك الشخصي، عدّل البيانات ثم احفظ.'),
    _Faq('كيف أحذف حسابي؟',
        'من أسفل «حسابي» اختر «حذف الحساب». يُخفى اسمك وبياناتك، وتبقى السجلّات المالية باسمٍ مجهول كما يقتضي النظام. الحذف نهائيّ.'),
    _Faq('هل بياناتي آمنة؟',
        'نعم — لا نشارك بياناتك مع جهات إعلانية. تفاصيل الخصوصية الكاملة في سياسة الخصوصية على موقعنا.'),
  ]),
];

class HelpCenterScreen extends StatelessWidget {
  final AppUser user;
  const HelpCenterScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مركز المساعدة')),
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
                child: Text('كيف نساعدك؟',
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
          Text('لم تجد إجابتك؟',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textGray)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('تواصل مع الدعم'),
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
