// lib/screens/admin/fleet_operator_home.dart
//
// شاشة مشغّل الأسطول (دفعة «ابدأ المشغل»، roles-design.md §ثانياً): يدخل
// المشغّل تطبيق الإدارة نفسه فتُفتح له **هذه الشاشة وحدها** — كباتنه ودفتره،
// لا شيء غيرها. القيد الحقيقي في قواعد Firestore (يسرد كباتنه بشرط
// operatorId==uid، ولا يرى مالاً غير مستحقّه)؛ وهذه الشاشة واجهته.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

class FleetOperatorHome extends StatelessWidget {
  const FleetOperatorHome({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final uid = auth.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('أسطولي — ${auth.user?.name ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: uid.isEmpty
          ? const AppEmpty(emoji: '👤', title: 'تعذّر تحميل حسابك')
          : StreamBuilder<FleetOperator?>(
              stream: service.streamFleetOperator(uid),
              builder: (ctx, opSnap) {
                final op = opSnap.data;
                return AppStreamBuilder<List<Driver>>(
                  stream: () => service.streamOperatorDrivers(uid),
                  builder: (ctx, drivers) {
                    return _OperatorBody(
                        uid: uid, operator: op, drivers: drivers);
                  },
                );
              },
            ),
    );
  }
}

class _OperatorBody extends StatelessWidget {
  final String uid;
  final FleetOperator? operator;
  final List<Driver> drivers;
  const _OperatorBody(
      {required this.uid, required this.operator, required this.drivers});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // بطاقة الملخّص: الرصيد (المستحق) والنسبة وعدد الكباتن. المستحق
        // المتراكم يُجمع من طلبات كباتنك المسلَّمة (حصّة المشغّل من كلٍّ).
        _SummaryCard(uid: uid, operator: operator, driverCount: drivers.length),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text('كباتنك',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        if (drivers.isEmpty)
          const AppEmpty(
              emoji: '🛵',
              title: 'لا كباتن بعد',
              subtitle: 'يسند المدير كباتنك إليك فيظهرون هنا.')
        else
          ...drivers.map((d) => _DriverCard(driver: d)),
        const SizedBox(height: 24),
        const Center(
          child: Text('مشغّل الأسطول — زاد جو',
              style: TextStyle(fontSize: 11, color: AppColors.textGray)),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String uid;
  final FleetOperator? operator;
  final int driverCount;
  const _SummaryCard(
      {required this.uid, required this.operator, required this.driverCount});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final share = operator?.driverSharePerDelivery ?? 0;
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primary.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // المستحق المتراكم من طلبات الكباتن المسلَّمة (مجموع operatorShare).
          StreamBuilder<List<Order>>(
            stream: service.streamOperatorOrders(uid),
            builder: (ctx, snap) {
              final orders = snap.data ?? const <Order>[];
              final earned = orders.fold<double>(
                  0, (sum, o) => sum + o.operatorShare);
              final ledger = operator?.balance ?? 0;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي مستحقّاتك المتراكمة',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textGray)),
                    const SizedBox(height: 2),
                    Text('${earned.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    if (ledger != 0)
                      Text(
                          ledger > 0
                              ? 'رصيد دفترك: ${ledger.toStringAsFixed(2)} ر.س'
                              : 'صُرف لك: ${(-ledger).toStringAsFixed(2)} ر.س',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textGray)),
                  ]);
            },
          ),
          const Divider(height: 20),
          Row(children: [
            _stat('كباتنك', '$driverCount'),
            const SizedBox(width: 20),
            _stat('حصّة الكابتن/توصيلة',
                share > 0 ? '${share.toStringAsFixed(2)} ر.س' : 'يحدّدها المدير'),
          ]),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textGray)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      );
}

class _DriverCard extends StatelessWidget {
  final Driver driver;
  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final d = driver;
    final statusColor = d.isOnline
        ? AppColors.success
        : (d.isAvailable ? AppColors.warning : AppColors.textGray);
    final statusText = d.isOnline
        ? 'متصل'
        : (d.isAvailable ? 'متاح' : 'غير متاح');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(d.name.isEmpty ? '(بلا اسم)' : d.name,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(statusText,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _chip(Icons.local_shipping_outlined, '${d.totalDeliveries} توصيلة'),
            const SizedBox(width: 10),
            _chip(Icons.star_rounded,
                d.ratingCount <= 0 ? 'جديد' : d.rating.toStringAsFixed(1)),
            const SizedBox(width: 10),
            if (d.warningCount > 0)
              _chip(Icons.warning_amber_rounded, '${d.warningCount} إنذار',
                  color: AppColors.error),
          ]),
          if (d.phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.phone_outlined,
                  size: 13, color: AppColors.textGray),
              const SizedBox(width: 4),
              Text(d.phone,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textDark)),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.textGray),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color ?? AppColors.textDark)),
        ],
      );
}
