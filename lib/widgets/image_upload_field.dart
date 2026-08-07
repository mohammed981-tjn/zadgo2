// lib/widgets/image_upload_field.dart
//
// حقل اختيار صورة ورفعها — يُستخدم في نماذج لوحة الإدارة (صورة المطعم وصورة
// الصنف). يعرض معاينة الصورة الحالية، ويسمح باستبدالها أو إزالتها، ويتكفّل
// برفعها إلى Firebase Storage وإرجاع الرابط عبر [onChanged].
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/storage_service.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class ImageUploadField extends StatefulWidget {
  /// عنوان الحقل الظاهر فوق المعاينة.
  final String label;

  /// رابط الصورة الحالية (إن وُجدت).
  final String? imageUrl;

  /// المسار داخل التخزين الذي تُرفع إليه الصورة (يُبنى من معرّف المطعم/الصنف).
  /// يُستدعى مع امتداد الملف المختار حتى يُحفظ بامتداده الصحيح.
  final String Function(String extension) pathBuilder;

  /// يُستدعى بالرابط الجديد بعد نجاح الرفع، أو بـ `null` عند إزالة الصورة.
  final ValueChanged<String?> onChanged;

  const ImageUploadField({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.pathBuilder,
    required this.onChanged,
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  bool _uploading = false;

  Future<void> _pick() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // ضغط معقول قبل الرفع: صور المنيو تُعرض بحجم صغير، فرفع صورة بدقّة
        // الكاميرا الكاملة يهدر باقة العميل ومساحة التخزين بلا فائدة.
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final ext = _extensionOf(picked.name);
      final url = await StorageService().uploadImage(
        bytes: bytes,
        path: widget.pathBuilder(ext),
        contentType: _contentTypeOf(ext),
      );
      widget.onChanged(url);
      if (mounted) showSuccess(context, 'تم رفع الصورة');
    } catch (_) {
      if (mounted) showError(context, 'تعذّر رفع الصورة، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _contentTypeOf(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    final hasImage = url != null && url.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _uploading
                  ? const Center(
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : hasImage
                      ? Image.network(url, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined, color: AppColors.textGray))
                      : const Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.textGray),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text(hasImage ? 'استبدال الصورة' : 'اختيار صورة'),
                    onPressed: _uploading ? null : _pick,
                  ),
                  if (hasImage && !_uploading)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('إزالة'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      onPressed: () => widget.onChanged(null),
                    ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
