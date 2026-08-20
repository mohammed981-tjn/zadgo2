// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'firebase_service.dart';
import 'push_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _service;
  AppUser? _user;
  bool _loading = false;
  String? _error;

  /// يكتمل بعد أول حكم فعلي لتدفّق المصادقة (جلسة مستعادة أو لا جلسة).
  /// السبلاش ينتظره بدل مهلة ثابتة: الفحص قبل اكتمال الاستعادة كان يرمي
  /// صاحبَ جلسةٍ سليمة إلى شاشة الدخول لمجرد بطء الشبكة (شكوى المالك:
  /// «كل عودة من الخلفية تطلب تسجيل الدخول من جديد»).
  final Completer<void> _firstAuthEvent = Completer<void>();
  Future<void> get onAuthResolved => _firstAuthEvent.future;

  AppUser? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  AuthProvider(this._service) {
    _service.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
    } else {
      try {
        final fetched = await _fetchUserWithRetry(firebaseUser.uid);
        if (fetched != null && !fetched.isActive) {
          await _service.signOut();
          _user = null;
          _error = 'تم تعطيل هذا الحساب، يرجى مراجعة الإدارة';
        } else {
          _user = fetched;
          // تسجيل الجهاز لإشعارات FCM بعد اكتمال بيانات المستخدم — هنا
          // تحديداً (لا في login وحدها) حتى يشمل أيضاً فتح التطبيق بجلسة
          // محفوظة، وهي الحالة الأكثر تكراراً بمرّات من تسجيل دخول جديد.
          if (fetched != null) {
            PushService.registerDevice(fetched.uid, _service.updateFcmToken);
          }
        }
      } catch (_) {
        _user = null;
      }
    }
    if (!_firstAuthEvent.isCompleted) _firstAuthEvent.complete();
    notifyListeners();
  }

  /// إعادة جلب ملف المستخدم من المصدر — تستدعيها بوابة المتقدّمين لحظة
  /// اعتماد المدير: الدور تغيّر في المستند بينما النسخة المحفوظة هنا ما
  /// زالت «عميلاً»، والملاحة للواجهة الصحيحة تقرأ من هذه النسخة.
  Future<void> reloadUser() async {
    final uid = _user?.uid;
    if (uid == null) return;
    final fetched = await _fetchUserWithRetry(uid);
    if (fetched != null) {
      _user = fetched;
      notifyListeners();
    }
  }

  /// جلب ملف المستخدم بثلاث محاولات متباعدة: تعثّر شبكة عابر لحظة العودة
  /// من الخلفية كان يُفرِّغ _user فيُطرد صاحبُ جلسةٍ صالحة لشاشة الدخول —
  /// وإعادة إدخاله كلمة المرور على نفس الشبكة المتعثرة لن تنجح أصلاً.
  Future<AppUser?> _fetchUserWithRetry(String uid) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future.delayed(Duration(seconds: attempt));
      try {
        return await _service.getUser(uid);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError!;
  }

  /// ينتظر فعلياً حتى تمتلئ بيانات المستخدم الكاملة (_user) بعد نجاح
  /// المصادقة، بدل الاعتماد فقط على تدفّق authStateChanges المستقل الذي
  /// قد يصل بعد أن يكون login() قد أرجع true بالفعل — وهذا بالضبط ما كان
  /// يسبب ظهور "فشل تسجيل الدخول" رغم صحة البيانات في المحاولة الأولى:
  /// login_screen.dart كان يتحقق من auth.user فور استلام true، بينما
  /// auth.user لم يُملأ بعد لأن _onAuthChanged لم يكتمل.
  ///
  /// نفحص كل 100 مللي ثانية لمدة أقصاها 8 ثوانٍ (حد أمان معقول لأي بطء
  /// شبكة غير متوقع)؛ إن لم يمتلئ _user خلالها، نعتبرها حالة فشل حقيقية
  /// بدل الانتظار للأبد.
  Future<bool> _waitForUserData() async {
    const maxWait = Duration(seconds: 8);
    const pollInterval = Duration(milliseconds: 100);
    final deadline = DateTime.now().add(maxWait);

    while (_user == null && DateTime.now().isBefore(deadline)) {
      await Future.delayed(pollInterval);
    }
    return _user != null;
  }

  Future<bool> login(String email, String password) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _service.signIn(email.trim(), password.trim());

      // ننتظر هنا حتى يكتمل _onAuthChanged فعلياً ويملأ _user، بدل إرجاع
      // true فوراً بعد نجاح المصادقة وحدها.
      final userReady = await _waitForUserData();

      _loading = false;
      notifyListeners();

      if (!userReady) {
        _error = 'تعذّر تحميل بيانات الحساب، حاول مرة أخرى';
        return false;
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code); _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'خطأ غير متوقع'; _loading = false; notifyListeners();
      return false;
    }
  }

  /// تحديث النسخة المحلية من بيانات المستخدم بعد تعديل الملف الشخصي —
  /// بدونها تبقى الشاشات التي تقرأ auth.user (إنشاء الطلب/الشكوى) بالاسم
  /// القديم حتى إعادة تسجيل الدخول.
  void applyProfile({required String name, required String phone}) {
    if (_user == null) return;
    _user = _user!.copyWith(name: name.trim(), phone: phone.trim());
    notifyListeners();
  }

  /// تغيير كلمة المرور: إعادة مصادقة بالحالية أولاً (شرط Firebase لعملية
  /// حساسة) ثم التحديث. أخطاء الشبكة والمصادقة تُترجم عربياً في [error].
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      final email = fbUser?.email;
      if (fbUser == null || email == null) {
        _error = 'سجّل الدخول أولاً';
        _loading = false; notifyListeners();
        return false;
      }
      final credential = EmailAuthProvider.credential(
          email: email, password: currentPassword);
      await fbUser.reauthenticateWithCredential(credential);
      await fbUser.updatePassword(newPassword);
      _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = switch (e.code) {
        'wrong-password' || 'invalid-credential' =>
          'كلمة المرور الحالية غير صحيحة',
        'weak-password' => 'كلمة المرور الجديدة ضعيفة (٦ أحرف فأكثر)',
        'requires-recent-login' => 'أعد تسجيل الدخول ثم حاول مجدداً',
        _ => _mapError(e.code),
      };
      _loading = false; notifyListeners();
      return false;
    } catch (_) {
      _error = 'خطأ غير متوقع'; _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name, required String email, required String password,
    required String phone, required UserRole role,
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final cred = await _service.register(email.trim(), password.trim());
      final uid = cred.user!.uid;
      final newUser = AppUser(uid: uid, name: name.trim(), email: email.trim(),
          phone: phone.trim(), role: role, createdAt: DateTime.now());
      await _service.createUser(newUser);
      if (role == UserRole.driver) {
        await _service.addDriver(Driver(id: uid, name: name.trim(), phone: phone.trim(),
            vehicleType: 'دراجة نارية'));
      }
      _user = newUser; _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code); _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'خطأ غير متوقع'; _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> registerWithCode({
    required String code,
    required String name,
    required String email,
    required String password,
    required String phone,
    String? nationalId,
    Set<UserRole>? allowedRoles,
    String? referredByCode,
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final user = await _service.registerWithCode(
        code: code.trim(),
        name: name.trim(),
        email: email.trim(),
        password: password.trim(),
        phone: phone.trim(),
        nationalId: nationalId?.trim(),
        allowedRoles: allowedRoles,
        referredByCode: referredByCode?.trim(),
      );
      _user = user; _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code); _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // يُمسح توكن الجهاز من مستند المستخدم قبل الخروج (بعده تمنع قواعد
    // الأمان الكتابة)، فلا تصل إشعارات حسابٍ خرج صاحبه إلى جهاز قد
    // يستخدمه شخص آخر.
    final uid = _user?.uid;
    if (uid != null) {
      try { await _service.clearFcmToken(uid); } catch (_) {}
    }
    await PushService.unregisterDevice();
    try { await _service.signOut(); } catch (_) {}
    _user = null; notifyListeners();
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found': return 'البريد الإلكتروني غير مسجل';
      case 'wrong-password': return 'كلمة المرور غير صحيحة';
      case 'invalid-credential': return 'البريد أو كلمة المرور غير صحيحة';
      case 'email-already-in-use': return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password': return 'كلمة المرور ضعيفة جداً';
      default: return 'خطأ ($code)';
    }
  }
}