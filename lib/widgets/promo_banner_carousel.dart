// lib/widgets/promo_banner_carousel.dart
//
// شريط البنرات الترويجية أعلى شاشة مطاعم العميل — النمط المعتمد في تطبيقات
// التوصيل الكبرى: عروض ومطاعم جديدة في مساحة بصرية أولى، تتحكم بها الإدارة
// من تطبيقها لحظياً (تفعيل/إيقاف/ترتيب) دون أي تحديث للتطبيق.
//
// السلوك: تقليب تلقائي كل 5 ثوانٍ مع نقاط مؤشر، وضغطة البنر تفتح صفحة
// المطعم المربوط به إن وُجد. حين لا بنرات فعّالة من الإدارة يظهر البنر
// الافتراضي المدمج (عرض الطلب الأول) بدل اختفاء الشريط.
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/firebase_service.dart';
import '../utils/app_lang.dart';
import '../utils/helpers.dart';
import '../utils/theme.dart';
import '../screens/customer/restaurant_detail_screen.dart';

class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final PageController _controller = PageController();
  Timer? _autoSlide;
  int _current = 0;
  int _count = 0;

  /// ت٢٨: انطباعٌ واحد لكل بنر في الجلسة — لا عدّ مكرّر مع كل تقليب.
  final Set<String> _impressed = {};

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlide?.cancel();
    _autoSlide = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _count < 2 || !_controller.hasClients) return;
      final next = (_current + 1) % _count;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _autoSlide?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _recordImpression(PromoBanner b) {
    if (!_impressed.add(b.id)) return;
    context.read<FirebaseService>().recordBannerImpression(b.id);
  }

  Future<void> _open(PromoBanner banner) async {
    final restaurantId = banner.restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;
    final service = context.read<FirebaseService>();
    // ت٢٨: النقرة تُقاس قبل الجلب — نقرةُ مطعمٍ حُذف نقرةٌ حقيقية أيضاً.
    service.recordBannerClick(banner.id);
    final restaurant = await service.getRestaurantOnce(restaurantId);
    if (!mounted) return;
    if (restaurant == null) {
      // ت٢٥: البنر المشير لمطعمٍ محذوف كان يصمت — ضغطةٌ بلا نتيجة توحي
      // بعطل. رسالة صادقة أفضل من صمت.
      showError(context,
          tr('هذا العرض لم يعد متاحاً', 'This offer is no longer available'));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: restaurant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<PromoBanner>>(
      stream: service.streamActiveBanners(),
      builder: (context, snap) {
        // فلترة النافذة الزمنية (دفعة «الإعلانات الذكية»): البثّ يفلتر
        // isActive فقط، وهنا نُسقط المجدول مستقبلاً والمنتهي — فلا يظهر
        // إعلانٌ خارج مدّته (شكوى المالك «الإعلان يستمر بلا نهاية»).
        final now = DateTime.now();
        final banners =
            (snap.data ?? []).where((b) => b.isLiveAt(now)).toList();
        _count = banners.length;
        // حين لا بنرات فعّالة الآن يظهر البنر الافتراضي المدمج — **إلا إن
        // أطفأه المدير** من لوحته (تحكّم كامل: قد يريد شاشةً بلا إعلان).
        if (banners.isEmpty) {
          return StreamBuilder<bool>(
            stream: service.streamShowDefaultBanner(),
            builder: (ctx, s) => s.data == false
                ? const SizedBox.shrink()
                : const _DefaultPromoBanner(),
          );
        }

        // ت٢٨: انطباع البنر الأول يُسجَّل مع أول بناء — onPageChanged لا
        // يُستدعى للصفحة الافتتاحية.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && banners.isNotEmpty) _recordImpression(banners[0]);
        });

        return Column(children: [
          // ت٢٣: ارتفاع الصندوق مشتقّ من عرضه بنسبة ٢٫٤:١ — نفس النسبة
          // التي توصي بها شاشة البنرات حرفياً، فلا يُقصّ من الصورة ٩-١٨٪
          // على الشاشات العريضة ويُبتر نصٌّ كُتب داخلها.
          LayoutBuilder(builder: (ctx, constraints) {
            final boxHeight = ((constraints.maxWidth - 32) / 2.4)
                .clamp(120.0, 190.0);
            return SizedBox(
              height: boxHeight,
              // ت٢٤: الكاروسيل يتوقف تحت الإصبع — كان يقفز أثناء السحب.
              child: Listener(
                onPointerDown: (_) => _autoSlide?.cancel(),
                onPointerUp: (_) => _startAutoSlide(),
                onPointerCancel: (_) => _startAutoSlide(),
                child: PageView.builder(
                  controller: _controller,
                  itemCount: banners.length,
                  onPageChanged: (i) {
                    setState(() => _current = i);
                    _recordImpression(banners[i]);
                  },
                  itemBuilder: (_, i) {
                    final b = banners[i];
                    final linked = (b.restaurantId ?? '').isNotEmpty;
                    final card = ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(fit: StackFit.expand, children: [
                        CachedNetworkImage(
                          imageUrl: b.imageUrl,
                          fit: BoxFit.cover,
                          // ت٢٧: فكّ الترميز بعرض الصندوق الفعلي بالبكسل
                          // لا برقمٍ ثابت — كان 1200 لصندوقٍ عرضه ~600
                          // بكسل: أربعة أضعاف الذاكرة لكل بنر معروض.
                          memCacheWidth: ((constraints.maxWidth - 32) *
                                  MediaQuery.of(ctx).devicePixelRatio)
                              .round(),
                          // بديل هادئ عند فشل التحميل بدل أيقونة كسر قبيحة.
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.primary.withOpacity(0.1),
                            alignment: Alignment.center,
                            child: const Icon(Icons.local_offer_outlined,
                                color: AppColors.primary, size: 34),
                          ),
                          placeholder: (_, __) =>
                              Container(color: AppColors.surface),
                        ),
                        // ت٢٩ (قرار المالك 2026-08-22): وسم «إعلان» على كل
                        // بنر إداري — شفافية أن ما يتصدّر شاشةً مرتّبة
                        // بالتقييم والقرب مساحةٌ مدفوعة/موجَّهة لا ترتيب.
                        PositionedDirectional(
                          top: 8,
                          start: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(tr('إعلان', 'Ad'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        if (b.title.trim().isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.65),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Text(
                                b.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ]),
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // ت٢٤: عنوانٌ منطوق لقارئ الشاشة — بنرٌ بلا عنوان
                      // كان لا يُنطق منه شيء. وت٢٥: البنر غير المربوط لا
                      // يستقبل ضغطاً أصلاً — لا «ضغطة بلا نتيجة».
                      child: Semantics(
                        label: b.title.trim().isNotEmpty
                            ? tr('إعلان: ${b.title}', 'Ad: ${b.title}')
                            : tr('بنر ترويجي', 'Promotional banner'),
                        button: linked,
                        child: linked
                            ? GestureDetector(
                                onTap: () => _open(b), child: card)
                            : card,
                      ),
                    );
                  },
                ),
              ),
            );
          }),
          if (banners.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (i) {
                  final active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 8),
        ]);
      },
    );
  }
}

/// البنر الافتراضي — يُعرض حين لا حملة فعّالة (وأذِن المدير). أُعيد تصميمه
/// (دفعة «الإعلانات الذكية» 2026-08-20، شكوى المالك «بلا تصميم إبداعي»):
/// بطاقة تدرّجٍ مرسومة بالكود لا صورةٌ ثابتة — أنظف وأخفّ وبلا وعدٍ كاذب
/// (رسالةٌ تعريفية بالخدمة لا خصمٌ لا يسنده كوبون).
class _DefaultPromoBanner extends StatelessWidget {
  const _DefaultPromoBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.primary, AppColors.secondary],
          ),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Stack(children: [
          // دائرتان زخرفيتان خفيفتان تكسران السطح المصمت.
          Positioned(
            right: -24,
            top: -24,
            child: CircleAvatar(
                radius: 58, backgroundColor: Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            left: -18,
            bottom: -30,
            child: CircleAvatar(
                radius: 42, backgroundColor: Colors.white.withOpacity(0.06)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        tr('زادقو يوصّلك أشهى المطاعم 🍽️',
                            'ZadGo brings you the tastiest restaurants 🍽️'),
                        maxLines: 2,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.3)),
                    const SizedBox(height: 6),
                    Text(
                        tr('اطلب الآن — ويصلك سريعاً إلى بابك',
                            'Order now — delivered fast to your door'),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delivery_dining_rounded,
                    color: Colors.white, size: 34),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
