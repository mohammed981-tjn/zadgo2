// lib/screens/auth/application_gate_screen.dart
//
// بوابة المتقدّمين الجدد — نكهتا الكابتن والمطعم (نمط أوبر وتطبيقات
// التوصيل الكبرى): حساب جديد ← نموذج التقديم بالمستندات ← شاشة «بانتظار
// الاعتماد» ← يعتمد المديرُ من تطبيقه فتنقلب هذه الشاشة **وحدها** إلى
// الواجهة الكاملة، بلا كود تسجيل ولا إعادة دخول.
//
// مفتاح الفتح هو **دور الحساب** لا حالة الطلب: البوابة تبثّ مستند
// المستخدم، ولحظة أن يكتب الاعتمادُ دورَ «سائق/مدير مطعم» فيه تنتقل.
// حالة الطلب تُبثّ بالتوازي لعرض الرفض بسببه وإتاحة إعادة التقديم.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_flavor.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/app_lang.dart';
import 'driver_apply_form.dart';
import 'restaurant_apply_form.dart';

class ApplicationGateScreen extends StatefulWidget {
  const ApplicationGateScreen({super.key});

  @override
  State<ApplicationGateScreen> createState() => _ApplicationGateScreenState();
}

class _ApplicationGateScreenState extends State<ApplicationGateScreen> {
  bool _unlocking = false;
  bool _reapplying = false;

  bool get _isDriverFlavor => AppFlavorConfig.flavor == AppFlavor.driver;

  /// الدور الذي ينتظره المتقدّم في هذه النكهة.
  UserRole get _targetRole =>
      _isDriverFlavor ? UserRole.driver : UserRole.restaurantManager;

  Future<void> _unlock(FirebaseService service,
      DriverApplication? driverApp) async {
    if (_unlocking) return;
    _unlocking = true;
    final auth = context.read<app_auth.AuthProvider>();
    try {
      // مستند السائق يُنشئه جهازُه هو (القاعدة تفرض أرصدة صفرية وتمنع
      // حتى المدير من إنشائه بالنيابة) — من بيانات طلبه المعتمَد.
      if (_isDriverFlavor && driverApp != null) {
        await service.ensureDriverDocFromApplication(driverApp);
      }
      await auth.reloadUser();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => AppFlavorConfig.buildHomeForRole(_targetRole)),
        (_) => false,
      );
    } catch (_) {
      // فشل عابر (شبكة): يُعاد فتح القفل ليحاول البثّ التالي من جديد.
      _unlocking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final auth = context.watch<app_auth.AuthProvider>();
    final uid = auth.user?.uid;

    // خرج (أو أُخرج) من الحساب: عودة لشاشة الدخول.
    if (uid == null) {
      return AppFlavorConfig.buildLoginScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isDriverFlavor
            ? tr('الانضمام ككابتن', 'Join as a captain')
            : tr('تسجيل مطعمك', 'Register your restaurant')),
        actions: [
          IconButton(
            tooltip: tr('خروج', 'Sign out'),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<app_auth.AuthProvider>().logout(),
          ),
        ],
      ),
      body: StreamBuilder<UserRole?>(
        stream: service.streamOwnRole(uid),
        builder: (ctx, roleSnap) {
          final role = roleSnap.data;
          if (_isDriverFlavor) {
            return StreamBuilder<DriverApplication?>(
              stream: service.streamOwnDriverApplication(uid),
              builder: (c2, appSnap) {
                if (role == _targetRole) {
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _unlock(service, appSnap.data));
                  return const _UnlockingView();
                }
                return _buildByApplication<DriverApplication>(
                  waiting: appSnap.connectionState == ConnectionState.waiting,
                  app: appSnap.data,
                  status: appSnap.data?.status,
                  reviewNote: appSnap.data?.reviewNote ?? '',
                  form: DriverApplyForm(
                    existing: appSnap.data,
                    onSubmitted: () => setState(() => _reapplying = false),
                  ),
                );
              },
            );
          }
          return StreamBuilder<RestaurantApplication?>(
            stream: service.streamOwnRestaurantApplication(uid),
            builder: (c2, appSnap) {
              if (role == _targetRole) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _unlock(service, null));
                return const _UnlockingView();
              }
              return _buildByApplication<RestaurantApplication>(
                waiting: appSnap.connectionState == ConnectionState.waiting,
                app: appSnap.data,
                status: appSnap.data?.status,
                reviewNote: appSnap.data?.reviewNote ?? '',
                form: RestaurantApplyForm(
                  existing: appSnap.data,
                  onSubmitted: () => setState(() => _reapplying = false),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildByApplication<T>({
    required bool waiting,
    required T? app,
    required DriverApplicationStatus? status,
    required String reviewNote,
    required Widget form,
  }) {
    if (waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (app == null || _reapplying) return form;
    switch (status!) {
      case DriverApplicationStatus.pending:
        return _WaitingView(isDriver: _isDriverFlavor);
      case DriverApplicationStatus.approved:
        // الطلب اعتُمد والدور في طريقه (ترتيب الكتابة يجعل الدور يسبق
        // عادةً؛ هذه الحالة تظهر لثوانٍ في أسوأ الأحوال).
        return const _UnlockingView();
      case DriverApplicationStatus.rejected:
        return _RejectedView(
          reason: reviewNote,
          onReapply: () => setState(() => _reapplying = true),
        );
    }
  }
}

/// «وصل طلبك» — تتغيّر وحدها لحظة الاعتماد (بثّ حيّ لا سحبٌ يدوي).
class _WaitingView extends StatelessWidget {
  final bool isDriver;
  const _WaitingView({required this.isDriver});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.hourglass_top_rounded,
              size: 64, color: AppColors.textGray.withOpacity(0.7)),
          const SizedBox(height: 20),
          Text(tr('بانتظار الاعتماد', 'Awaiting approval'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            isDriver
                ? tr(
                    'وصل طلبك. لن تستقبل طلبات توصيل قبل أن تعتمده الإدارة '
                        '— وهذه الشاشة تتغيّر وحدها لحظة اعتماده.',
                    "Your application is in. You won't receive delivery "
                        'requests until the team approves it — this screen '
                        'updates on its own the moment that happens.')
                : tr(
                    'وصل طلبك. لن يظهر مطعمك للعملاء قبل أن تعتمده الإدارة '
                        '— وهذه الشاشة تتغيّر وحدها لحظة اعتماده.',
                    "Your application is in. Your restaurant won't appear to "
                        'customers until the team approves it — this screen '
                        'updates on its own the moment that happens.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textGray),
          ),
        ]),
      ),
    );
  }
}

/// لحظة الاعتماد: تجهيز الحساب ثم الانتقال — تُعرض لثوانٍ.
class _UnlockingView extends StatelessWidget {
  const _UnlockingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
            tr('اعتُمد طلبك ✅ — يُجهَّز حسابك الآن...',
                'Application approved ✅ — setting up your account...'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _RejectedView extends StatelessWidget {
  final String reason;
  final VoidCallback onReapply;
  const _RejectedView({required this.reason, required this.onReapply});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.block_rounded, size: 56, color: AppColors.error),
          const SizedBox(height: 16),
          Text(tr('لم يُقبل طلبك', 'Application not accepted'),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          if (reason.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(tr('السبب: $reason', 'Reason: $reason'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5)),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onReapply,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(tr('عالجت السبب — تقديم من جديد',
                'Issue fixed — apply again')),
          ),
        ]),
      ),
    );
  }
}
