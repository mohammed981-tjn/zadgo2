// lib/screens/customer/account_screen.dart
//
// شاشة «حسابي» للعميل — تجمع ما كان مبعثراً أو غائباً تماماً:
//
// • رصيد المحفظة: كان غير ظاهر للعميل إطلاقاً رغم أن الإدارة تودع فيه مبالغ
//   الاسترداد عند حلّ الشكاوى — أي أن العميل كان يُعوَّض ولا يعلم.
// • العناوين المحفوظة: كان على العميل تحديد موقعه على الخريطة في كل طلب،
//   وهي أكثر خطوة متكرّرة إزعاجاً في مسار الشراء.
// • بيانات الحساب وتسجيل الخروج في مكان متوقَّع بدل أيقونة في شريط علوي.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import '../auth/edit_profile_screen.dart';
import 'my_complaints_screen.dart';
import 'pick_location_screen.dart';
import 'help_center_screen.dart';
import 'customer_referral_screen.dart';
import '../../utils/app_lang.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final uid = auth.user?.uid ?? '';

    if (uid.isEmpty) {
      return AppEmpty(
          emoji: '👤',
          title: tr('سجّل الدخول لعرض حسابك', 'Sign in to view your account'));
    }

    // يُتابَع المستخدم لحظياً حتى يظهر رصيد المحفظة والعناوين محدَّثة فور
    // تغيّرها، لا كما كانت وقت تسجيل الدخول.
    //
    // يُستخدم StreamBuilder مباشرةً لا AppStreamBuilder، لأن الأخير يعتبر
    // القيمة null «لا بيانات بعد» فيبقى معلّقاً على مؤشّر التحميل، بينما null
    // هنا تعني حالة صريحة: مستند المستخدم غير موجود.
    return StreamBuilder<AppUser?>(
      stream: service.streamUser(uid),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return AppEmpty(
              emoji: '⚠️',
              title: tr('تعذّر تحميل بيانات الحساب',
                  'Couldn\'t load account details'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppLoading();
        }
        final user = snap.data;
        if (user == null) {
          return AppEmpty(
              emoji: '👤',
              title: tr('تعذّر تحميل بيانات الحساب',
                  'Couldn\'t load account details'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileCard(user: user),
            const SizedBox(height: 16),
            _WalletCard(balance: user.walletBalance),
            const SizedBox(height: 16),
            _AddressesSection(user: user),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.support_agent_rounded,
                    color: AppColors.primary),
                title: Text(tr('شكاواي', 'My complaints'),
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    tr('متابعة شكاواك والتواصل مع الإدارة',
                        'Track your complaints and talk to support'),
                    style: const TextStyle(fontSize: 12.5)),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyComplaintsScreen(
                        uid: uid, role: UserRole.customer),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading:
                    const Icon(Icons.lock_outline, color: AppColors.primary),
                title: Text(tr('تغيير كلمة المرور', 'Change password'),
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ادعُ أصدقاءك (دفعة ٥): مدخل إحالة العميل — يشارك كوده فيربح
            // الطرفان رصيداً حين ينجز المدعوّ الشرط.
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.card_giftcard_rounded,
                    color: AppColors.primary),
                title: Text(tr('ادعُ أصدقاءك', 'Invite friends'),
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    tr('شارك كودك واربحا معاً', 'Share your code and both earn'),
                    style: const TextStyle(fontSize: 12.5)),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CustomerReferralScreen(user: user)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // تبديل اللغة (دفعة «اللغة الثانية»): عربية ↔ إنجليزية.
            const Card(margin: EdgeInsets.zero, child: LanguageToggleTile()),
            const SizedBox(height: 8),
            // مركز المساعدة (دفعة ٥): مدخلٌ للأسئلة الشائعة قبل التذكرة —
            // يجيب أكثر الأسئلة فوراً ويقلّل ضغط الدعم.
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.help_outline_rounded,
                    color: AppColors.primary),
                title: Text(tr('مركز المساعدة', 'Help center'),
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    tr('أسئلة شائعة وتواصل مع الدعم',
                        'FAQs and contact support'),
                    style: const TextStyle(fontSize: 12.5)),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HelpCenterScreen(user: user)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: tr('حركات المحفظة', 'Wallet transactions')),
            AppStreamBuilder<List<WalletTransaction>>(
              stream: () => service.streamWalletTransactions(uid),
              builder: (c, txs) {
                if (txs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        tr('لا توجد حركات على محفظتك بعد',
                            'No wallet activity yet'),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textGray)),
                  );
                }
                // ت٤٦: عدّاد ما كسبه العميل من الكاش باك — برنامج ولاءٍ
                // لا يراه صاحبه مصروفٌ بلا عائد تسويقي.
                final cashbackTotal = txs
                    .where((t) => t.type == WalletTransactionType.cashback)
                    .fold(0.0, (s, t) => s + t.amount);
                return Column(children: [
                  if (cashbackTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.savings_outlined,
                            size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(
                            tr('كسبتَ من الكاش باك حتى الآن: ${formatCurrency(cashbackTotal)}',
                                'Cashback earned so far: ${formatCurrency(cashbackTotal)}'),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ]),
                    ),
                  ...txs.map((t) => _WalletTile(tx: t)),
                ]);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 18),
                label: Text(tr('تسجيل الخروج', 'Log out')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: () async {
                  final ok = await showConfirmDialog(context,
                      title: tr('تسجيل الخروج', 'Log out'),
                      content: tr('هل تريد تسجيل الخروج من حسابك؟',
                          'Do you want to log out of your account?'),
                      confirmLabel: tr('خروج', 'Log out'),
                      confirmColor: AppColors.error);
                  if (ok != true || !context.mounted) return;
                  await context.read<app_auth.AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            // حذف الحساب داخل التطبيق (هـ٤) — تلزم به قاعدة آبل 5.1.1(v)
            // وسياسة Google Play قبل النشر. إخفاء هوية لا حذف سجلّ:
            // الدفاتر المالية تبقى باسم «مستخدم محذوف».
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.delete_forever_outlined,
                    size: 17, color: AppColors.textGray),
                label: Text(tr('حذف الحساب نهائياً', 'Delete account permanently'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textGray)),
                onPressed: () => _deleteAccount(context),
              ),
            ),
          ],
        );
      },
    );
  }
  /// حوار حذف الحساب: شرح صريح لما يبقى وما يُمحى + كلمة المرور لإعادة
  /// المصادقة (يشترطها Firebase لحذف الحساب) — ثم خروج نهائي لشاشة الدخول.
  Future<void> _deleteAccount(BuildContext context) async {
    final pwCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('حذف الحساب نهائياً', 'Delete account permanently')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            tr(
                'سيُحذف حساب دخولك وتُمحى بياناتك التعريفية (الاسم والجوال '
                'والبريد) نهائياً ولا يمكن التراجع. سجلّ الطلبات والحركات '
                'المالية يبقى محفوظاً باسم «مستخدم محذوف» كما تُلزمنا الأنظمة '
                'المحاسبية.\n\nأدخل كلمة مرورك للتأكيد:',
                'Your login account will be deleted and your personal details '
                '(name, phone, email) permanently erased — this can\'t be '
                'undone. Order and financial records remain stored under '
                '"Deleted user" as accounting regulations require us.\n\n'
                'Enter your password to confirm:'),
            style: const TextStyle(fontSize: 13.5, height: 1.7),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: pwCtrl,
            obscureText: true,
            decoration: InputDecoration(labelText: tr('كلمة المرور', 'Password')),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('تراجع', 'Cancel'))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('احذف حسابي', 'Delete my account'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context
          .read<FirebaseService>()
          .deleteMyAccount(password: pwCtrl.text);
      if (!context.mounted) return;
      await context.read<app_auth.AuthProvider>().logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      }
    } catch (_) {
      if (context.mounted) {
        showError(
            context,
            tr('تعذّر الحذف — تأكد من كلمة المرور واتصالك بالإنترنت',
                'Couldn\'t delete — check your password and internet connection'));
      }
    }
  }

}

