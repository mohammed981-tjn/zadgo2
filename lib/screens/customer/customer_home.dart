import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animations/animations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/cart_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/food_visuals.dart';
import '../../widgets/promo_banner_carousel.dart';
import '../../widgets/app_skeletons.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import 'restaurant_detail_screen.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'account_screen.dart';

/// عتبة عدد الطلبات المُنجزة التي تُظهر شارة "الأكثر طلباً" على بطاقة
/// المطعم — لا تتطلب حقلاً إضافياً في البيانات، تُحسب من [Restaurant.totalOrders].
const int _popularOrdersThreshold = 50;

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final cart = context.watch<CartProvider>();
    // الزائر (غير مسجَّل الدخول) يتصفح المطاعم بحرية؛ التسجيل يُطلب فقط عند
    // تأكيد الطلب أو فتح "طلباتي".
    final isGuest = !auth.isLoggedIn;
    return Scaffold(
      appBar: AppBar(
        title: Text(isGuest ? 'مرحباً بك في ZadGo' : 'مرحباً ${auth.user?.name ?? ""}'),
        actions: [
          badges.Badge(showBadge: cart.itemCount > 0,
            badgeContent: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10.5)),
            child: IconButton(icon: PhosphorIcon(PhosphorIcons.shoppingCartSimple()),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())))),
          if (isGuest)
            TextButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('تسجيل الدخول'),
            )
          else
            IconButton(icon: PhosphorIcon(PhosphorIcons.signOut()), onPressed: () async {
              await auth.logout();
              if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }),
        ],
      ),
      body: Column(children: [
        // شريط الرسائل الجماعية: فشله لا يجب أن يعطّل الشاشة كلها، لذلك
        // يُخفى بصمت عند الخطأ بدل عرض رسالة خطأ للعميل.
        StreamBuilder<List<BroadcastMessage>>(
          stream: context.read<FirebaseService>().streamBroadcasts(BroadcastAudience.customers),
          builder: (ctx, snap) {
            if (snap.hasError) {
              debugPrint('BroadcastBanner error: ${snap.error}');
              return const SizedBox.shrink();
            }
            final list = snap.data;
            if (list == null || list.isEmpty) return const SizedBox.shrink();
            final latest = list.first;
            return BroadcastBanner(title: latest.title, body: latest.body);
          },
        ),
        Expanded(
          child: IndexedStack(index: _tab, children: [
            const _RestaurantsPage(),
            isGuest ? const _GuestOrdersPrompt() : const MyOrdersScreen(),
            isGuest ? const _GuestOrdersPrompt() : const AccountScreen(),
          ]),
        ),
      ]),
      // أيقونات Phosphor (ز5) في شريط تنقّل العميل: المحدَّد duotone
      // (ممتلئ جزئياً) وغيره regular — تمييزٌ بالامتلاء يبقى واضحاً حتى
      // لعمى الألوان، والطابع مختلف عن أيقونات كل تطبيق أندرويد.
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: PhosphorIcon(PhosphorIcons.storefront()),
              selectedIcon:
                  PhosphorIcon(PhosphorIcons.storefront(PhosphorIconsStyle.duotone)),
              label: 'المطاعم'),
          NavigationDestination(
              icon: PhosphorIcon(PhosphorIcons.receipt()),
              selectedIcon:
                  PhosphorIcon(PhosphorIcons.receipt(PhosphorIconsStyle.duotone)),
              label: 'طلباتي'),
          NavigationDestination(
              icon: PhosphorIcon(PhosphorIcons.user()),
              selectedIcon:
                  PhosphorIcon(PhosphorIcons.user(PhosphorIconsStyle.duotone)),
              label: 'حسابي'),
        ]),
    );
  }
}

/// دعوة للتسجيل بدل رسالة خطأ حين يحاول زائر (غير مسجَّل) فتح "طلباتي".
class _GuestOrdersPrompt extends StatelessWidget {
  const _GuestOrdersPrompt();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PhosphorIcon(PhosphorIcons.receipt(), size: 64, color: AppColors.textGray),
            const SizedBox(height: 16),
            const Text('سجّل حسابك لمتابعة طلباتك',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('يمكنك تصفح المطاعم بحرية، وتحتاج حساباً فقط لمتابعة طلباتك',
                style: TextStyle(color: AppColors.textGray), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('تسجيل الدخول / إنشاء حساب'),
            ),
          ]),
        ),
      );
}

class _RestaurantsPage extends StatefulWidget {
  const _RestaurantsPage();
  @override
  State<_RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<_RestaurantsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'الكل';

  /// مهلة تهدئة للبحث: بدونها كان كل حرف يُعيد بناء كل بطاقات القائمة
  /// فوراً — تقطيع محسوس على القوائم الكبيرة والأجهزة الضعيفة.
  Timer? _searchDebounce;

