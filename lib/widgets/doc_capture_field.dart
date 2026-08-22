// lib/widgets/doc_capture_field.dart
//
// حقل التقاط مستند في نماذج التقديم (كابتن/مطعم): بطاقة تُفتح على
// كاميرا/معرض وتعرض المصغّر بعد الالتقاط، وضغطة مطوّلة تحذف.
//
// الالتقاط بعرض ١٢٨٠ وجودة ٧٠ عمداً: القاعدة ترفض صورة فوق ٤٠٠ك (المستند
// Blob داخل Firestore — التخزين محجوب حتى Blaze)، وهذه الإعدادات تنتج
// عملياً ١٥٠–٣٥٠ك مع بقاء رقم الهوية وتاريخ الانتهاء مقروءين في عارض
// التكبير الإداري. لا إعادة ضغط محلية (تستلزم حزمة جديدة — بند أ٦)،
// فالصورة النادرة المتجاوزة تُرفض برسالة تطلب إعادة التصوير.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_lang.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

/// السقف العملي قبل حدّ القاعدة (400000) — هامش لرأس المستند وحقوله.
const int kDocImageMaxBytes = 390000;

/// يلتقط صورة مستند مضغوطة من الكاميرا أو المعرض ويعيد بايتاتها،
/// أو null عند الإلغاء. يعرض خطأً ويعيد null إن تجاوزت السقف.
Future<Uint8List?> pickDocImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(tr('التقط بالكاميرا', 'Take with camera')),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(tr('من المعرض', 'From gallery')),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    imageQuality: 70,
  );
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  if (bytes.length > kDocImageMaxBytes) {
    if (context.mounted) {
      showError(
          context,
          tr('الصورة كبيرة جداً — أعد التصوير للمستند وحده (بلا خلفية واسعة)',
              'Image too large — retake with the document only (no wide background)'));
    }
    return null;
  }
  return bytes;
}

class DocCaptureField extends StatelessWidget {
  final String label;
  final bool required;
  final Uint8List? value;
  final ValueChanged<Uint8List?> onChanged;

  const DocCaptureField({
    super.key,
    required this.label,
    this.required = false,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final has = value != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () async {
          final bytes = await pickDocImage(context);
          if (bytes != null) onChanged(bytes);
        },
        onLongPress: has ? () => onChanged(null) : null,
        leading: has
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(value!,
                    width: 52, height: 52, fit: BoxFit.cover),
              )
            : Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.add_a_photo_outlined,
                    color: AppColors.textGray, size: 22),
              ),
        title: Text(label, style: const TextStyle(fontSize: 13.5)),
        subtitle: Text(
          has
              ? tr('التُقطت — اضغط للتبديل، مطوّلاً للحذف',
                  'Captured — tap to replace, long-press to delete')
              : (required ? tr('إلزامي', 'Required') : tr('اختياري', 'Optional')),
          style: TextStyle(
            fontSize: 11.5,
            color: has
                ? AppColors.success
                : (required ? AppColors.error : AppColors.textGray),
          ),
        ),
        trailing: Icon(
          has ? Icons.check_circle_rounded : Icons.chevron_left_rounded,
          color: has ? AppColors.success : AppColors.textGray,
          size: 22,
        ),
      ),
    );
  }
}
