import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'firebase_service.dart';

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
      try { _user = await _service.getUser(firebaseUser.uid); } catch (_) { _user = null; }
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _service.signIn(email.trim(), password.trim());
      _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code); _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'خطأ غير متوقع'; _loading = false; notifyListeners();
      return false;
    }
  }

  Future<String?> validateRoleAccess(UserRole role, String? accessCode) async {
    switch (role) {
      case UserRole.customer:
        return null;
      case UserRole.driver:
        final code = accessCode?.trim() ?? '';
        if (code.isEmpty) return 'رمز التسجيل للسائق مطلوب';
        final inviteCode = await _service.getInviteCode(code, role);
        if (inviteCode == null) return 'رمز التسجيل للسائق غير صحيح أو منتهي';
        return null;
      case UserRole.admin:
        final code = accessCode?.trim() ?? '';
        if (code.isEmpty) return 'رمز التسجيل للمدير مطلوب';
        final inviteCode = await _service.getInviteCode(code, role);
        if (inviteCode == null) return 'رمز التسجيل للمدير غير صحيح أو منتهي';
        return null;
    }
  }

  Future<bool> register({
    required String name, required String email, required String password,
    required String phone, required UserRole role, String? accessCode,
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final roleAccessError = await validateRoleAccess(role, accessCode);
      if (roleAccessError != null) {
        _error = roleAccessError; _loading = false; notifyListeners();
        return false;
      }
      final cred = await _service.register(email.trim(), password.trim());
      final uid = cred.user!.uid;
      final newUser = AppUser(uid: uid, name: name.trim(), email: email.trim(),
          phone: phone.trim(), role: role, createdAt: DateTime.now());
      await _service.createUser(newUser);
      if (role == UserRole.driver) {
        await _service.addDriver(Driver(id: uid, name: name.trim(), phone: phone.trim(),
            vehicleType: 'دراجة نارية'));
      }
      if (role == UserRole.driver || role == UserRole.admin) {
        final inviteCode = await _service.getInviteCode(accessCode!.trim(), role);
        if (inviteCode != null) {
          await _service.markInviteCodeUsed(inviteCode.id);
        }
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

  Future<bool> requestPasswordReset(String email) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _service.sendPasswordResetEmail(email.trim());
      _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code); _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'خطأ غير متوقع'; _loading = false; notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try { await _service.signOut(); } catch (_) {}
    _user = null; notifyListeners();
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found': return 'البريد الإلكتروني غير مسجل';
      case 'wrong-password': return 'كلمة المرور غير صحيحة';
      case 'invalid-credential': return 'البريد أو كلمة المرور غير صحيحة';
      case 'invalid-email': return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'email-already-in-use': return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password': return 'كلمة المرور ضعيفة جداً';
      case 'too-many-requests': return 'تم تجاوز عدد المحاولات، حاول لاحقاً';
      default: return 'خطأ ($code)';
    }
  }
}
