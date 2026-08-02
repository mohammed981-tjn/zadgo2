// lib/screens/admin/admin_restaurants_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'pick_location_screen.dart';

class AdminRestaurantsTab extends StatelessWidget {
  const AdminRestaurantsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Restaurant>>(
      stream: service.streamRestaurants,
      builder: (ctx, list) {
        return Scaffold(
          body: list.isEmpty
              ? AppEmpty(
                  emoji: '🍽️',
                  title: 'لا يوجد مطاعم',
                  action: ElevatedButton(
                    onPressed: () => _showRestaurantForm(ctx, null),
                    child: const Text('إضافة مطعم'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _RestaurantCard(restaurant: list[i]),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showRestaurantForm(ctx, null),
            icon: const Icon(Icons.add),
            label: const Text('مطعم جديد'),
          ),
        );
      },
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  const _RestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(restaurant.emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(restaurant.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(restaurant.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: restaurant.isOpen,
              onChanged: (v) => service.toggleRestaurant(restaurant.id, v),
              activeColor: AppColors.success,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                InfoRow(icon: Icons.phone_outlined, text: restaurant.phone),
                InfoRow(icon: Icons.location_on_outlined, text: restaurant.address),
                InfoRow(
                  icon: Icons.delivery_dining,
                  text:
                      'أجرة التوصيل: نصيب السائق ${formatCurrency(restaurant.driverShareFee)} + نصيب التطبيق ${formatCurrency(restaurant.appShareFee)}',
                ),
                InfoRow(
                  icon: Icons.timer_outlined,
                  text: 'وقت التوصيل: ${restaurant.estimatedTimeMin} دقيقة',
                ),
                InfoRow(
                  icon: Icons.shopping_bag_outlined,
                  text: 'الحد الأدنى: ${formatCurrency(restaurant.minOrder)}',
                ),
                InfoRow(
                  icon: Icons.star_rounded,
                  text: 'التقييم: ${restaurant.rating.toStringAsFixed(1)} ⭐',
                ),
                InfoRow(
                  icon: restaurant.lat != null ? Icons.check_circle : Icons.warning_amber_rounded,
                  text: restaurant.lat != null
                      ? 'الموقع محدد على الخريطة'
                      : 'لم يُحدَّد موقع على الخريطة',
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRestaurantForm(context, restaurant),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('تعديل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showMenuManager(context, restaurant),
                      icon: const Icon(Icons.menu_book_outlined, size: 16),
                      label: const Text('القائمة'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showRestaurantForm(BuildContext context, Restaurant? r) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _RestaurantForm(existing: r),
  );
}

class _RestaurantForm extends StatefulWidget {
  final Restaurant? existing;
  const _RestaurantForm({this.existing});
  @override
  State<_RestaurantForm> createState() => _RestaurantFormState();
}

class _RestaurantFormState extends State<_RestaurantForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _desc, _phone, _addr,
      _driverFee, _appFee, _perKm, _freeKm, _min, _time, _emoji;
  bool _loading = false;
  double? _lat, _lng;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _name  = TextEditingController(text: r?.name ?? '');
    _desc  = TextEditingController(text: r?.description ?? '');
    _phone = TextEditingController(text: r?.phone ?? '');
    _addr  = TextEditingController(text: r?.address ?? '');
    _driverFee = TextEditingController(text: r?.driverShareFee.toString() ?? '5');
    _appFee    = TextEditingController(text: r?.appShareFee.toString() ?? '0');
    _perKm = TextEditingController(text: r?.perKmFee.toString() ?? '0');
    _freeKm = TextEditingController(text: r?.freeKm.toString() ?? '3');
    _min   = TextEditingController(text: r?.minOrder.toString() ?? '20');
    _time  = TextEditingController(text: r?.estimatedTimeMin.toString() ?? '30');
    _emoji = TextEditingController(text: r?.emoji ?? '🍽️');
    _lat = r?.lat;
    _lng = r?.lng;
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _phone, _addr, _driverFee, _appFee, _perKm, _freeKm, _min, _time, _emoji]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          initialLocation: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final service = context.read<FirebaseService>();
    final r = Restaurant(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      description: _desc.text.trim(),
      emoji: _emoji.text.trim(),
      phone: _phone.text.trim(),
      address: _addr.text.trim(),
      driverShareFee: double.tryParse(_driverFee.text) ?? 5,
      appShareFee: double.tryParse(_appFee.text) ?? 0,
      perKmFee: double.tryParse(_perKm.text) ?? 0,
      freeKm: double.tryParse(_freeKm.text) ?? 3,
      minOrder: double.tryParse(_min.text) ?? 20,
      estimatedTimeMin: int.tryParse(_time.text) ?? 30,
      isOpen: widget.existing?.isOpen ?? true,
      rating: widget.existing?.rating ?? 5.0,
      lat: _lat,
      lng: _lng,
    );
    if (widget.existing == null) {
      await service.addRestaurant(r);
    } else {
      await service.updateRestaurant(r);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16, left: 16, right: 16,
        ),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.existing == null ? 'إضافة مطعم' : 'تعديل المطعم',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _f(_emoji, 'رمز المطعم (Emoji)', isReq: false),
                _f(_name, 'اسم المطعم'),
                _f(_desc, 'وصف المطعم'),
                _f(_phone, 'رقم الهاتف', type: TextInputType.phone),
                _f(_addr, 'العنوان'),
                Row(children: [
                  Expanded(child: _f(_driverFee, 'نصيب السائق', type: TextInputType.number, validator: validatePrice)),
                  const SizedBox(width: 10),
                  Expanded(child: _f(_appFee, 'نصيب التطبيق', type: TextInputType.number, validator: validatePrice)),
                ]),
                Row(children: [
                  Expanded(child: _f(_perKm, 'أجرة الكيلومتر الإضافي', type: TextInputType.number, isReq: false)),
                  const SizedBox(width: 10),
                  Expanded(child: _f(_freeKm, 'الكيلومترات المجانية', type: TextInputType.number, isReq: false)),
                ]),
                Row(children: [
                  Expanded(child: _f(_min, 'الحد الأدنى', type: TextInputType.number, validator: validatePrice)),
                  const SizedBox(width: 10),
                  Expanded(child: _f(_time, 'وقت التوصيل (دقيقة)', type: TextInputType.number)),
                ]),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: Icon(_lat != null ? Icons.check_circle : Icons.map_outlined,
                      color: _lat != null ? AppColors.success : null),
                  label: Text(_lat != null
                      ? 'الموقع محدد ✓ (اضغط للتعديل)'
                      : 'اختر موقع المطعم من الخريطة'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );

  Widget _f(
    TextEditingController c, String label, {
    TextInputType type = TextInputType.text,
    bool isReq = true,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(labelText: label),
          validator: validator ?? (isReq ? (v) => validateRequired(v, label) : null),
        ),
      );
}

void _showMenuManager(BuildContext context, Restaurant r) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MenuManagerScreen(restaurant: r)),
  );
}

class MenuManagerScreen extends StatelessWidget {
  final Restaurant restaurant;
  const MenuManagerScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Scaffold(
      appBar: AppBar(title: Text('قائمة ${restaurant.name}')),
      body: AppStreamBuilder<List<MenuCategory>>(
        stream: () => service.streamCategories(restaurant.id),
        builder: (ctx, cats) {
          return AppStreamBuilder<List<MenuItem>>(
            stream: () => service.streamMenuItems(restaurant.id),
            builder: (ctx2, allItems) {
              // أصناف بلا فئة صالحة: categoryId فارغ أو يشير لفئة محذوفة/غير
              // موجودة. سابقاً كانت تختفي بصمت (لا تظهر في أي فئة) فيصعب
              // على المدير حتى معرفة وجودها لتصحيحها؛ الآن تُجمع في قسم
              // منفصل "أصناف بلا فئة" يبقى ظاهراً دائماً طالما يوجد صنف واحد
              // فيه، مع إمكانية تعديل الصنف واختيار فئة صحيحة له.
              final catIds = cats.map((c) => c.id).toSet();
              final unclassifiedItems =
                  allItems.where((i) => !catIds.contains(i.categoryId)).toList();
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _addCategoryDialog(context, restaurant.id),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة فئة'),
                  ),
                  const SizedBox(height: 12),
                  ...cats.map((cat) {
                    final catItems = allItems.where((i) => i.categoryId == cat.id).toList();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        title: Text(cat.name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${catItems.length} صنف'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                          onPressed: () => _showItemForm(context, restaurant.id, cat.id, null, cats),
                        ),
                        children: catItems
                            .map((item) => _ItemTile(
                                item: item, restaurantId: restaurant.id, categories: cats))
                            .toList(),
                      ),
                    );
                  }),
                  if (unclassifiedItems.isNotEmpty)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: AppColors.warning.withOpacity(0.08),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: const Text('أصناف بلا فئة',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
                        subtitle: Text('${unclassifiedItems.length} صنف — يحتاج تعيين فئة'),
                        children: unclassifiedItems
                            .map((item) => _ItemTile(
                                item: item, restaurantId: restaurant.id, categories: cats))
                            .toList(),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _addCategoryDialog(BuildContext context, String rId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة فئة'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'اسم الفئة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await context.read<FirebaseService>().addCategory(
                      MenuCategory(
                        id: const Uuid().v4(),
                        restaurantId: rId,
                        name: ctrl.text.trim(),
                      ),
                    );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final MenuItem item;
  final String restaurantId;
  final List<MenuCategory> categories;
  const _ItemTile({required this.item, required this.restaurantId, required this.categories});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return ListTile(
      leading: Text(item.emoji, style: const TextStyle(fontSize: 28)),
      title: Text(item.name.trim().isEmpty ? '(بلا اسم)' : item.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${formatCurrency(item.price)}${item.trackStock ? "  •  مخزون: ${item.stockQuantity ?? "∞"}" : ""}',
            style: const TextStyle(fontSize: 12),
          ),
          // تحذير واضح بدل ترك المدير يكتشف صنفاً ناقص البيانات صدفة —
          // اسم فارغ أو سعر صفري/غير صالح غالباً يعني إدخالاً غير مكتمل.
          if (item.name.trim().isEmpty || item.price <= 0)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline, size: 13, color: AppColors.warning),
                SizedBox(width: 4),
                Text('بيانات الصنف غير مكتملة',
                    style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: item.isAvailable,
            onChanged: (v) =>
                service.toggleItemAvailability(restaurantId, item.id, v),
            activeColor: AppColors.success,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () =>
                _showItemForm(context, restaurantId, item.categoryId, item, categories),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'حذف الصنف',
                content: 'هل تريد حذف "${item.name}"؟',
                confirmLabel: 'حذف',
                confirmColor: AppColors.error,
              );
              if (ok == true && context.mounted) {
                await service.deleteMenuItem(restaurantId, item.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

void _showItemForm(BuildContext context, String rId, String catId, MenuItem? existing,
    List<MenuCategory> categories) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ItemForm(
        restaurantId: rId, categoryId: catId, existing: existing, categories: categories),
  );
}

class _ItemForm extends StatefulWidget {
  final String restaurantId, categoryId;
  final MenuItem? existing;
  final List<MenuCategory> categories;
  const _ItemForm(
      {required this.restaurantId,
      required this.categoryId,
      this.existing,
      required this.categories});
  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _desc, _price, _emoji, _stock;
  bool _loading = false;
  bool _trackStock = false;
  late String? _categoryId;

  @override
  void initState() {
    super.initState();
    final i = widget.existing;
    _name  = TextEditingController(text: i?.name ?? '');
    _desc  = TextEditingController(text: i?.description ?? '');
    _price = TextEditingController(text: i?.price.toString() ?? '');
    _emoji = TextEditingController(text: i?.emoji ?? '🍽️');
    _stock = TextEditingController(text: i?.stockQuantity?.toString() ?? '');
    _trackStock = i?.trackStock ?? false;
    // القيمة المبدئية للفئة: فئة الصنف الحالية إن كانت لا تزال موجودة فعلاً
    // ضمن قائمة الفئات، وإلا (صنف "بلا فئة" مثلاً) تُترك بلا اختيار مبدئي
    // ليختار المدير فئة صريحة بدل الإبقاء على معرّف فئة غير موجود.
    final currentCatId = widget.categoryId;
    _categoryId = widget.categories.any((c) => c.id == currentCatId) ? currentCatId : null;
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _emoji, _stock]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_categoryId == null) return;
    setState(() => _loading = true);
    final service = context.read<FirebaseService>();
    final item = MenuItem(
      id: widget.existing?.id ?? const Uuid().v4(),
      restaurantId: widget.restaurantId,
      categoryId: _categoryId!,
      name: _name.text.trim(),
      description: _desc.text.trim(),
      price: double.tryParse(_price.text) ?? 0,
      emoji: _emoji.text.trim(),
      isAvailable: widget.existing?.isAvailable ?? true,
      trackStock: _trackStock,
      stockQuantity:
          _trackStock && _stock.text.isNotEmpty ? int.tryParse(_stock.text) : null,
    );
    if (widget.existing == null) {
      await service.addMenuItem(item);
    } else {
      await service.updateMenuItem(item);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16, left: 16, right: 16,
        ),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing == null ? 'إضافة صنف' : 'تعديل الصنف',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(labelText: 'الفئة'),
                  items: widget.categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) => v == null ? 'اختر فئة للصنف' : null,
                ),
                const SizedBox(height: 12),
                _f(_emoji, 'رمز الصنف', isReq: false),
                _f(_name, 'اسم الصنف'),
                _f(_desc, 'الوصف'),
                _f(_price, 'السعر', type: TextInputType.number, validator: validatePrice),
                SwitchListTile(
                  value: _trackStock,
                  onChanged: (v) => setState(() => _trackStock = v),
                  title: const Text('تتبع المخزون'),
                  subtitle: const Text('إخفاء الصنف تلقائياً عند نفاده',
                      style: TextStyle(fontSize: 12)),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                ),
                if (_trackStock)
                  _f(_stock, 'الكمية المتاحة', type: TextInputType.number),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );

  Widget _f(
    TextEditingController c, String label, {
    TextInputType type = TextInputType.text,
    bool isReq = true,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(labelText: label),
          validator: validator ?? (isReq ? (v) => validateRequired(v, label) : null),
        ),
      );
}
