// lib/providers/auth_provider.dart
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
        final fetched = await _service.getUser(firebaseUser.uid);
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
    notifyListeners();
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
    UserRole? expectedRole,
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
        expectedRole: expectedRole,
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