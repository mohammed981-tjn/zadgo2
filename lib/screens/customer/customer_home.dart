import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animations/animations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../utils/location_guard.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/cart_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/food_visuals.dart';
import '../../utils/reorder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/promo_banner_carousel.dart';
import '../../widgets/app_skeletons.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import 'restaurant_detail_screen.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'account_screen.dart';
import 'suggestion_screen.dart';

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
          // اقتراح/نصيحة — متاح للزائر أيضاً (قناة صوت عامة بلا تسجيل).
          IconButton(
            tooltip: 'اقتراح أو نصيحة',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SuggestionScreen())),
          ),
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

  /// المطبخ المختار من ورقة «المطابخ» (ح8 — نمط كيتا): «الكل» افتراضاً.
  String _cuisine = 'الكل';

  /// الفرز (ح8+ح9 — ورقة كيتا كاملة عدا «الأعلى خصماً» المحفوظة لميزة
  /// عروض المطاعم): الموصى به / الأعلى تقييماً / الأقرب / مدة التوصيل.
  _HomeSort _sort = _HomeSort.recommended;

  /// موقع العميل لفرز «الأقرب» — يُجلب مرة عند أول اختيار له ويُحفظ.
  double? _myLat, _myLng;

  /// عوامل التصفية السريعة (ح9 — نمط كيتا): تُطبَّق معاً (AND).
  bool _fNew = false, _f30min = false, _f45rating = false;
  final Set<int> _fPriceLevels = {};

  /// إعدادات المنصّة (أجرة التوصيل) لعرض «التوصيل من X» بدقّة — من اللوحة
  /// لا رقماً مبرمَجاً. `_settingsLoaded` يميّز «حُمّلت فعلاً» عن الافتراضي:
  /// قراءة `incentives` تشترط تسجيل الدخول، فالزائر كان يرى رقماً افتراضياً
  /// قد يخالف اللوحة ثم يفاجأ عند الدفع — الصدق: لا رقم حتى يُعرف الحقيقي.
  IncentiveSettings _settings = const IncentiveSettings();
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    context.read<FirebaseService>().getIncentiveSettings().then((v) {
      if (mounted) {
        setState(() {
          _settings = v;
          _settingsLoaded = true;
        });
      }
    }).catchError((_) {});
  }

  bool get _hasQuickFilters =>
      _fNew || _f30min || _f45rating || _fPriceLevels.isNotEmpty;

  /// فلتر المفضلة (ح2) — شريحة مستقلة عن الفئات: «مفضلتي من البرجر»
  /// اختياران متقاطعان لا بديلان.
  bool _favoritesOnly = false;

  /// تدفّق مستند المستخدم مثبَّت هنا لا في build: إنشاؤه مع كل إعادة
  /// بناء يعني إعادة اشتراك مع كل حرف بحث — وميضاً واختفاء قلوبٍ لحظياً.
  Stream<AppUser?>? _userStream;
  String? _userStreamUid;

  Stream<AppUser?> _favoritesStream(BuildContext context) {
    final uid = context.read<app_auth.AuthProvider>().user?.uid;
    if (uid != _userStreamUid || _userStream == null) {
      _userStreamUid = uid;
      _userStream = uid == null
          ? Stream<AppUser?>.value(null)
          : context.read<FirebaseService>().streamUser(uid);
    }
    return _userStream!;
  }

  /// مهلة تهدئة للبحث: بدونها كان كل حرف يُعيد بناء كل بطاقات القائمة
  /// فوراً — تقطيع محسوس على القوائم الكبيرة والأجهزة الضعيفة.
  Timer? _searchDebounce;

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
  List<Restaurant> _filter(List<Restaurant> list, Set<String> favorites) {
    var result = list;
    if (_favoritesOnly) {
      result = result.where((r) => favorites.contains(r.id)).toList();
    }
    if (_cuisine != 'الكل') {
      // المطابخ المصنّفة أولاً، وسقوطٌ على مطابقة النص للمطاعم القديمة
      // التي لم تُصنَّف بعد — كي لا تختفي فجأة من فلترٍ كان يجدها بالاسم.
      result = result.where((r) =>
          r.cuisines.contains(_cuisine) ||
          (r.cuisines.isEmpty &&
              (r.name.contains(_cuisine) ||
                  r.description.contains(_cuisine)))).toList();
    }
    if (_query.trim().isNotEmpty) {
      // بحث مطبَّع عربياً (لمسات العميل): «البيك» تجد «البيك» بالهمزة،
      // و«شاورما» تجد «شاورمه» — فلا يُعاقَب مَن لا يضبط الإملاء.
      final q = normalizeArabic(_query);
      result = result.where((r) =>
          normalizeArabic(r.name).contains(q) ||
          normalizeArabic(r.branchName).contains(q) ||
          normalizeArabic(r.description).contains(q) ||
          normalizeArabic(r.address).contains(q)).toList();
    }
    // عوامل التصفية السريعة (ح9) — تُطبَّق معاً:
    if (_fNew) result = result.where((r) => r.isNewlyListed).toList();
    if (_f30min) {
      result = result.where((r) => r.estimatedTimeMin <= 30).toList();
    }
    if (_f45rating) {
      // المطعم الجديد بلا تقييمات لا يُعاقب بفلتر التقييم — يُستثنى منه
      // كما تُعرض له شارة «جديد» بدل رقمٍ موهم.
      result = result
          .where((r) => r.ratingCount == 0 || r.rating >= 4.5)
          .toList();
    }
    if (_fPriceLevels.isNotEmpty) {
      // غير المصنَّف (٠) لا يُستبعد — استبعاده يعاقب مطاعم لم تُصنَّف بعد.
      result = result
          .where((r) =>
              r.priceLevel == 0 || _fPriceLevels.contains(r.priceLevel))
          .toList();
    }
    // الفرز: المفتوح يتصدر دائماً — مطعم مغلق أعلى القائمة إحباط مهما
    // علا تقييمه — ثم معيار الاختيار.
    double dist(Restaurant r) =>
        (r.lat == null || r.lng == null || _myLat == null)
            ? double.infinity
            : haversineDistanceKm(_myLat!, _myLng!, r.lat!, r.lng!);
    result = [...result]..sort((a, b) {
      if (a.isOpenNow != b.isOpenNow) return a.isOpenNow ? -1 : 1;
      switch (_sort) {
        case _HomeSort.nearest:
          return dist(a).compareTo(dist(b));
        case _HomeSort.deliveryTime:
          return a.estimatedTimeMin.compareTo(b.estimatedTimeMin);
        case _HomeSort.rating:
          return b.rating.compareTo(a.rating);
        case _HomeSort.recommended:
          final byRating = b.rating.compareTo(a.rating);
          if (byRating != 0) return byRating;
          return b.totalOrders.compareTo(a.totalOrders);
      }
    });
    return result;
  }

  /// جلب موقع العميل لفرز «الأقرب» — مرة واحدة، وبرفضٍ مُفسَّر لا صامت.
  Future<bool> _ensureMyLocation() async {
    if (_myLat != null) return true;
    try {
      final pos = await LocationGuard.currentPosition();
      _myLat = pos.latitude;
      _myLng = pos.longitude;
      return true;
    } catch (_) {
      if (mounted) {
        showError(context,
            'فرز «الأقرب» يحتاج إذن الموقع — فعّله من إعدادات جهازك');
      }
      return false;
    }
  }

  /// ورقة «المطابخ» بنمط كيتا — قائمة اختيار واحد تتسع لعشرين مطبخاً
  /// لا يتسع لها شريط شرائح.
  Future<void> _showCuisinesSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Center(
                child: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('المطابخ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
            )),
            for (final c in ['الكل', ...kCuisines])
              RadioListTile<String>(
                value: c,
                groupValue: _cuisine,
                dense: true,
                title: Text(c, style: const TextStyle(fontSize: 13.5)),
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _cuisine = picked);
  }

  static const _sortLabels = {
    _HomeSort.recommended: 'الموصى به',
    _HomeSort.rating: 'الأعلى تقييماً',
    _HomeSort.nearest: 'الأقرب',
    _HomeSort.deliveryTime: 'مدة التوصيل',
  };

  /// ورقة «فرز حسب» — ورقة كيتا كاملة عدا «الأعلى خصماً» (محفوظة لميزة
  /// عروض المطاعم بأمر المالك 2026-08-14).
  Future<void> _showSortSheet() async {
    final picked = await showModalBottomSheet<_HomeSort>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('فرز حسب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          ),
          for (final o in _HomeSort.values)
            RadioListTile<_HomeSort>(
              value: o,
              groupValue: _sort,
              dense: true,
              title: Text(_sortLabels[o]!,
                  style: const TextStyle(fontSize: 13.5)),
              subtitle: o == _HomeSort.recommended
                  ? const Text('المفتوح أولاً، ثم التقييم والأكثر طلباً',
                      style: TextStyle(fontSize: 11.5))
                  : null,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == _HomeSort.nearest && !await _ensureMyLocation()) return;
    if (mounted) setState(() => _sort = picked);
  }

  /// ورقة «عوامل التصفية» (ح9 — نمط كيتا): سريعة + السعر، بتطبيقٍ
  /// و«حذف الكل».
  Future<void> _showFiltersSheet() async {
    var fNew = _fNew, f30 = _f30min, f45 = _f45rating;
    final prices = {..._fPriceLevels};
    final applied = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Center(
                  child: Text('عوامل التصفية',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14.5))),
              const SizedBox(height: 10),
              const Text('عوامل تصفية سريعة',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                FilterChip(
                    label: const Text('جديد'),
                    selected: fNew,
                    onSelected: (v) => setSheet(() => fNew = v)),
                FilterChip(
                    label: const Text('خلال ٣٠ دقيقة'),
                    selected: f30,
                    onSelected: (v) => setSheet(() => f30 = v)),
                FilterChip(
                    label: const Text('التقييمات 4.5+'),
                    selected: f45,
                    onSelected: (v) => setSheet(() => f45 = v)),
              ]),
              const SizedBox(height: 12),
              const Text('السعر',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final (lvl, label) in [(1, '\$'), (2, '\$\$'), (3, '\$\$\$')])
                  FilterChip(
                      label: Text(label),
                      selected: prices.contains(lvl),
                      onSelected: (v) => setSheet(
                          () => v ? prices.add(lvl) : prices.remove(lvl))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setSheet(() {
                      fNew = false; f30 = false; f45 = false; prices.clear();
                    }),
                    child: const Text('حذف الكل'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('تطبيق'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        _fNew = fNew; _f30min = f30; _f45rating = f45;
        _fPriceLevels..clear()..addAll(prices);
      });
    }
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
      // شريط التصنيف بنمط كيتا (ح8): المفضلة + ورقتا المطابخ والفرز —
      // عشرون مطبخاً لا يتسع لها شريط شرائح، فتنتقل لورقة سفلية.
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ChoiceChip(
              avatar: Icon(Icons.favorite,
                  size: 16,
                  color: _favoritesOnly ? Colors.white : AppColors.error),
              label: const Text('المفضلة'),
              selected: _favoritesOnly,
              onSelected: (_) =>
                  setState(() => _favoritesOnly = !_favoritesOnly),
              selectedColor: AppColors.error,
              labelStyle: TextStyle(
                color: _favoritesOnly ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.surface,
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: Icon(
                  _cuisine == 'الكل'
                      ? Icons.restaurant_menu_rounded
                      : Icons.check_circle_rounded,
                  size: 16,
                  color: _cuisine == 'الكل'
                      ? AppColors.textDark
                      : AppColors.primary),
              label: Text(_cuisine == 'الكل' ? 'المطابخ ⌄' : '$_cuisine ⌄',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _cuisine == 'الكل'
                          ? AppColors.textDark
                          : AppColors.primary)),
              onPressed: _showCuisinesSheet,
              backgroundColor: AppColors.surface,
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.swap_vert_rounded,
                  size: 16, color: AppColors.textDark),
              label: Text('${_sortLabels[_sort]} ⌄',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onPressed: _showSortSheet,
              backgroundColor: AppColors.surface,
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: Icon(Icons.tune_rounded,
                  size: 16,
                  color: _hasQuickFilters
                      ? AppColors.primary
                      : AppColors.textDark),
              label: Text('تصفية ⌄',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _hasQuickFilters
                          ? AppColors.primary
                          : AppColors.textDark)),
              onPressed: _showFiltersSheet,
              backgroundColor: AppColors.surface,
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      // ملاحظة تخطيط (شكوى المالك 2026-08-20): كان البنر و«اطلب مجدداً»
      // مثبّتَين هنا فوق القائمة، فيبتلعان ارتفاع الشاشة ولا يبقى للمطاعم
      // إلا شريطٌ يعرض مطعمين. نُقلا **داخل** قائمة المطاعم كعنصرَي رأسٍ
      // يمرّان معها (نمط تطبيقات التوصيل) — فالقائمة تأخذ كامل الارتفاع،
      // والبنر يختفي عند التمرير. (يُبنيان في itemBuilder أدناه.)
      Expanded(
        // ملاحظة مهمة: AppStreamBuilder يتوقّع دالة تُرجع Stream وليس Stream
        // جاهزاً، لذلك يُمرَّر اسم الدالة بلا أقواس (tear-off). إضافة أقواس
        // هنا تكسر التوقيع.
        // المفضلة الحية من مستند المستخدم (ح2): تدفّقٌ لا لقطة، فقلبٌ
        // ضُغط في صفحة المطعم ينعكس هنا فوراً. الزائر (بلا حساب) يرى
        // القائمة بلا قلوب — المفضلة ميزة أصحاب الحسابات.
        child: StreamBuilder<AppUser?>(
            stream: _favoritesStream(context),
            builder: (ctx0, userSnap) {
          final favorites =
              (userSnap.data?.favoriteRestaurantIds ?? const []).toSet();
          return AppStreamBuilder<List<Restaurant>>(
            stream: service.streamRestaurants,
            loading: const RestaurantListSkeleton(),
            builder: (ctx, list) {
          final filtered = _filter(list, favorites);
          if (list.isEmpty) return const AppEmpty(emoji: '🍽️', title: 'لا يوجد مطاعم');
          if (filtered.isEmpty) {
            // بحث خائب عن مطعم (ح5): اللحظة الأخطر في التطبيق كله —
            // «لم أجد مطعمي» تساوي حذفاً عند ٨٦٪ من المستخدمين. بدل
            // «لا يوجد» الميتة: زر يحوّل الخيبة إلى صوتٍ يُحصى فيصير
            // خريطة مبيعات، والعميل يصله لاحقاً «مطعمك وصل».
            final q = _query.trim();
            return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AppEmpty(
                  emoji: _favoritesOnly ? '💛' : '🔍',
                  title: _favoritesOnly
                      ? 'لا مفضلة بعد — اضغط القلب على مطعم يعجبك'
                      : 'لا توجد نتائج مطابقة'),
              if (!_favoritesOnly && q.length >= 2 && userSnap.data != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_business_outlined, size: 18),
                    label: Text('اطلب إضافة «$q»'),
                    onPressed: () async {
                      try {
                        await context
                            .read<FirebaseService>()
                            .requestRestaurant(q);
                        // نتذكّر ما طلبه هذا الجهاز محلياً لنبشّره حين ينضم.
                        await rememberRequestedRestaurant(q);
                        if (ctx.mounted) {
                          showSuccess(ctx,
                              'وصلنا صوتك — سنعمل على إحضار «$q» ونخبرك حين يصل 🙌');
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          showError(ctx, 'تعذّر إرسال الطلب، حاول مرة أخرى');
                        }
                      }
                    },
                  ),
                ),
            ]);
          }
          // البنر و«اطلب مجدداً» عنصرا رأسٍ يمرّان مع القائمة (لا مثبّتان
          // فوقها) كي تأخذ المطاعم كامل الارتفاع — يظهران خارج البحث فقط.
          final headers = <Widget>[
            if (_query.isEmpty) const PromoBannerCarousel(),
            if (_query.isEmpty) const _ReorderStrip(),
          ];
          final h = headers.length;
          return Column(children: [
            // بشير «مطعمك المطلوب وصل» فوق القائمة (لا أثناء البحث).
            if (_query.isEmpty) _RequestedArrivedBanner(restaurants: list),
            Expanded(
          child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: filtered.length + h,
              itemBuilder: (_, idx) {
            if (idx < h) return headers[idx];
            final i = idx - h;
            // دخول متعاقب لأول ثماني بطاقات فقط: التتابع بعدها لا يُرى
            // (خارج الشاشة)، وتأخيرُ عنصرٍ في أسفل قائمة طويلة بحساب
            // ترتيبه يجعله يظهر متأخراً بلا سبب مرئي عند القفز إليه.
            final card = _RestaurantCard(
                restaurant: filtered[i],
                isFavorite: favorites.contains(filtered[i].id),
                canFavorite: userSnap.data != null,
                deliveryFromFee: _settingsLoaded
                    ? _settings.deliveryBaseFee + _settings.deliveryAppCut
                    : null);
            if (i >= 8) return card;
            return card
                .animate(delay: (55 * i).ms)
                .fadeIn(duration: 260.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, duration: 300.ms, curve: Curves.easeOut);
          }),
            ),
          ]);
            });
        }),
      ),
    ]);
  }
}

