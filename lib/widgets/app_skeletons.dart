// lib/widgets/app_skeletons.dart
//
// هياكل تحميل نابضة (Skeleton loaders) — بدل دائرة التحميل المجردة يرى
// المستخدم شكل المحتوى القادم فيُحسّ التطبيق أسرع مما هو (النمط المعتمد في
// كل تطبيقات التوصيل الكبرى). بلا أي حزمة خارجية: نبض شفافية بسيط يكفي
// ولا يضيف اعتمادية قد تكسر البناء.
import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// النابض الأساسي: يُغلّف أي هيكل بنبض شفافية مستمر.
class SkeletonPulse extends StatefulWidget {
  final Widget child;
  const SkeletonPulse({super.key, required this.child});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: widget.child,
      );
}

/// صندوق هيكلي واحد بزوايا مستديرة.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.textGray.withOpacity(0.16),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// هيكل قائمة المطاعم: بطاقات بصورة وسطرين — يطابق تخطيط البطاقة الحقيقية
/// فلا «يقفز» المحتوى عند وصوله.
class RestaurantListSkeleton extends StatelessWidget {
  const RestaurantListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonPulse(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          itemBuilder: (_, __) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const SkeletonBox(width: 64, height: 64, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 140, height: 15),
                      SizedBox(height: 8),
                      SkeletonBox(width: 200, height: 11),
                      SizedBox(height: 6),
                      SkeletonBox(width: 90, height: 11),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// هيكل قائمة الطلبات/الحركات: بطاقات بثلاثة أسطر.
class ListCardsSkeleton extends StatelessWidget {
  final int count;
  const ListCardsSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) => SkeletonPulse(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (_, __) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    SkeletonBox(width: 70, height: 14),
                    Spacer(),
                    SkeletonBox(width: 64, height: 20, radius: 999),
                  ]),
                  const SizedBox(height: 10),
                  const SkeletonBox(width: 180, height: 12),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 120, height: 12),
                ],
              ),
            ),
          ),
        ),
      );
}
