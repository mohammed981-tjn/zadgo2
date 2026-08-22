// إحالة العميل (دفعة ٥ — النمو والاحتفاظ): العميل يشارك كوده، فمن يسجّل به
// وينجز شرط الطلبات يُكسب الطرفين رصيداً في محفظتيهما. المعيار العالمي
// (أوبر إيتس/كريم): «ادعُ صديقاً واربحا معاً» — أرخص قناة نموّ وأعلاها ثقة.
//
// كل الأرقام من لوحة المدير (ج١): الشاشة تقرأ الإعدادات الحيّة فلا رقم
// مبرمَج. الصرف بيد المدير (كنس اللوحة) لأن القواعد تمنع العميل من زيادة
// رصيده — العميل هنا يشارك ويتابع فقط.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/app_lang.dart';
import '../../widgets/common_widgets.dart';

class CustomerReferralScreen extends StatelessWidget {
  final AppUser user;
  const CustomerReferralScreen({super.key, required this.user});

  String _shareText(IncentiveSettings s) {
    final reward = s.customerRefereeBonus > 0
        ? tr(' واحصل على ${formatCurrency(s.customerRefereeBonus)} في محفظتك',
            ' and get ${formatCurrency(s.customerRefereeBonus)} in your wallet')
        : '';
    return tr(
        'حمّل تطبيق زاد جو للتوصيل، وسجّل بكود دعوتي «${user.referralCode}»'
            '$reward. 🚀',
        'Download the ZadGo delivery app and sign up with my invite code '
            '"${user.referralCode}"$reward. 🚀');
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('ادعُ أصدقاءك', 'Invite friends'))),
      body: AppStreamBuilder<IncentiveSettings>(
        stream: service.streamIncentiveSettings,
        builder: (ctx, s) {
          final enabled = s.customerReferralEnabled &&
              (s.customerReferrerBonus > 0 || s.customerRefereeBonus > 0);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // بطاقة الكود — كحليّ على ذهبي (اتساق تباين دفعة ٤).
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Icon(Icons.card_giftcard_rounded,
                      color: AppColors.dark, size: 40),
                  const SizedBox(height: 10),
                  Text(tr('كود دعوتك', 'Your invite code'),
                      style: TextStyle(
                          color: AppColors.dark.withOpacity(0.75),
                          fontSize: 13.5)),
                  const SizedBox(height: 4),
                  SelectableText(user.referralCode,
                      style: const TextStyle(
                          color: AppColors.dark,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded,
                        size: 16, color: AppColors.dark),
                    label: Text(tr('نسخ الكود', 'Copy code'),
                        style: const TextStyle(color: AppColors.dark)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.dark.withOpacity(0.4))),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: user.referralCode));
                      if (ctx.mounted) {
                        showSuccess(ctx, tr('نُسخ الكود', 'Code copied'));
                      }
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              if (enabled) ...[
                _StepRow(
                    icon: Icons.share_rounded,
                    text: tr('شارك كودك مع أصدقائك',
                        'Share your code with friends')),
                _StepRow(
                    icon: Icons.person_add_alt_1_rounded,
                    text: tr('يسجّل صديقك ويكتب كودك عند إنشاء حسابه',
                        'Your friend signs up and enters your code')),
                _StepRow(
                    icon: Icons.shopping_bag_rounded,
                    text: s.customerReferralOrders > 0
                        ? tr(
                            'يُكمل ${s.customerReferralOrders} طلباً خلال '
                                '${s.customerReferralWindowDays} يوماً',
                            'They complete ${s.customerReferralOrders} orders '
                                'within ${s.customerReferralWindowDays} days')
                        : tr('يطلب من التطبيق', 'They order from the app')),
                _StepRow(
                    icon: Icons.account_balance_wallet_rounded,
                    text: s.customerReferrerBonus > 0
                        ? tr(
                            'تحصل على ${formatCurrency(s.customerReferrerBonus)} '
                                'في محفظتك، وصديقك على '
                                '${formatCurrency(s.customerRefereeBonus)}',
                            'You get ${formatCurrency(s.customerReferrerBonus)} '
                                'in your wallet, and your friend gets '
                                '${formatCurrency(s.customerRefereeBonus)}')
                        : tr('تحصلان على مكافأة في محفظتيكما',
                            'You both get a wallet reward')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(tr('شارك الكود', 'Share code')),
                    onPressed: () => Share.share(_shareText(s)),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                      tr(
                          'برنامج الدعوة غير مفعّل حالياً — يمكنك مشاركة كودك، '
                          'وسنطلق المكافآت قريباً.',
                          'The referral program isn\'t active yet — you can still '
                          'share your code, and rewards are coming soon.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.textGray)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StepRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.14),
            child: Icon(icon, size: 18, color: AppColors.dark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ),
        ]),
      );
}