/// بطاقة مطعم واحد في القائمة — لا تفتح إلا إذا كان المطعم مفتوحاً.
class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final bool isFavorite;
  final bool canFavorite;
  /// أدنى أجرة توصيل (الأساس + رسم المنصّة) من إعدادات اللوحة — تُمرَّر من
  /// الحالة لأن البطاقة StatelessWidget لا تصل إلى `_settings`. null =
  /// لم تُحمَّل بعد (زائر بلا صلاحية قراءة أو شبكة) فتُخفى الشريحة بدل
  /// عرض رقم افتراضي قد يخالف اللوحة.
  final double? deliveryFromFee;
  const _RestaurantCard(
      {required this.restaurant,
      this.isFavorite = false,
      this.canFavorite = false,
      this.deliveryFromFee});

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
      tappable: r.isOpenNow,
      openBuilder: (_, __) => RestaurantDetailScreen(restaurant: r),
      closedBuilder: (ctx, open) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: r.isOpenNow ? open : null,
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
                // قلب المفضلة (ح2) — للزائر لا يظهر: الميزة تخصّ حساباً
                // تُحفظ فيه. GestureDetector لا IconButton كي لا يفرض
                // حجم لمسٍ يضخّم صف العنوان.
                if (canFavorite)
                  GestureDetector(
                    onTap: () {
                      final auth = context.read<app_auth.AuthProvider>();
                      final uid = auth.user?.uid;
                      if (uid == null) return;
                      context
                          .read<FirebaseService>()
                          .toggleFavoriteRestaurant(uid, r.id, !isFavorite);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isFavorite ? AppColors.error : AppColors.textGray,
                      ),
                    ),
                  ),
                StatusBadge(label: r.openStatusLabel, color: r.isOpenNow ? AppColors.success : Colors.grey),
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
                if (deliveryFromFee != null)
                  _MetaChip(icon: Icons.delivery_dining_outlined,
                      // «توصيل مجاني» كانت كذبة مكلفة: حقل المطعم القديم صفر
                      // بينما التسعير الموحّد يحصّل فعلاً — فيصدم العميل في
                      // الدفع ويفقد الثقة. الصدق أرخص، والرقم شامل الرسم الثابت
                      // (قاعدة المالك: التوصيل المعروض = الأجرة + العمولة).
                      label:
                          'التوصيل من ${deliveryFromFee!.toStringAsFixed(0)} ر.س',
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

/// خيارات فرز الرئيسة (ح8+ح9) — «الأعلى خصماً» محفوظة عمداً حتى تُبنى
/// ميزة عروض المطاعم (قرار المالك 2026-08-14).
enum _HomeSort { recommended, rating, nearest, deliveryTime }

// ————————————————————————————————————————————————————————————————
// «مطعمك المطلوب وصل» (بقيّة ح٥، 2026-08-20): «اطلب مطعمك» كان يحفظ
// العدّاد فقط — فلا سبيل لإشعار من طلب يوم ينضم مطعمه، ووعدُنا له «سنخبرك
// حين يصل» يبقى بلا وفاء. الإشعار الخادمي (push) ينتظر نشر ووركر
// الإشعارات؛ وحتى ذلك، هذا اكتشافٌ **محلّي** يوفّي الوعد بلا خادم: الجهاز
// يتذكّر ما طلبه صاحبه، ويكشف انضمام المطعم بمطابقة قائمة المطاعم عند فتح
// الرئيسية، فيبشّره ببانرٍ لمرة واحدة. (حدُّه: جهازٌ واحد، ومتى فُتح
// التطبيق — والـpush يكمّله لاحقاً.)
const String _kRequestedKey = 'requested_restaurants';

Future<void> rememberRequestedRestaurant(String name) async {
  final norm = normalizeArabic(name);
  if (norm.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_kRequestedKey) ?? [];
  if (!list.contains(norm)) {
    list.add(norm);
    await prefs.setStringList(_kRequestedKey, list);
  }
}

/// شريحة تُظهَر مرّةً حين يتوفّر مطعمٌ طلبه صاحب الجهاز — تأخذ قائمة
/// المطاعم المعروضة أصلاً فلا تفتح تدفّقاً ثانياً.
class _RequestedArrivedBanner extends StatefulWidget {
  final List<Restaurant> restaurants;
  const _RequestedArrivedBanner({required this.restaurants});

  @override
  State<_RequestedArrivedBanner> createState() =>
      _RequestedArrivedBannerState();
}

class _RequestedArrivedBannerState extends State<_RequestedArrivedBanner> {
  Restaurant? _match;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final wanted = prefs.getStringList(_kRequestedKey) ?? [];
    if (wanted.isEmpty) return;
    for (final r in widget.restaurants) {
      final rn = normalizeArabic(r.name);
      final hit = wanted.firstWhere(
          (w) => rn.contains(w) || w.contains(rn),
          orElse: () => '');
      if (hit.isNotEmpty) {
        // يُشطب فور اكتشافه فلا يتكرّر البشير كل فتحة.
        wanted.remove(hit);
        await prefs.setStringList(_kRequestedKey, wanted);
        if (mounted) setState(() => _match = r);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _match;
    if (r == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _match = null);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RestaurantDetailScreen(restaurant: r)));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Text('🎉', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مطعمك المطلوب وصل!',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text('${r.name} — اطلب منه الآن',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textGray)),
                    ]),
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: AppColors.primaryDark),
            ]),
          ),
        ),
      ),
    );
  }
}