class _ProfileCard extends StatelessWidget {
  final AppUser user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text(
              user.name.trim().isEmpty
                  ? tr('؟', '?')
                  : user.name.trim().substring(0, 1),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
                if (user.phone.isNotEmpty)
                  Text(user.phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.textGray)),
                if (user.email.isNotEmpty)
                  Text(user.email,
                      textDirection: TextDirection.ltr,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textGray)),
              ],
            ),
          ),
          // تعديل الاسم والجوال — البطاقة كانت عرضاً فقط (ملاحظة المالك).
          IconButton(
            tooltip: tr('تعديل الملف الشخصي', 'Edit profile'),
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
        ]),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final double balance;
  const _WalletCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(16),
      ),
      // النصّ كحليّ داكن على تدرّج ذهبي — الأبيض على الذهبي يعطي تبايناً ~١٫٨:١
      // (أقل من عتبة WCAG AA) فيصعب قراءة الرصيد؛ الكحليّ يرفعه فوق ٨:١.
      child: Row(children: [
        const Icon(Icons.account_balance_wallet_rounded,
            color: AppColors.dark, size: 34),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('رصيد المحفظة', 'Wallet balance'),
                style: TextStyle(
                    color: AppColors.dark.withOpacity(0.75), fontSize: 13.5)),
            Text(formatCurrency(balance),
                style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ]),
    );
  }
}

class _AddressesSection extends StatelessWidget {
  final AppUser user;
  const _AddressesSection({required this.user});

