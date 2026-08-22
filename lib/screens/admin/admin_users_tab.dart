// lib/screens/admin/admin_users_tab.dart
//
// إدارة المستخدمين — يتيح للمدير العام إدارة الحسابات (تفعيل/تعطيل/حذف/
// إعادة تعيين كلمة المرور)، وتقييد إنشاء حسابات "مدير عام" و"سائق" و"مدير
// مطعم" الجديدة عبر توليد كود تسجيل وحيد الاستخدام لكل دور (ومرتبط بمطعم
// محدد لحالة مدير المطعم)، يُرسله المدير العام يدوياً (واتساب) للشخص
// المستهدف، الذي يستخدمه بدوره للتسجيل الذاتي.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminUsersTab extends StatelessWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenerateRegistrationCodeDialog(context),
        icon: const Icon(Icons.vpn_key_outlined),
        label: Text(tr('توليد كود تسجيل', 'Generate registration code')),
      ),
      body: AppStreamBuilder<List<AppUser>>(
        stream: service.streamUsers,
        builder: (ctx, users) {
          if (users.isEmpty) {
            return AppEmpty(emoji: '👥', title: tr('لا يوجد مستخدمون', 'No users'));
          }
          // ✅ تجميع المستخدمين في قوائم منسدلة قابلة للطي حسب الدور بدل قائمة
          // طويلة مسطّحة، لتوفير المساحة وتسهيل تصفّح عدد كبير من الحسابات.
          const order = [
            UserRole.admin,
            UserRole.support,
            UserRole.fleetOperator,
            UserRole.restaurantManager,
            UserRole.driver,
            UserRole.customer,
          ];
          final grouped = <UserRole, List<AppUser>>{
            for (final r in order) r: users.where((u) => u.role == r).toList(),
          };
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final role in order)
                if (grouped[role]!.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: Icon(_roleIcon(role), color: AppColors.primary),
                      title: Text('${role.label} (${grouped[role]!.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      childrenPadding: const EdgeInsets.only(bottom: 4),
                      children: grouped[role]!
                          .map((u) => _UserTile(user: u, service: service))
                          .toList(),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  IconData _roleIcon(UserRole role) => switch (role) {
        UserRole.admin => Icons.admin_panel_settings_outlined,
        UserRole.restaurantManager => Icons.storefront_outlined,
        UserRole.driver => Icons.delivery_dining_outlined,
        UserRole.customer => Icons.person_outline,
        UserRole.support => Icons.support_agent_outlined,
        UserRole.fleetOperator => Icons.groups_2_outlined,
      };

  void _showGenerateRegistrationCodeDialog(BuildContext context) {
    final service = context.read<FirebaseService>();
    final phoneCtrl = TextEditingController();
    UserRole selectedRole = UserRole.restaurantManager;
    String? selectedRestaurantId;
    String? selectedRestaurantName;
    bool loading = false;
    RegistrationCode? generated;
    // صلاحية الكود — الافتراضي ٧ أيام: تكفي المرسَل إليه وتمنع بقاء أكواد
    // حيّة منسية للأبد. 0 = بلا انتهاء.
    int validityDays = 7;

    String roleLabel(UserRole r) => switch (r) {
          UserRole.restaurantManager => tr('مدير مطعم', 'Restaurant manager'),
          UserRole.driver => tr('سائق', 'Driver'),
          UserRole.admin => tr('مدير عام', 'Admin'),
          UserRole.customer => tr('عميل', 'Customer'),
          UserRole.support => tr('موظف دعم', 'Support agent'),
          UserRole.fleetOperator => tr('مشغّل الأسطول', 'Fleet operator'),
        };

    // نسخة عربية دائماً لرسالة واتساب: المستلم يقرأ العربية بصرف النظر
    // عن لغة واجهة المدير — الرسالة بيانات مُرسلة لا واجهة.
    String roleLabelAr(UserRole r) => switch (r) {
          UserRole.restaurantManager => 'مدير مطعم',
          UserRole.driver => 'سائق',
          UserRole.admin => 'مدير عام',
          UserRole.customer => 'عميل',
          UserRole.support => 'موظف دعم',
          UserRole.fleetOperator => 'مشغّل الأسطول',
        };

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: Text(tr('توليد كود تسجيل', 'Generate registration code')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (generated == null) ...[
                Text(
                  tr(
                      'اختر الدور، ثم ولّد كود تسجيل وحيد الاستخدام لإرساله للشخص المستهدف؛ '
                      'سيستخدمه لتفعيل حسابه بنفسه بالدور المحدَّد (ومطعمه إن كان مدير مطعم).',
                      'Pick the role, then generate a single-use registration code to send to the target person; '
                      'they use it to activate their own account with that role (and their restaurant if a restaurant manager).'),
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textGray),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: InputDecoration(labelText: tr('الدور', 'Role')),
                  items: [
                    DropdownMenuItem(value: UserRole.restaurantManager, child: Text(tr('مدير مطعم', 'Restaurant manager'))),
                    DropdownMenuItem(value: UserRole.driver, child: Text(tr('سائق', 'Driver'))),
                    DropdownMenuItem(value: UserRole.admin, child: Text(tr('مدير عام', 'Admin'))),
                    // كود «موظف دعم» يفتح لوحة إدارة منكمشة: شكاوى
                    // ومتابعة بلا مالٍ ولا صلاحيات — القيد في القواعد.
                    DropdownMenuItem(value: UserRole.support, child: Text(tr('موظف دعم', 'Support agent'))),
                    // كود «مشغّل الأسطول» يفتح شاشة كباتنه ودفتره فقط —
                    // جهةٌ تأتي بكباتنها وتقتسم أجرة التوصيل (بند القواعد).
                    DropdownMenuItem(
                        value: UserRole.fleetOperator,
                        child: Text(tr('مشغّل الأسطول', 'Fleet operator'))),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      selectedRole = v;
                      selectedRestaurantId = null;
                      selectedRestaurantName = null;
                    });
                  },
                ),
                if (selectedRole == UserRole.restaurantManager) ...[
                  const SizedBox(height: 10),
                  AppStreamBuilder<List<Restaurant>>(
                    stream: service.streamRestaurants,
                    builder: (ctx, allRestaurants) {
                      return AppStreamBuilder<List<AppUser>>(
                        stream: service.streamUsers,
                        builder: (ctx, allUsers) {
                          final linkedRestaurantIds = allUsers
                              .where((u) => u.role == UserRole.restaurantManager && u.restaurantId != null)
                              .map((u) => u.restaurantId)
                              .toSet();
                          final restaurants = allRestaurants
                              .where((r) => !linkedRestaurantIds.contains(r.id))
                              .toList();
                          if (selectedRestaurantId != null &&
                              !restaurants.any((r) => r.id == selectedRestaurantId)) {
                            selectedRestaurantId = null;
                            selectedRestaurantName = null;
                          }
                          if (restaurants.isEmpty) {
                            return Text(
                              tr('لا توجد مطاعم متاحة حالياً — جميع المطاعم مرتبطة بالفعل بمدير مسجَّل.',
                                  'No restaurants available right now — every restaurant is already linked to a registered manager.'),
                              style: const TextStyle(fontSize: 13.5, color: Colors.orange),
                            );
                          }
                          return DropdownButtonFormField<String>(
                            value: selectedRestaurantId,
                            decoration: InputDecoration(
                                labelText: tr('المطعم (غير المرتبط بمدير بعد)',
                                    'Restaurant (not yet linked to a manager)')),
                            items: restaurants
                                .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                selectedRestaurantId = v;
                                selectedRestaurantName = restaurants.firstWhere((r) => r.id == v).name;
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: validityDays,
                  decoration: InputDecoration(
                      labelText: tr('صلاحية الكود', 'Code validity')),
                  items: [
                    DropdownMenuItem(value: 1, child: Text(tr('٢٤ ساعة', '24 hours'))),
                    DropdownMenuItem(value: 7, child: Text(tr('٧ أيام', '7 days'))),
                    DropdownMenuItem(value: 30, child: Text(tr('٣٠ يوماً', '30 days'))),
                    DropdownMenuItem(value: 0, child: Text(tr('بلا انتهاء', 'No expiry'))),
                  ],
                  onChanged: (v) => setState(() => validityDays = v ?? 7),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: tr('رقم واتساب المستلم (اختياري)',
                        'Recipient WhatsApp number (optional)'),
                    hintText: tr('مثال: 9665xxxxxxxx', 'Example: 9665xxxxxxxx'),
                  ),
                ),
              ] else ...[
                Text(tr(
                    'تم توليد كود بدور "${roleLabel(generated!.role)}"'
                        '${generated!.restaurantName.isNotEmpty ? " لمطعم \"${generated!.restaurantName}\"" : ""}',
                    'Generated a "${roleLabel(generated!.role)}" code'
                        '${generated!.restaurantName.isNotEmpty ? " for restaurant \"${generated!.restaurantName}\"" : ""}')),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    generated!.code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(tr('نسخ الكود', 'Copy code')),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: generated!.code));
                        if (dialogCtx.mounted) {
                          showSuccess(dialogCtx, tr('تم نسخ الكود', 'Code copied'));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_outlined),
                      label: Text(tr('إرسال واتساب', 'Send via WhatsApp')),
                      onPressed: phoneCtrl.text.trim().isEmpty
                          ? null
                          : () async {
                              final phone = phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
                              final roleText = roleLabelAr(generated!.role);
                              final restaurantText =
                                  generated!.restaurantName.isNotEmpty ? ' لمطعم "${generated!.restaurantName}"' : '';
                              final text = Uri.encodeComponent(
                                  'كود تسجيل حسابك كـ"$roleText"$restaurantText في تطبيق ZadGo هو: '
                                  '${generated!.code}\nافتح التطبيق واختر "لديك كود تسجيل؟ فعّل حسابك" لاستخدامه.');
                              final uri = Uri.parse('https://wa.me/$phone?text=$text');
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(generated == null
                    ? tr('إلغاء', 'Cancel')
                    : tr('إغلاق', 'Close'))),
            if (generated == null)
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (selectedRole == UserRole.restaurantManager && selectedRestaurantId == null) {
                          showError(dialogCtx, tr('يرجى اختيار المطعم أولاً',
                              'Please pick the restaurant first'));
                          return;
                        }
                        setState(() => loading = true);
                        try {
                          final code = await service.generateRegistrationCode(
                            role: selectedRole,
                            restaurantId: selectedRole == UserRole.restaurantManager ? selectedRestaurantId! : '',
                            restaurantName:
                                selectedRole == UserRole.restaurantManager ? selectedRestaurantName! : '',
                            validity: validityDays == 0
                                ? null
                                : Duration(days: validityDays),
                          );
                          setState(() {
                            generated = code;
                            loading = false;
                          });
                        } catch (e) {
                          setState(() => loading = false);
                          if (dialogCtx.mounted) {
                            showError(dialogCtx, tr('تعذر توليد الكود: $e',
                                'Could not generate the code: $e'));
                          }
                        }
                      },
                child: loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr('توليد الكود', 'Generate code')),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  final FirebaseService service;
  const _UserTile({required this.user, required this.service});

  @override
  Widget build(BuildContext context) {
    final u = user;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            u.isActive ? AppColors.primary.withOpacity(0.15) : Colors.grey.shade300,
        child: Text(u.name.isNotEmpty ? u.name[0] : '?'),
      ),
      title: Text(u.name),
      subtitle: Text(
        tr(
            '${u.restaurantName != null ? "${u.restaurantName} • " : ""}${u.email}'
                '${u.nationalId != null && u.nationalId!.isNotEmpty ? "\nرقم الإقامة/الهوية: ${u.nationalId}" : ""}',
            '${u.restaurantName != null ? "${u.restaurantName} • " : ""}${u.email}'
                '${u.nationalId != null && u.nationalId!.isNotEmpty ? "\nNational/residency ID: ${u.nationalId}" : ""}'),
      ),
      isThreeLine: u.nationalId != null && u.nationalId!.isNotEmpty,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        // شارة حظر النقدي (درع النقد): يرفعها الكنس تلقائياً عند تكرار
        // رفض الاستلام — والمدير يرفعها من قائمة النقاط حين يقتنع بالعذر.
        if (u.cashBlocked) ...[
          StatusBadge(label: tr('نقدي محظور 🚫', 'Cash blocked 🚫'), color: AppColors.error),
          const SizedBox(width: 4),
        ],
        StatusBadge(
            label: u.isActive ? tr('مفعّل', 'Active') : tr('معطّل', 'Disabled'),
            color: u.isActive ? AppColors.success : AppColors.error),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'toggle') {
              await service.setUserActive(u.uid, !u.isActive);
            } else if (v == 'cash_unblock') {
              await service.setCashBlocked(u.uid, false);
              if (context.mounted) {
                showSuccess(context,
                    tr('رُفع حظر النقدي عن ${u.name} وصُفّر عدّاد الرفض',
                        'Cash block lifted for ${u.name} and the refusal counter reset'));
              }
            } else if (v == 'reset_password') {
              try {
                await service.sendPasswordReset(u.email);
                if (context.mounted) {
                  showSuccess(
                      context,
                      tr('تم إرسال رابط إعادة تعيين كلمة المرور إلى ${u.email}',
                          'Password reset link sent to ${u.email}'));
                }
              } catch (e) {
                if (context.mounted) {
                  showError(context, tr('تعذر إرسال رابط إعادة التعيين: $e',
                      'Could not send the reset link: $e'));
                }
              }
            } else if (v == 'revoke_role') {
              // إلغاء الصلاحية = تحويل الدور إلى «عميل»: الوصول محروسٌ
              // بحقل الدور في القواعد، فهذا يسحبه فوراً على الخادم.
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(tr('إلغاء الصلاحية', 'Revoke role')),
                  content: Text(
                      tr(
                          'تحويل "${u.name}" من ${u.role.label} إلى عميل عادي؟ '
                          'يفقد صلاحيته فوراً. (يمكن منحه الصلاحية لاحقاً بكود جديد.)',
                          'Turn "${u.name}" from ${u.role.label} into a regular customer? '
                          'They lose their role immediately. (It can be granted again later with a new code.)')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(tr('تراجع', 'Back'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(tr('إلغاء الصلاحية', 'Revoke role'))),
                  ],
                ),
              );
              if (confirm == true) {
                await service.setUserRole(u.uid, UserRole.customer);
                if (context.mounted) {
                  showSuccess(context, tr('أُلغيت صلاحية ${u.name} (صار عميلاً)',
                      '${u.name}\'s role was revoked (now a customer)'));
                }
              }
            } else if (v == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(tr('حذف المستخدم', 'Delete user')),
                  content: Text(tr('هل تريد حذف حساب "${u.name}"؟',
                      'Delete the account of "${u.name}"?')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(tr('إلغاء', 'Cancel'))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(tr('حذف', 'Delete'))),
                  ],
                ),
              );
              if (confirm == true) await service.deleteUserDoc(u.uid);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'toggle',
                child: Text(u.isActive ? tr('تعطيل', 'Disable') : tr('تفعيل', 'Enable'))),
            // إلغاء الصلاحية يظهر للأدوار المحروسة بالحقل (دعم/مشغّل/مدير
            // مطعم) — لا للعميل (لا صلاحية) ولا للمدير (ادّعاء موقّع يُسحب
            // من ورشة Admin claim لا من هنا).
            if (u.role == UserRole.support ||
                u.role == UserRole.fleetOperator ||
                u.role == UserRole.restaurantManager)
              PopupMenuItem(
                  value: 'revoke_role', child: Text(tr('إلغاء الصلاحية', 'Revoke role'))),
            if (u.cashBlocked)
              PopupMenuItem(
                  value: 'cash_unblock',
                  child: Text(tr('رفع حظر الدفع النقدي', 'Lift cash payment block'))),
            PopupMenuItem(
                value: 'reset_password',
                child: Text(tr('إعادة تعيين كلمة المرور', 'Reset password'))),
            PopupMenuItem(value: 'delete', child: Text(tr('حذف', 'Delete'))),
          ],
        ),
      ]),
    );
  }
}