/// شريحة «اطلب مجدداً» لآخر طلبٍ مكتمل — تُجلب مرة عند بناء الشاشة (لا
/// تدفّقاً دائماً: الرئيسية لا تحتاج تحديثاً حياً لطلبٍ سابق). تختفي
/// تماماً لمن لا طلب مكتمل له، فلا تشغل حيزاً فارغاً للعميل الجديد.
class _ReorderStrip extends StatefulWidget {
  const _ReorderStrip();

  @override
  State<_ReorderStrip> createState() => _ReorderStripState();
}

class _ReorderStripState extends State<_ReorderStrip> {
  Future<Order?>? _future;

  @override
  void initState() {
    super.initState();
    final uid = context.read<app_auth.AuthProvider>().user?.uid;
    if (uid == null) return;
    final service = context.read<FirebaseService>();
    // أول لقطة من تدفّق طلبات العميل (مرتّبة تنازلياً) تكفي — نأخذ أحدث
    // طلبٍ مكتمل منها. لا نُبقي التدفّق مفتوحاً.
    _future = service.streamCustomerOrders(uid).first.then((orders) {
      for (final o in orders) {
        if (o.status == OrderStatus.delivered) return o;
      }
      return null;
    }).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) return const SizedBox.shrink();
    return FutureBuilder<Order?>(
      future: _future,
      builder: (ctx, snap) {
        final order = snap.data;
        if (order == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final ok = await reorderIntoCart(context, order);
                if (ok && context.mounted) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CartScreen()));
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.replay_rounded,
                      size: 20, color: AppColors.primaryDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('اطلب مجدداً',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700)),
                          Text('${order.restaurantName} — طلبك السابق',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textGray)),
                        ]),
                  ),
                  const Icon(Icons.chevron_left_rounded,
                      color: AppColors.textGray),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