  Future<void> _addAddress(BuildContext context) async {
    final labelCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    // ت٤٨: الوحدة والتعليمات الدائمة و«اتركه عند الباب» — في حيٍّ بلا
    // أرقام مبانٍ كان الكابتن يتصل في كل طلب يسأل نفس الأسئلة.
    final unitCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var leaveAtDoor = false;
    LatLng? picked;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: Text(tr('عنوان جديد', 'New address')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(
                    labelText: tr('الاسم', 'Name'),
                    hintText: tr('المنزل، العمل...', 'Home, work...')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addrCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: tr('العنوان بالتفصيل', 'Full address')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitCtrl,
                decoration: InputDecoration(
                    labelText: tr('المبنى / الدور / الشقة (اختياري)',
                        'Building / floor / apartment (optional)'),
                    hintText: tr('عمارة الياسمين، الدور ٣، شقة ٥',
                        'Yasmin bldg, 3rd floor, apt 5')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: tr('تعليمات دائمة للكابتن (اختياري)',
                        'Standing instructions for the captain (optional)'),
                    hintText: tr('ادخل من البوابة الشرقية، اسأل الحارس',
                        'Use the east gate, ask the guard')),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: leaveAtDoor,
                onChanged: (v) => setDialogState(() => leaveAtDoor = v),
                title: Text(tr('اتركه عند الباب', 'Leave at the door'),
                    style: const TextStyle(fontSize: 13.5)),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: Icon(picked != null ? Icons.check_circle : Icons.map_outlined,
                    color: picked != null ? AppColors.success : null),
                label: Text(picked != null
                    ? tr('الموقع محدد ✓', 'Location set ✓')
                    : tr('حدد الموقع على الخريطة', 'Set location on the map')),
                onPressed: () async {
                  final r = await Navigator.push<LatLng>(
                    ctx2,
                    MaterialPageRoute(
                        builder: (_) => PickLocationScreen(initialLocation: picked)),
                  );
                  if (r != null) setDialogState(() => picked = r);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('إلغاء', 'Cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('حفظ', 'Save'))),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) {
      labelCtrl.dispose();
      addrCtrl.dispose();
      unitCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final label = labelCtrl.text.trim();
    final address = addrCtrl.text.trim();
    if (label.isEmpty || address.isEmpty) {
      showError(
          context,
          tr('أدخل اسم العنوان وتفاصيله',
              'Enter the address name and details'));
      return;
    }
    if (picked == null) {
      // بلا إحداثيات لا يمكن حساب أجرة التوصيل، فالعنوان يصبح بلا فائدة عند
      // الطلب — يُمنع الحفظ الآن بدل مفاجأة العميل لاحقاً عند الدفع.
      showError(context,
          tr('حدد الموقع على الخريطة أولاً', 'Set the location on the map first'));
      return;
    }

    final updated = [
      ...user.savedAddresses,
      SavedAddress(
          label: label,
          address: address,
          lat: picked!.latitude,
          lng: picked!.longitude,
          unit: unitCtrl.text.trim(),
          notes: notesCtrl.text.trim(),
          leaveAtDoor: leaveAtDoor),
    ];
    try {
      await context
          .read<FirebaseService>()
          .updateSavedAddresses(user.uid, updated);
      if (context.mounted) {
        showSuccess(context, tr('تم حفظ العنوان', 'Address saved'));
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر حفظ العنوان', 'Couldn\'t save the address'));
      }
    }
  }

  Future<void> _remove(BuildContext context, int index) async {
    final updated = [...user.savedAddresses]..removeAt(index);
    try {
      await context
          .read<FirebaseService>()
          .updateSavedAddresses(user.uid, updated);
    } catch (_) {
      if (context.mounted) {
        showError(
            context, tr('تعذّر حذف العنوان', 'Couldn\'t delete the address'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = user.savedAddresses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: SectionHeader(title: tr('عناويني', 'My addresses'))),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr('إضافة', 'Add')),
            onPressed: () => _addAddress(context),
          ),
        ]),
        if (addresses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              tr(
                  'لا توجد عناوين محفوظة. أضف عنوانك لتختاره بنقرة عند الطلب بدل '
                  'تحديد الموقع في كل مرة.',
                  'No saved addresses. Add yours to pick it in one tap at '
                  'checkout instead of setting the location every time.'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
            ),
          )
        else
          ...addresses.asMap().entries.map((e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.place_outlined,
                      color: AppColors.primary),
                  title: Text(e.value.label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(e.value.address,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error, size: 20),
                    onPressed: () => _remove(context, e.key),
                  ),
                ),
              )),
      ],
    );
  }
}


/// سطر حركة في سجلّ محفظة العميل — يوضّح سبب كل تغيّر في الرصيد بدل رقم
/// يتبدّل بلا تفسير.
class _WalletTile extends StatelessWidget {
  final WalletTransaction tx;
  const _WalletTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount >= 0;
    final color = positive ? AppColors.success : AppColors.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(tx.type.icon, size: 16, color: color),
        ),
        title: Text(tx.type.label, style: const TextStyle(fontSize: 13.5)),
        subtitle: Text(
          [
            if (tx.orderNumber != null)
              tr('طلب #${tx.orderNumber}', 'Order #${tx.orderNumber}'),
            if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
            '${tx.createdAt.day}/${tx.createdAt.month}',
          ].join(' • '),
          style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
        ),
        trailing: Text(
          '${positive ? '+' : '−'}${formatCurrency(tx.amount.abs())}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13.5),
        ),
      ),
    );
  }
}
