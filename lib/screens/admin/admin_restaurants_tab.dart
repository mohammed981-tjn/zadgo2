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
import '../../widgets/image_upload_field.dart';
import '../../providers/storage_service.dart';
import 'pick_location_screen.dart';
import 'admin_menu_import_screen.dart';

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
        title: Text(restaurant.displayName,
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
                const InfoRow(
                  icon: Icons.delivery_dining_outlined,
                  text: 'أجرة التوصيل موحّدة للمنصّة — تُضبط من شاشة «الحوافز»',
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
  late final TextEditingController _name, _branch, _desc, _phone, _addr,
      _min, _time, _emoji, _commission;
  bool _loading = false;
  double? _lat, _lng;
  String? _imageUrl;
  late final Set<String> _cuisines;
  int _priceLevel = 0;
  // ساعات العمل المجدولة: خريطة يوم(1..7)→جدول. فارغة = بلا جدول (المفتاح
  // اليدوي وحده). _useSchedule يفصل «بلا جدول» عن «جدول كل أيامه مغلقة».
  late final Map<int, DaySchedule> _hours;
  bool _useSchedule = false;
  // تاريخ انتهاء الإعفاء من العمولة (حملة «٣ شهور مجاناً»): تُختم النسبة
  // صفراً حتى هذا التاريخ ثم تعود المضبوطة تلقائياً. null = بلا إعفاء.
  DateTime? _commissionFreeUntil;
  // معرّف ثابت يُحسب مرة واحدة، ليُرفع الغلاف تحت مسار المطعم نفسه حتى قبل
  // حفظه لأول مرة (بدل توليد معرّف جديد عند الحفظ فتضيع الصورة المرفوعة).
  late final String _restaurantId = widget.existing?.id ?? const Uuid().v4();

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _name  = TextEditingController(text: r?.name ?? '');
    _branch = TextEditingController(text: r?.branchName ?? '');
    _desc  = TextEditingController(text: r?.description ?? '');
    _phone = TextEditingController(text: r?.phone ?? '');
    _addr  = TextEditingController(text: r?.address ?? '');
    _min   = TextEditingController(text: r?.minOrder.toString() ?? '20');
    _time  = TextEditingController(text: r?.estimatedTimeMin.toString() ?? '30');
    _emoji = TextEditingController(text: r?.emoji ?? '🍽️');
    _commission = TextEditingController(
        text: (r?.commissionPercent ?? 15).toStringAsFixed(0));
    _lat = r?.lat;
    _lng = r?.lng;
    _imageUrl = r?.imageUrl;
    _cuisines = {...?r?.cuisines};
    _priceLevel = r?.priceLevel ?? 0;
    _hours = {...?r?.openingHours};
    _useSchedule = _hours.isNotEmpty;
    _commissionFreeUntil = r?.commissionFreeUntil;
  }

  @override
  void dispose() {
    for (final c in [_name, _branch, _desc, _phone, _addr, _min, _time, _emoji, _commission]) {
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

  static const _dayNames = {
    1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس',
    5: 'الجمعة', 6: 'السبت', 7: 'الأحد',
  };

  Future<void> _pickTime(
      int day, bool isOpenField, void Function(void Function()) setHrs) async {
    final d = _hours[day] ?? const DaySchedule();
    final parts = (isOpenField ? d.open : d.close).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
    );
    if (picked == null) return;
    final hhmm = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setHrs(() {
      final cur = _hours[day] ?? const DaySchedule();
      _hours[day] =
          isOpenField ? cur.copyWith(open: hhmm) : cur.copyWith(close: hhmm);
    });
  }

  Widget _dayRow(int day, void Function(void Function()) setHrs) {
    final d = _hours[day] ?? const DaySchedule();
    return Row(children: [
      SizedBox(
          width: 58,
          child: Text(_dayNames[day]!, style: const TextStyle(fontSize: 12.5))),
      Checkbox(
        visualDensity: VisualDensity.compact,
        value: d.closed,
        onChanged: (v) =>
            setHrs(() => _hours[day] = d.copyWith(closed: v ?? false)),
      ),
      const Text('مغلق', style: TextStyle(fontSize: 11.5)),
      const Spacer(),
      if (d.closed)
        const Text('—', style: TextStyle(fontSize: 13, color: AppColors.textGray))
      else ...[
        TextButton(
            onPressed: () => _pickTime(day, true, setHrs),
            child: Text(d.open, style: const TextStyle(fontSize: 13))),
        const Text('–', style: TextStyle(fontSize: 12)),
        TextButton(
            onPressed: () => _pickTime(day, false, setHrs),
            child: Text(d.close, style: const TextStyle(fontSize: 13))),
      ],
    ]);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final service = context.read<FirebaseService>();
    final r = Restaurant(
      id: _restaurantId,
      name: _name.text.trim(),
      branchName: _branch.text.trim(),
      description: _desc.text.trim(),
      emoji: _emoji.text.trim(),
      phone: _phone.text.trim(),
      address: _addr.text.trim(),
      // حقول التسعير القديمة تُمرَّر كما كانت محفوظة (لا حقول إدخال لها):
      // التسعير الموحّد في Pricing لا يقرؤها، وعرضُها للمدير كان يوهمه أن
      // تعديلها يغيّر شيئاً — بينما لا أثر لها إطلاقاً.
      driverShareFee: widget.existing?.driverShareFee ?? 0,
      appShareFee: widget.existing?.appShareFee ?? 0,
      perKmFee: widget.existing?.perKmFee ?? 0,
      freeKm: widget.existing?.freeKm ?? 0,
      minOrder: double.tryParse(_min.text) ?? 20,
      // العمولة المرنة: سلاح حملة التوقيع («صفر عمولة ٩٠ يوماً») — النسبة
      // من هذا الحقل لا من الكود، مقيّدة ٠..١٠٠ فلا تشلّها غلطة إدخال.
      commissionPercent:
          (double.tryParse(_commission.text.trim()) ?? 15).clamp(0.0, 100.0),
      commissionFreeUntil: _commissionFreeUntil,
      cuisines: _cuisines.toList(),
      priceLevel: _priceLevel,
      estimatedTimeMin: int.tryParse(_time.text) ?? 30,
      isOpen: widget.existing?.isOpen ?? true,
      openingHours: _useSchedule ? _hours : const {},
      rating: widget.existing?.rating ?? 5.0,
      ratingCount: widget.existing?.ratingCount ?? 0,
      totalOrders: widget.existing?.totalOrders ?? 0,
      imageUrl: _imageUrl,
      lat: _lat,
      lng: _lng,
    );
    if (widget.existing == null) {
      await service.addRestaurant(r);
    } else {
      await service.updateRestaurant(r);
      // موقع مصحَّح يلحق بالطلبات الجارية فوراً (ملاحظة المالك: سائق طلبٍ
      // قائم ظل يُقاد للموقع القديم بعد التصحيح — لقطة الطلب لا تتحدث
      // وحدها). فشل النشر لا يُفشل الحفظ: القراءة الحيّة في شاشات السائق
      // خط الدفاع الثاني.
      final moved = _lat != null &&
          _lng != null &&
          (widget.existing!.lat != _lat || widget.existing!.lng != _lng);
      if (moved) {
        try {
          final n =
              await service.propagateRestaurantLocation(_restaurantId, _lat!, _lng!);
          if (n > 0 && mounted) {
            showSuccess(context, 'حُدِّث الموقع في $n من الطلبات الجارية');
          }
        } catch (_) {}
      }
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
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _f(_emoji, 'رمز المطعم (Emoji)', isReq: false),
                _f(_name, 'اسم المطعم'),
                // اسم الفرع اختياري — يُملأ فقط للعلامات ذات الفروع المتعددة
                // ليظهر للعميل «فطير ستيشن — العزيزية» بدل اسمين متطابقين.
                _f(_branch, 'اسم الفرع (اختياري) — مثل: العزيزية', isReq: false),
                ImageUploadField(
                  label: 'صورة المطعم',
                  imageUrl: _imageUrl,
                  pathBuilder: (ext) => StorageService.restaurantPath(_restaurantId, ext),
                  onChanged: (url) => setState(() => _imageUrl = url),
                ),
                _f(_desc, 'وصف المطعم'),
                _f(_phone, 'رقم الهاتف', type: TextInputType.phone),
                _f(_addr, 'العنوان'),
                Row(children: [
                  Expanded(child: _f(_min, 'الحد الأدنى', type: TextInputType.number, validator: validatePrice)),
                  const SizedBox(width: 10),
                  Expanded(child: _f(_time, 'وقت التوصيل (دقيقة)', type: TextInputType.number)),
                ]),
                _f(_commission, 'نسبة عمولة المنصّة ٪ (0 = بلا عمولة)',
                    type: TextInputType.number),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                      'اضبط النسبة المتفَّق عليها هنا، وحدّد أدناه «مجاني حتى» '
                      'تاريخَ انتهاء الإعفاء — تبقى العمولة صفراً حتى ذلك '
                      'اليوم ثم تسري النسبة تلقائياً. الدفاتر السابقة لا تتحرك.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
                ),
                // «مجاني حتى» (العمولة التلقائية): تختار التاريخ مرة واحدة يوم
                // التوقيع، فينتهي الإعفاء وحده في موعده بلا متابعة يدوية.
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _commissionFreeUntil ??
                          now.add(const Duration(days: 90)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setState(() => _commissionFreeUntil = picked);
                    }
                  },
                  icon: Icon(
                      _commissionFreeUntil != null
                          ? Icons.event_available
                          : Icons.event_outlined,
                      size: 18,
                      color: _commissionFreeUntil != null
                          ? AppColors.success
                          : null),
                  label: Text(_commissionFreeUntil != null
                      ? 'عمولة صفر حتى ${_commissionFreeUntil!.year}/${_commissionFreeUntil!.month}/${_commissionFreeUntil!.day} (اضغط للتعديل)'
                      : 'مجاني حتى تاريخ (اختياري — للإعفاء المؤقت)'),
                ),
                if (_commissionFreeUntil != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _commissionFreeUntil = null),
                      icon: const Icon(Icons.close, size: 15),
                      label: const Text('إلغاء الإعفاء',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 8),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('المطابخ (تصنيف كيتا — يظهر في فلتر العميل)',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                StatefulBuilder(
                  builder: (ctx, setChips) => Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final c in kCuisines)
                        FilterChip(
                          label: Text(c, style: const TextStyle(fontSize: 11.5)),
                          selected: _cuisines.contains(c),
                          onSelected: (v) => setChips(() =>
                              v ? _cuisines.add(c) : _cuisines.remove(c)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('مستوى الأسعار (لفلتر العميل)',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                StatefulBuilder(
                  builder: (ctx, setPrice) => Wrap(spacing: 6, children: [
                    for (final (lvl, label) in [
                      (0, 'بلا'), (1, '\$ اقتصادي'), (2, '\$\$ متوسط'), (3, '\$\$\$ مرتفع')
                    ])
                      ChoiceChip(
                        label:
                            Text(label, style: const TextStyle(fontSize: 11.5)),
                        selected: _priceLevel == lvl,
                        onSelected: (_) => setPrice(() => _priceLevel = lvl),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (ctx, setHrs) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('ساعات عمل مجدولة',
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        subtitle: const Text(
                            'يفتح ويغلق المطعم تلقائياً حسب اليوم والساعة. '
                            'المفتاح اليدوي يبقى سيّداً لإغلاقٍ طارئ.',
                            style: TextStyle(fontSize: 11.5)),
                        value: _useSchedule,
                        onChanged: (v) => setHrs(() {
                          _useSchedule = v;
                          // تفعيلٌ أولُ مرة: املأ الأيام السبعة بجدول افتراضي
                          // كي يرى المدير أسبوعاً كاملاً بدل فراغ.
                          if (v && _hours.isEmpty) {
                            for (var d = 1; d <= 7; d++) {
                              _hours[d] = const DaySchedule();
                            }
                          }
                        }),
                      ),
                      if (_useSchedule)
                        for (var day = 1; day <= 7; day++) _dayRow(day, setHrs),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: Icon(_lat != null ? Icons.check_circle : Icons.map_outlined,
                      color: _lat != null ? AppColors.success : null),
                  label: Text(_lat != null
                      ? 'الموقع محدد ✓ (اضغط للتعديل)'
                      : 'اختر موقع المطعم من الخريطة'),
                ),
                // الإحداثيات مكتوبة صراحةً: نقطة خاطئة على الخريطة تبدو
                // «محددة ✓» تماماً كالصحيحة، وقد عطّلت تأكيد الاستلام عند
                // الكابتن (٢٠٢٦-٠٨-١١) — والرقم الظاهر يُقارَن بموقع المطعم
                // في خرائط جوجل بثوانٍ ويكشف الخطأ قبل أن يقع.
                if (_lat != null && _lng != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'الإحداثيات: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                      '  —  الكابتن لا يستطيع تأكيد الاستلام إلا ضمن ١٠٠ متر من هذه النقطة',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textGray),
                    ),
                  ),
                // تحذير صريح بأثر تشغيلي لا مجرد «حقل ناقص»: مطعم بلا موقع
                // كانت طلباته لا تُسنَد لأي سائق إطلاقاً (بلاغ المالك
                // ٢٠٢٦-٠٨-١١). الإسناد صار يعمل بدونه، لكن باختيار أضعف —
                // بالتقييم لا بالأقرب — وأجرة التوصيل تُحسب على مسافة صفر.
                if (_lat == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: const Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 18, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'بلا موقع: يُختار الكابتن بالتقييم لا بالأقرب، '
                          'وأجرة التوصيل تُحسب بلا مسافة. حدِّد الموقع.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ]),
                  ),
                ],
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
      appBar: AppBar(
        title: Text('قائمة ${restaurant.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'استيراد منيو',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminMenuImportScreen(
                  restaurantId: restaurant.id,
                  restaurantName: restaurant.displayName,
                ),
              ),
            ),
          ),
        ],
      ),
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
            style: const TextStyle(fontSize: 12.5),
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
                    style: TextStyle(fontSize: 11.5, color: AppColors.warning, fontWeight: FontWeight.w600)),
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
  late final TextEditingController _name, _desc, _price, _emoji, _stock, _kcal;
  bool _loading = false;
  bool _trackStock = false;
  late String? _categoryId;
  String? _imageUrl;

  /// مجموعات خيارات الصنف (حجم/إضافات) — تُحرَّر محلياً وتُحفظ مع الصنف.
  late List<ItemOptionGroup> _optionGroups =
      List.of(widget.existing?.optionGroups ?? const []);
  // معرّف ثابت للصنف حتى تُرفع صورته تحت مساره الصحيح قبل الحفظ الأول.
  late final String _itemId = widget.existing?.id ?? const Uuid().v4();

  @override
  void initState() {
    super.initState();
    final i = widget.existing;
    _name  = TextEditingController(text: i?.name ?? '');
    _desc  = TextEditingController(text: i?.description ?? '');
    _price = TextEditingController(text: i?.price.toString() ?? '');
    _emoji = TextEditingController(text: i?.emoji ?? '🍽️');
    _stock = TextEditingController(text: i?.stockQuantity?.toString() ?? '');
    _kcal  = TextEditingController(text: i?.kcal?.toString() ?? '');
    _trackStock = i?.trackStock ?? false;
    _imageUrl = i?.imageUrl;
    // القيمة المبدئية للفئة: فئة الصنف الحالية إن كانت لا تزال موجودة فعلاً
    // ضمن قائمة الفئات، وإلا (صنف "بلا فئة" مثلاً) تُترك بلا اختيار مبدئي
    // ليختار المدير فئة صريحة بدل الإبقاء على معرّف فئة غير موجود.
    final currentCatId = widget.categoryId;
    _categoryId = widget.categories.any((c) => c.id == currentCatId) ? currentCatId : null;
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _emoji, _stock, _kcal]) c.dispose();
    super.dispose();
  }

  /// حوار إنشاء/تعديل مجموعة خيارات: الاسم، النوع، وقائمة الخيارات بفروق
  /// أسعارها. [index] فارغ = مجموعة جديدة.
  Future<void> _editGroup(int? index) async {
    final existing = index == null ? null : _optionGroups[index];
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final optNameCtrl = TextEditingController();
    final optDeltaCtrl = TextEditingController();
    bool multi = existing?.multiSelect ?? false;
    final options = List<ItemOption>.of(existing?.options ?? const []);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: Text(index == null ? 'مجموعة خيارات جديدة' : 'تعديل المجموعة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم المجموعة',
                      hintText: 'الحجم / الإضافات / نوع العجين'),
                ),
                SwitchListTile(
                  value: multi,
                  onChanged: (v) => setDialogState(() => multi = v),
                  title: const Text('إضافات اختيارية (تحديد متعدد)',
                      style: TextStyle(fontSize: 13.5)),
                  subtitle: const Text(
                      'مطفأ = اختيار واحد إلزامي كالحجم',
                      style: TextStyle(fontSize: 11.5)),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                ),
                ...options.asMap().entries.map((e) => Row(children: [
                      Expanded(
                        child: Text(
                            e.value.priceDelta == 0
                                ? e.value.name
                                : '${e.value.name} (${e.value.priceDelta > 0 ? '+' : ''}${e.value.priceDelta.toStringAsFixed(0)} ر.س)',
                            style: const TextStyle(fontSize: 13.5)),
                      ),
                      IconButton(
                        iconSize: 17,
                        icon: const Icon(Icons.close, color: AppColors.error),
                        onPressed: () =>
                            setDialogState(() => options.removeAt(e.key)),
                      ),
                    ])),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: optNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'خيار', hintText: 'كبير'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: optDeltaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(
                          labelText: '± سعر', hintText: '5'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.primary),
                    onPressed: () {
                      final n = optNameCtrl.text.trim();
                      if (n.isEmpty) return;
                      setDialogState(() {
                        options.add(ItemOption(
                            name: n,
                            priceDelta:
                                double.tryParse(optDeltaCtrl.text.trim()) ?? 0));
                        optNameCtrl.clear();
                        optDeltaCtrl.clear();
                      });
                    },
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('حفظ المجموعة')),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty || options.isEmpty) {
      if (mounted) {
        showError(context, 'المجموعة تحتاج اسماً وخياراً واحداً على الأقل');
      }
      return;
    }
    setState(() {
      final group =
          ItemOptionGroup(name: name, multiSelect: multi, options: options);
      if (index == null) {
        _optionGroups.add(group);
      } else {
        _optionGroups[index] = group;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_categoryId == null) return;
    setState(() => _loading = true);
    final service = context.read<FirebaseService>();
    final item = MenuItem(
      id: _itemId,
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
      imageUrl: _imageUrl,
      totalSold: widget.existing?.totalSold ?? 0,
      kcal: int.tryParse(_kcal.text.trim()),
      optionGroups: _optionGroups,
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
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                _f(_kcal, 'السعرات الحرارية (اختياري)',
                    type: TextInputType.number, isReq: false),
                ImageUploadField(
                  label: 'صورة الصنف',
                  imageUrl: _imageUrl,
                  pathBuilder: (ext) =>
                      StorageService.menuItemPath(widget.restaurantId, _itemId, ext),
                  onChanged: (url) => setState(() => _imageUrl = url),
                ),
                SwitchListTile(
                  value: _trackStock,
                  onChanged: (v) => setState(() => _trackStock = v),
                  title: const Text('تتبع المخزون'),
                  subtitle: const Text('إخفاء الصنف تلقائياً عند نفاده',
                      style: TextStyle(fontSize: 12.5)),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                ),
                if (_trackStock)
                  _f(_stock, 'الكمية المتاحة', type: TextInputType.number),
                const SizedBox(height: 10),
                // مجموعات الخيارات — الفجوة الكبرى أمام جاهز/كيتا: حجم
                // إلزامي (اختيار واحد) أو إضافات اختيارية بفروق أسعار.
                Row(children: [
                  const Text('خيارات الصنف',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _editGroup(null),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('مجموعة', style: TextStyle(fontSize: 12.5)),
                  ),
                ]),
                if (_optionGroups.isEmpty)
                  const Text('بلا خيارات — يُضاف الصنف مباشرة بسعره.',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.textGray)),
                ..._optionGroups.asMap().entries.map((e) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        title: Text(
                            '${e.value.name} — ${e.value.multiSelect ? 'إضافات اختيارية' : 'اختيار واحد إلزامي'}',
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          e.value.options
                              .map((o) => o.priceDelta == 0
                                  ? o.name
                                  : '${o.name} (${o.priceDelta > 0 ? '+' : ''}${o.priceDelta.toStringAsFixed(0)})')
                              .join('، '),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            iconSize: 18,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editGroup(e.key),
                          ),
                          IconButton(
                            iconSize: 18,
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error),
                            onPressed: () => setState(
                                () => _optionGroups.removeAt(e.key)),
                          ),
                        ]),
                      ),
                    )),
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
