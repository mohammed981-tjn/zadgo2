// lib/widgets/min_version_gate.dart
//
// بوابة الحدّ الأدنى للإصدار: تحجب النسخ الأقدم من الحدّ الذي يضبطه
// المدير في `delivery_settings/app`.
//
// لماذا تلزم: التوزيع بـApp Distribution يعني تعايش نسخ متعددة على
// الأجهزة. وثلاث من دفعاتنا الأخيرة تعتمد على تطابق النسخة مع قواعد
// الأمان (كود التسجيل المختوم، حقول الكوبون، ختوم الحوافز) — فالنسخة
// القديمة لا تكسر نفسها فحسب، بل تصطدم بالقواعد برسائل غامضة. البوابة
// تحوّل ذلك إلى «حدّث تطبيقك» صريحة.
//
// **الفشل مفتوح عمداً**: قبل وصول القيمة، أو عند خطأ قراءة، أو عند حدٍّ
// معطوب — يمرّ المستخدم. خللٌ عابر يجب ألا يُعطّل التطبيق على الجميع.
// وثمن ذلك أن الحجب يتأخّر ثانيةً أو ثانيتين، وهو ثمن مقبول.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/firebase_service.dart';
import '../utils/app_version.dart';
import '../utils/theme.dart';

class MinVersionGate extends StatelessWidget {
  final Widget child;
  const MinVersionGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<String>(
      stream: service.streamMinAppVersion(),
      builder: (context, snap) {
        final minimum = snap.data ?? '';
        if (!isVersionBelow(kAppVersion, minimum)) return child;
        return _BlockedScreen(current: kAppVersion, minimum: minimum);
      },
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  final String current;
  final String minimum;
  const _BlockedScreen({required this.current, required this.minimum});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⬆️', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 20),
                  const Text(
                    'يلزم تحديث التطبيق',
                    style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'هذه النسخة لم تعد مدعومة. حدّث التطبيق لتتمكّن من '
                    'المتابعة — بياناتك محفوظة ولن يضيع منها شيء.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 20),
                  // الرقمان يُعرضان ليصف المستخدم مشكلته للدعم بدقة بدل
                  // «التطبيق ما يشتغل».
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'نسختك $current • المطلوب $minimum فأحدث',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textGray),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
