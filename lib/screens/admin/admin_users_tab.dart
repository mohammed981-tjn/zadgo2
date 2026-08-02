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
        label: const Text('توليد كود تسجيل'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: service.streamUsers(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const AppLoading();
          final users = snap.data!;
          if (users.isEmpty) return const AppEmpty(emoji: '👥', title: 'لا يوجد مستخدمون');
          // ✅ تجميع المستخدمين في قوائم منسدلة قابلة للطي حسب الدور بدل قائمة
          // طويلة مسطّحة، لتوفير المساحة وتسهيل تصفّح عدد كبير من الحسابات.
          const order = [
            UserRole.admin,
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
      };

  void _showGenerateRegistrationCodeDialog(BuildContext context) {
    final service = context.read<FirebaseService>();
    final phoneCtrl = TextEditingController();
    UserRole selectedRole = UserRole.restaurantManager;
    String? selectedRestaurantId;
    String? selectedRestaurantName;
    bool loading = false;
    RegistrationCode? generated;

    String roleLabel(UserRole r) => switch (r) {
          UserRole.restaurantManager => 'مدير مطعم',
          UserRole.driver => 'سائق',
          UserRole.admin => 'مدير عام',
          UserRole.customer => 'عميل',
        };

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: const Text('توليد كود تسجيل'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (generated == null) ...[
                const Text(
                  'اختر الدور، ثم ولّد كود تسجيل وحيد الاستخدام لإرساله للشخص المستهدف؛ '
                  'سيستخدمه لتفعيل حسابه بنفسه بالدور المحدَّد (ومطعمه إن كان مدير مطعم).',
                  style: TextStyle(fontSize: 13, color: AppColors.textGray),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'الدور'),
                  items: const [
                    DropdownMenuItem(value: UserRole.restaurantManager, child: Text('مدير مطعم')),
                    DropdownMenuItem(value: UserRole.driver, child: Text('سائق')),
                    DropdownMenuItem(value: UserRole.admin, child: Text('مدير عام')),
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
                  StreamBuilder<List<Restaurant>>(
                    stream: service.streamRestaurants(),
                    builder: (ctx, rSnap) {
                      return StreamBuilder<List<AppUser>>(
                        stream: service.streamUsers(),
                        builder: (ctx, uSnap) {
                          final allRestaurants = rSnap.data ?? [];
                          final linkedRestaurantIds = (uSnap.data ?? [])
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
                          if (rSnap.hasData && uSnap.hasData && restaurants.isEmpty) {
                            return const Text(
                              'لا توجد مطاعم متاحة حالياً — جميع المطاعم مرتبطة بالفعل بمدير مسجَّل.',
                              style: TextStyle(fontSize: 13, color: Colors.orange),
                            );
                          }
                          return DropdownButtonFormField<String>(
                            value: selectedRestaurantId,
                            decoration: const InputDecoration(labelText: 'المطعم (غير المرتبط بمدير بعد)'),
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
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم واتساب المستلم (اختياري)',
                    hintText: 'مثال: 9665xxxxxxxx',
                  ),
                ),
              ] else ...[
                Text('تم توليد كود بدور "${roleLabel(generated!.role)}"'
                    '${generated!.restaurantName.isNotEmpty ? " لمطعم \"${generated!.restaurantName}\"" : ""}'),
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
                      label: const Text('نسخ الكود'),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: generated!.code));
                        if (dialogCtx.mounted) showSuccess(dialogCtx, 'تم نسخ الكود');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('إرسال واتساب'),
                      onPressed: phoneCtrl.text.trim().isEmpty
                          ? null
                          : () async {
                              final phone = phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
                              final roleText = roleLabel(generated!.role);
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
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(generated == null ? 'إلغاء' : 'إغلاق')),
            if (generated == null)
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (selectedRole == UserRole.restaurantManager && selectedRestaurantId == null) {
                          showError(dialogCtx, 'يرجى اختيار المطعم أولاً');
                          return;
                        }
                        setState(() => loading = true);
                        try {
                          final code = await service.generateRegistrationCode(
                            role: selectedRole,
                            restaurantId: selectedRole == UserRole.restaurantManager ? selectedRestaurantId! : '',
                            restaurantName:
                                selectedRole == UserRole.restaurantManager ? selectedRestaurantName! : '',
                          );
                          setState(() {
                            generated = code;
                            loading = false;
                          });
                        } catch (e) {
                          setState(() => loading = false);
                          if (dialogCtx.mounted) showError(dialogCtx, 'تعذر توليد الكود: $e');
                        }
                      },
                child: loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('توليد الكود'),
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
        '${u.restaurantName != null ? "${u.restaurantName} • " : ""}${u.email}'
        '${u.nationalId != null && u.nationalId!.isNotEmpty ? "\nرقم الإقامة/الهوية: ${u.nationalId}" : ""}',
      ),
      isThreeLine: u.nationalId != null && u.nationalId!.isNotEmpty,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        StatusBadge(
            label: u.isActive ? 'مفعّل' : 'معطّل',
            color: u.isActive ? AppColors.success : Colors.red),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'toggle') {
              await service.setUserActive(u.uid, !u.isActive);
            } else if (v == 'reset_password') {
              try {
                await service.sendPasswordReset(u.email);
                if (context.mounted) {
                  showSuccess(
                      context, 'تم إرسال رابط إعادة تعيين كلمة المرور إلى ${u.email}');
                }
              } catch (e) {
                if (context.mounted) {
                  showError(context, 'تعذر إرسال رابط إعادة التعيين: $e');
                }
              }
            } else if (v == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('حذف المستخدم'),
                  content: Text('هل تريد حذف حساب "${u.name}"؟'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('حذف')),
                  ],
                ),
              );
              if (confirm == true) await service.deleteUserDoc(u.uid);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'toggle', child: Text(u.isActive ? 'تعطيل' : 'تفعيل')),
            const PopupMenuItem(value: 'reset_password', child: Text('إعادة تعيين كلمة المرور')),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ]),
    );
  }
}
