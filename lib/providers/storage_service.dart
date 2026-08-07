// lib/providers/storage_service.dart
//
// رفع صور المطاعم والأصناف إلى Firebase Storage وإرجاع رابط تحميلها الدائم
// ليُحفظ في مستند المطعم/الصنف (حقل imageUrl).
//
// لماذا putData بالبايتات لا putFile بملف؟ لأن `dart:io.File` غير متاح على
// الويب، والتطبيق يُبنى للأندرويد وللويب معاً — قراءة البايتات من XFile
// تعمل على المنصّتين بنفس الشيفرة.
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// مجلّد صور المطاعم (شعار/غلاف) داخل التخزين.
  static String restaurantPath(String restaurantId, String ext) =>
      'restaurants/$restaurantId/cover.$ext';

  /// مجلّد صور أصناف مطعم معيّن.
  static String menuItemPath(String restaurantId, String itemId, String ext) =>
      'restaurants/$restaurantId/items/$itemId.$ext';

  /// يرفع الصورة ويُرجع رابط التحميل العام. يمرَّر [contentType] صراحةً حتى
  /// يُخزَّن الملف بنوعه الصحيح فتعرضه المتصفحات والتطبيق مباشرةً بدل تنزيله.
  Future<String> uploadImage({
    required Uint8List bytes,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// يحذف صورة عبر رابطها. يُتجاهل الفشل بهدوء لأن حذف صورة قديمة ليس سبباً
  /// كافياً لإفشال حفظ المطعم/الصنف نفسه (قد تكون محذوفة أصلاً).
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // تجاهل متعمّد.
    }
  }
}
