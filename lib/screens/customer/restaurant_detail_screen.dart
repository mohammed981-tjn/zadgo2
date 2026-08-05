Expanded(
  child: StreamBuilder<List<MenuCategory>>(
    stream: service.streamCategories(restaurant.id),
    builder: (context, catSnap) {
      if (catSnap.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'خطأ في تحميل الفئات:\n${catSnap.error}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      }
      if (!catSnap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final cats = catSnap.data!;

      return StreamBuilder<List<MenuItem>>(
        stream: service.streamMenuItems(restaurant.id),
        builder: (context, itemSnap) {
          if (itemSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  'خطأ في تحميل الأصناف:\n${itemSnap.error}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!itemSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = itemSnap.data!;

          final orderableItems = items.where((i) => i.canOrder).toList();
          final catIds = cats.map((c) => c.id).toSet();

          final unmatchedItems =
              orderableItems.where((i) => !catIds.contains(i.categoryId)).toList();
          final visibleCats =
              cats.where((cat) => orderableItems.any((i) => i.categoryId == cat.id)).toList();

          if (visibleCats.isEmpty && unmatchedItems.isEmpty) {
            return const AppEmpty(emoji: '🍽️', title: 'لا توجد أصناف متاحة حالياً');
          }

          const otherCategory =
              MenuCategory(id: '__other__', restaurantId: '', name: 'أصناف أخرى');

          return ListView(children: [
            ...visibleCats.map((cat) {
              final catItems =
                  orderableItems.where((i) => i.categoryId == cat.id).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(cat.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ),
                ...catItems.map((item) =>
                    _ItemTile(item: item, category: cat, restaurant: restaurant)),
              ]);
            }),
            if (unmatchedItems.isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(otherCategory.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ),
                ...unmatchedItems.map((item) =>
                    _ItemTile(item: item, category: otherCategory, restaurant: restaurant)),
              ]),
          ]);
        },
      );
    },
  ),
),