  // قائمة الفئات ثابتة في الكود (لا تُقرأ من Firestore)، لذلك تظهر دائماً
  // حتى لو فشل جلب المطاعم.
  static const _categories = ['الكل', 'مشاوي', 'برجر', 'بيتزا', 'مشروبات', 'حلويات'];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v);
    });
  }

  /// تصفية محلية (على الجهاز) حسب الفئة المختارة ونص البحث — لا استعلام
  /// إضافي على Firestore.
  List<Restaurant> _filter(List<Restaurant> list) {
    var result = list;
    if (_category != 'الكل') {
      result = result.where((r) =>
          r.name.contains(_category) || r.description.contains(_category)).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim();
      result = result.where((r) =>
          r.name.contains(q) || r.branchName.contains(q) ||
          r.description.contains(q) || r.address.contains(q)).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'ابحث عن مطعم أو صنف...',
            prefixIcon: PhosphorIcon(PhosphorIcons.magnifyingGlass(), size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() { _searchCtrl.clear(); _query = ''; }),
                  ),
          ),
        ),
      ),
      SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final cat = _categories[i];
            final selected = cat == _category;
            return ChoiceChip(
              label: Text(cat),
              selected: selected,
              onSelected: (_) => setState(() => _category = cat),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.surface,
            );
          },
        ),
      ),
      const SizedBox(height: 4),
      // البنرات الترويجية — تختفي أثناء البحث حتى لا تزاحم النتائج، وتختفي
      // كلياً حين لا حملة فعّالة.
      if (_query.isEmpty) const PromoBannerCarousel(),
      Expanded(
        // ملاحظة مهمة: AppStreamBuilder يتوقّع دالة تُرجع Stream وليس Stream
        // جاهزاً، لذلك يُمرَّر اسم الدالة بلا أقواس (tear-off). إضافة أقواس
        // هنا تكسر التوقيع.
        child: AppStreamBuilder<List<Restaurant>>(
            stream: service.streamRestaurants,
            loading: const RestaurantListSkeleton(),
            builder: (ctx, list) {
          final filtered = _filter(list);
          if (list.isEmpty) return const AppEmpty(emoji: '🍽️', title: 'لا يوجد مطاعم');
          if (filtered.isEmpty) return const AppEmpty(emoji: '🔍', title: 'لا توجد نتائج مطابقة');
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length, itemBuilder: (_, i) {
            // دخول متعاقب لأول ثماني بطاقات فقط: التتابع بعدها لا يُرى
            // (خارج الشاشة)، وتأخيرُ عنصرٍ في أسفل قائمة طويلة بحساب
            // ترتيبه يجعله يظهر متأخراً بلا سبب مرئي عند القفز إليه.
            final card = _RestaurantCard(restaurant: filtered[i]);
            if (i >= 8) return card;
            return card
                .animate(delay: (55 * i).ms)
                .fadeIn(duration: 260.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, duration: 300.ms, curve: Curves.easeOut);
          });
        }),
      ),
    ]);
  }
}

/// بطاقة مطعم واحد في القائمة — لا تفتح إلا إذا كان المطعم مفتوحاً.
class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  const _RestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final isPopular = r.totalOrders >= _popularOrdersThreshold;
    // تحوّل الحاوية (ز6): البطاقة «تتمدّد» إلى صفحة المطعم بدل قفزة
    // push — الودجت نفسه هو الذي يكبر، فيبقى ذهن المستخدم على الشيء
    // الذي ضغطه. المغلق بلا ظل ولا لون: البطاقة الداخلية (Card بحدّها)
    // هي الشكل، وOpenContainer مجرد غلاف الحركة.
    return OpenContainer(
      closedElevation: 0,
      closedColor: Colors.transparent,
      openColor: Colors.white,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      transitionDuration: const Duration(milliseconds: 380),
      tappable: r.isOpen,
      openBuilder: (_, __) => RestaurantDetailScreen(restaurant: r),
      closedBuilder: (ctx, open) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: r.isOpen ? open : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RestaurantAvatar(name: r.name, imageUrl: r.imageUrl, size: 64),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(r.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                StatusBadge(label: r.isOpen ? 'مفتوح' : 'مغلق', color: r.isOpen ? AppColors.success : Colors.grey),
              ]),
              const SizedBox(height: 2),
              // المسافة/الحي: يميّز بين فرعين لنفس المطعم في حيَّين مختلفين.
              if (r.address.trim().isNotEmpty)
                Row(children: [
                  PhosphorIcon(PhosphorIcons.mapPin(), size: 13, color: AppColors.textGray),
                  const SizedBox(width: 3),
                  Expanded(child: Text(r.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textGray, fontSize: 12.5))),
                ]),
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 4, children: [
                // مطعم بلا تقييمات يُعرض «جديد» بدل 5.0 وهمية، ومع التقييم
                // يظهر عدد المقيّمين لأن 4.6 من 128 أصدق من 5.0 من واحد.
                if (r.isNewlyListed)
                  const _MetaChip(icon: Icons.fiber_new_rounded, label: 'جديد', color: AppColors.secondary)
                else
                  _MetaChip(
                      icon: Icons.star_rounded,
                      label: '${r.rating.toStringAsFixed(1)} (${r.ratingCount})',
                      color: AppColors.warning),
                _MetaChip(icon: Icons.timer_outlined, label: '${r.estimatedTimeMin} د', color: AppColors.textGray),
                _MetaChip(icon: Icons.delivery_dining_outlined,
                    // «توصيل مجاني» كانت كذبة مكلفة: حقل المطعم القديم صفر
                    // بينما التسعير الموحّد يحصّل فعلاً — فيصدم العميل في
                    // الدفع ويفقد الثقة. الصدق أرخص، والرقم شامل الرسم الثابت
                    // (قاعدة المالك: التوصيل المعروض = الأجرة + العمولة).
                    label:
                        'التوصيل من ${(Pricing.baseDeliveryFee + Pricing.fixedDeliveryCommission).toStringAsFixed(0)} ر.س',
                    color: AppColors.textGray),
                if (isPopular)
                  const _MetaChip(icon: Icons.local_fire_department_rounded, label: 'الأكثر طلباً', color: AppColors.primary),
              ]),
            ])),
          ]),
        ),
      ),
    ),
    );
  }
}

/// عنصر معلومة صغير (تقييم/وقت/رسوم) داخل بطاقة المطعم.
class _MetaChip extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
      ]);
}