// lib/utils/reorder.dart
//
// «اطلب مجدداً» — منطقٌ واحد يخدم موضعين (لمسات العميل 2026-08-20):
// بطاقة «طلباتي» والشريحة الجديدة في الرئيسية. كان المنطق حبيس
// my_orders_screen، فنقله للرئيسية يعني نسخه — ونسختان تتباعدان مع
// أول تعديل. هنا دالة واحدة تُرجع نجاحها، ويتولّى المستدعي التنقّل
// للسلة (فلا يستورد utils شاشةً — يبقى الاتجاه أحادياً).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/firebase_service.dart';
import '../providers/cart_provider.dart';
import 'app_lang.dart';
import 'helpers.dart';

/// يملأ السلة بأصناف [order] المتوفّرة حالياً. يُرجع `true` إن أُضيف صنفٌ
/// واحد على الأقل (فينتقل المستدعي للسلة)، و`false` إن تعذّر (مطعم مغلق/
/// مختفٍ، أصناف نفدت، أو ألغى العميل استبدال سلة مطعمٍ آخر).
Future<bool> reorderIntoCart(BuildContext context, Order order) async {
  final service = context.read<FirebaseService>();
  final cart = context.read<CartProvider>();

  // سلة فيها أصناف من مطعم آخر ستُفرَّغ (قاعدة «مطعم واحد للسلة») —
  // بموافقة صريحة لا بمسح صامت.
  if (!cart.isEmpty && cart.restaurantId != order.restaurantId) {
    final otherName =
        cart.restaurantName ?? tr('مطعم آخر', 'another restaurant');
    final ok = await showConfirmDialog(
      context,
      title: tr('استبدال السلة؟', 'Replace cart?'),
      content: tr(
          'سلتك تحوي أصنافاً من $otherName — ستُستبدل بأصناف هذا الطلب.',
          'Your cart has items from $otherName — they will be replaced '
          "with this order's items."),
      confirmLabel: tr('استبدال', 'Replace'),
    );
    if (ok != true || !context.mounted) return false;
  }

  try {
    final restaurant = await service.getRestaurantOnce(order.restaurantId);
    if (restaurant == null) {
      if (context.mounted) {
        showError(context,
            tr('هذا المطعم لم يعد متوفراً', 'This restaurant is no longer available'));
      }
      return false;
    }
    if (!restaurant.isOpenNow) {
      if (context.mounted) {
        showError(
            context,
            tr('${restaurant.name} مغلق حالياً — جرّب لاحقاً',
                '${restaurant.name} is closed right now — try again later'));
      }
      return false;
    }

    final menu = await service.getMenuItemsOnce(order.restaurantId);
    final byId = {for (final m in menu) m.id: m};

    var added = 0, skipped = 0;
    for (final oi in order.items) {
      final current = byId[oi.menuItemId];
      if (current == null || !current.isAvailable) {
        skipped++;
        continue;
      }
      // استرجاع خيارات الطلب القديم بأسمائها من القائمة الحالية؛ الخيار
      // الذي حُذف من القائمة يسقط، والمجموعة الإلزامية بلا اختيار مسترجَع
      // تأخذ خيارها الأول — فلا يدخل السلة صنفُ خياراتٍ ناقصُ إلزامي.
      final oldNames = (oi.extras ?? '')
          .split(' • ')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      final selections = <ItemOption>[];
      for (final group in current.optionGroups) {
        final matched =
            group.options.where((o) => oldNames.contains(o.name)).toList();
        if (group.multiSelect) {
          selections.addAll(matched);
        } else if (group.options.isNotEmpty) {
          selections.add(matched.isNotEmpty ? matched.first : group.options.first);
        }
      }
      for (var q = 0; q < oi.quantity; q++) {
        cart.add(current, restaurant.id, restaurant.name, restaurant.emoji,
            restaurant.driverShareFee, restaurant.appShareFee, selections);
      }
      added++;
    }

    if (!context.mounted) return false;
    if (added == 0) {
      showError(
          context,
          tr('أصناف هذا الطلب لم تعد متوفرة في القائمة',
              'The items from this order are no longer on the menu'));
      return false;
    }
    if (skipped > 0) {
      showSuccess(
          context,
          tr('أُضيف $added من الأصناف — و$skipped لم يعد متوفراً فتُرك',
              'Added $added items — $skipped no longer available, so skipped'));
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      showError(
          context,
          tr('تعذّر تجهيز السلة — تحقق من اتصالك وحاول مجدداً',
              'Could not prepare the cart — check your connection and try again'));
    }
    return false;
  }
}
