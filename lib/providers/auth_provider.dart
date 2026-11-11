import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../core/api/api_client.dart';
import '../services/activity_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();
  final ApiClient _api = ApiClient();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  // -------------------
  // GETTERS
  // -------------------

  UserModel? get user => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // -------------------
  // AUTO LOGIN
  // -------------------

  Future<void> tryAutoLogin() async {
    // Firebase Auth จำ session ให้อยู่แล้ว — ถ้าไม่มี session ก็ถือว่ายังไม่ล็อกอิน
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");

    if (firebaseUser == null || userId == null) {
      await prefs.clear();
      notifyListeners();
      return;
    }

    _api.setToken(firebaseUser.uid);

    try {
      final user = await _repository.getProfile(userId);
      _currentUser = user;
    } catch (e) {
      await prefs.clear();
    }

    notifyListeners();
  }

  // -------------------
  // LOGIN
  // -------------------

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _repository.login(phone: username, password: password);

      _currentUser = user;

      // ผูก FCM token กับช่างจริงที่ล็อกอิน (แทนการ hardcode ตอนเริ่มแอป)
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("getToken error: $e");
      }

      await FirebaseFirestore.instance
          .collection('technicians')
          .doc(user.id)
          .update({
            'status': 'online',
            'lastLogin': FieldValue.serverTimestamp(),
            if (fcmToken != null) 'fcmToken': fcmToken,
          });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("userId", user.id);
      _api.setToken(user.token);

      // บันทึกเหตุการณ์เข้าสู่ระบบลง activity_events
      await ActivityService.log(
        type: ActivityService.login,
        technicianId: user.id,
      );
    } catch (e) {
      debugPrint("LOGIN ERROR: $e");
      final msg = e.toString();
      if (msg.contains("PASSWORD_WRONG")) {
        _error = "รหัสผ่านไม่ถูกต้อง";
      } else if (msg.contains("USER_NOT_FOUND")) {
        _error = "ไม่พบผู้ใช้งานนี้";
      } else {
        _error = "เข้าสู่ระบบไม่สำเร็จ";
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // -------------------
  // LOGOUT
  // -------------------

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = _currentUser?.id; 

    _api.setToken("");

    _error = null;

    if (userId != null) {
      await FirebaseFirestore.instance
          .collection('technicians')
          .doc(userId)
          .update({
            'status': 'offline',
            'lastLogout': FieldValue.serverTimestamp(),
            // ลบ FCM token ออกเพื่อไม่ให้แจ้งเตือนไปหาช่างที่ล็อกเอาต์แล้ว
            'fcmToken': FieldValue.delete(),
          });

      // บันทึกเหตุการณ์ออกจากระบบลง activity_events
      await ActivityService.log(
        type: ActivityService.logout,
        technicianId: userId,
      );
    }

    // ออกจากระบบ Firebase Auth หลังเขียนข้อมูลเสร็จ (rules ต้องใช้ session อยู่)
    await FirebaseAuth.instance.signOut();

    await prefs.clear();

    _currentUser = null;

    notifyListeners();
  }
}
