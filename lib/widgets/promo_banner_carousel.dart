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

  @override
  void initState() {
    super.initState();
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

  Future<void> _open(PromoBanner banner) async {
    final restaurantId = banner.restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;
    final service = context.read<FirebaseService>();
    final restaurant = await service.getRestaurantOnce(restaurantId);
    if (restaurant == null || !mounted) return;
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
        final banners = snap.data ?? [];
        _count = banners.length;
        // حين لا بنرات من الإدارة يظهر البنر الافتراضي المدمج في التطبيق
        // (عرض الطلب الأول) — فلا تفقد الشاشة مساحتها الترويجية أبداً.
        if (banners.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/banner_promo_1.jpg',
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          );
        }

        return Column(children: [
          SizedBox(
            height: 150,
            child: PageView.builder(
              controller: _controller,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) {
                final b = banners[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () => _open(b),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(fit: StackFit.expand, children: [
                        CachedNetworkImage(
                          imageUrl: b.imageUrl,
                          fit: BoxFit.cover,
                          // فكّ الترميز بعرض معقول للبنر لا بحجم الملف الأصلي،
                          // والتخزين على القرص يعرضه فورياً من ثاني فتح.
                          memCacheWidth: 1200,
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
                    ),
                  ),
                );
              },
            ),
          ),
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
