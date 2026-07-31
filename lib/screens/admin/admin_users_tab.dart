// lib/screens/admin/admin_users_tab.dart
//
// إدارة المستخدمين — يتيح للمدير العام إنشاء/تعديل/تعطيل الحسابات،
// وربط حسابات "مدير مطعم" الجديدة بمطعم محدد، والتحكم الكامل في بيانات
// اعتمادها (إعادة تعيين كلمة المرور) بدلاً من ترك ذلك لإدارة المطعم.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        onPressed: () => _showCreateRestaurantManagerDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('مدير مطعم جديد'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: service.streamUsers(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const AppLoading();
          final users = snap.data!;
          if (users.isEmpty) return const AppEmpty(emoji: '👥', title: 'لا يوجد مستخدمون');
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u.isActive
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.grey.shade300,
                    child: Text(u.name.isNotEmpty ? u.name[0] : '?'),
                  ),
                  title: Text(u.name),
                  subtitle: Text(
                    '${u.role.label}${u.restaurantName != null ? " • ${u.restaurantName}" : ""}\n${u.email}',
                  ),
                  isThreeLine: true,
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
                              showSuccess(context,
                                  'تم إرسال رابط إعادة تعيين كلمة المرور إلى ${u.email}');
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
                        const PopupMenuItem(
                            value: 'reset_password', child: Text('إعادة تعيين كلمة المرور')),
                        const PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateRestaurantManagerDialog(BuildContext context) {
    final service = context.read<FirebaseService>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? selectedRestaurantId;
    String? selectedRestaurantName;
    bool loading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: const Text('إنشاء حساب مدير مطعم'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              const SizedBox(height: 10),
              TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
              const SizedBox(height: 10),
              TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف')),
              const SizedBox(height: 10),
              TextField(
                  controller: passCtrl,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'كلمة المرور')),
              const SizedBox(height: 14),
              StreamBuilder<List<Restaurant>>(
                stream: service.streamRestaurants(),
                builder: (ctx, rSnap) {
                  final restaurants = rSnap.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: selectedRestaurantId,
                    decoration: const InputDecoration(labelText: 'المطعم المرتبط'),
                    items: restaurants
                        .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                        .toList(),
                    onChanged: (v) {
                      selectedRestaurantId = v;
                      selectedRestaurantName =
                          restaurants.firstWhere((r) => r.id == v).name;
                    },
                  );
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          validateEmail(emailCtrl.text) != null ||
                          passCtrl.text.trim().length < 6 ||
                          selectedRestaurantId == null) {
                        showError(dialogCtx, 'يرجى تعبئة كل الحقول واختيار مطعم صحيح');
                        return;
                      }
                      setState(() => loading = true);
                      try {
                        await service.createManagedUser(
                          name: nameCtrl.text,
                          email: emailCtrl.text,
                          password: passCtrl.text,
                          phone: phoneCtrl.text,
                          role: UserRole.restaurantManager,
                          restaurantId: selectedRestaurantId,
                          restaurantName: selectedRestaurantName,
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      } catch (e) {
                        setState(() => loading = false);
                        if (dialogCtx.mounted) showError(dialogCtx, 'تعذر إنشاء الحساب: $e');
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }
}
