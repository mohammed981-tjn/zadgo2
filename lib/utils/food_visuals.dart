// عناصر بصرية بديلة عن الصور الفوتوغرافية لواجهة العميل: تدرجات لونية من
// هوية ZadGo، أيقونات رمزية حسب فئة الصنف، وشارات معلومات بارزة (وقت
// التوصيل، التقييم، رسوم التوصيل، "الأكثر طلباً"). تُستخدم بدل الاعتماد على
// صور مطاعم/أصناف قد لا تتوفر أو تكون مكسورة.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

/// تدرج لوني ثابت من هوية ZadGo يُستخدم خلفية لبطاقات المطاعم بدل الصور.
const List<Color> zadgoBrandGradient = [AppColors.dark, AppColors.secondary];

/// يختار أيقونة رمزية مناسبة لصنف طعام بالاعتماد على اسم الفئة/الصنف (كلمات
/// مفتاحية عربية شائعة). تُستخدم كبديل عن صورة الصنف حين لا تتوفر.
IconData foodCategoryIcon(String categoryName, [String itemName = '']) {
  final text = '$categoryName $itemName';
  bool has(List<String> words) => words.any(text.contains);

  if (has(['مشاوي', 'شواء', 'مشوي', 'كباب', 'كبسة', 'مندي', 'لحم'])) {
    return Icons.outdoor_grill_rounded;
  }
  if (has(['برجر', 'هامبرجر', 'ساندويش', 'سندويش'])) {
    return Icons.lunch_dining_rounded;
  }
  if (has(['بيتزا'])) return Icons.local_pizza_rounded;
  if (has(['مشروبات', 'عصير', 'قهوة', 'شاي', 'كوفي'])) {
    return Icons.local_cafe_rounded;
  }
  if (has(['حلويات', 'حلى', 'كيك', 'آيسكريم', 'ايسكريم', 'حلا'])) {
    return Icons.icecream_rounded;
  }
  if (has(['دجاج', 'فراخ'])) return Icons.egg_alt_rounded;
  if (has(['بحري', 'سمك', 'روبيان', 'أسماك'])) return Icons.set_meal_rounded;
  if (has(['سلطة', 'صحي'])) return Icons.eco_rounded;
  if (has(['فطور', 'إفطار'])) return Icons.free_breakfast_rounded;
  return Icons.restaurant_menu_rounded;
}

/// شعار بديل موحّد لبطاقة المطعم: تدرج لوني من هوية ZadGo + الحرف الأول من
/// اسم المطعم بخط كبير أنيق. يُستخدم دائماً حين لا يتوفر [imageUrl]، ويعرض
/// الصورة تلقائياً (مع سقوط آمن لنفس البديل عند فشل التحميل) حين تتوفر.
class RestaurantAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final BorderRadius? borderRadius;
  const RestaurantAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 64,
    this.borderRadius,
  });

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: zadgoBrandGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: borderRadius ?? BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          _initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.trim().isEmpty) return _fallback();
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      // تخزين على القرص: صورة المطعم تُنزَّل مرة وتُعرض من الجهاز بعدها —
      // كانت تُعاد من الشبكة مع كل فتح للتطبيق.
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        errorWidget: (_, __, ___) => _fallback(),
        placeholder: (_, __) => _fallback(),
      ),
    );
  }
}

/// أيقونة الصنف: تعرض [imageUrl] تلقائياً إن توفّر، وإلا أيقونة رمزية حسب
/// الفئة داخل دائرة بلون هوية ZadGo الفاتح.
class MenuItemVisual extends StatelessWidget {
  final String categoryName;
  final String itemName;
  final String? imageUrl;
  final double size;
  const MenuItemVisual({
    super.key,
    required this.categoryName,
    required this.itemName,
    this.imageUrl,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // فكّ الترميز بحجم العرض لا بحجم الملف: صورة 2000 بكسل كانت تُفك
          // في الذاكرة كاملة (~16MB) لعرضها في 60 بكسل. الضرب في 3 يغطي
          // أعلى كثافات الشاشات دون فرق بصري. والتخزين على القرص يمنع
          // إعادة تنزيل قوائم كاملة مع كل فتح.
          memCacheWidth: (size * 3).round(),
          errorWidget: (_, __, ___) => _iconFallback(),
          placeholder: (_, __) => _iconFallback(),
        ),
      );
    }
    return _iconFallback();
  }

  Widget _iconFallback() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(foodCategoryIcon(categoryName, itemName),
            color: AppColors.primaryDark, size: size * 0.5),
      );
}
