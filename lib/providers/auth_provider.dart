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

  Future<void> login(String username, String password) =>
      _runLogin(() => _repository.login(phone: username, password: password));

  /// เข้าสู่ระบบด้วย Google (ต้องเชื่อมบัญชีไว้ก่อน)
  Future<void> loginWithGoogle() => _runLogin(_repository.loginWithGoogle);

  /// อีเมล Google ที่เชื่อมไว้ (null = ยังไม่ได้เชื่อม)
  String? get linkedGoogleEmail => _repository.linkedGoogleEmail;

  /// เชื่อมบัญชี Google กับช่างที่ล็อกอินอยู่
  /// คืนค่าข้อความสำหรับแสดงผล (null = ผู้ใช้กดยกเลิก)
  Future<String?> linkGoogle() async {
    try {
      final email = await _repository.linkGoogle();
      notifyListeners();
      return email.isEmpty
          ? "เชื่อมบัญชี Google แล้ว"
          : "เชื่อมบัญชี Google แล้ว ($email)";
    } catch (e) {
      debugPrint("LINK GOOGLE ERROR: $e");
      final msg = e.toString();
      if (msg.contains("CANCELLED")) return null;
      if (msg.contains("ALREADY_LINKED")) {
        return "บัญชีนี้เชื่อม Google ไว้แล้ว";
      }
      if (msg.contains("GOOGLE_IN_USE")) {
        return "บัญชี Google นี้ถูกใช้กับผู้ใช้อื่นแล้ว กรุณาเลือกบัญชีอื่น หรือติดต่อแอดมิน";
      }
      if (msg.contains("REAUTH")) {
        return "กรุณาออกจากระบบแล้วเข้าสู่ระบบใหม่ก่อนเชื่อมบัญชี Google";
      }
      return "เชื่อมบัญชี Google ไม่สำเร็จ";
    }
  }

  Future<void> _runLogin(Future<UserModel> Function() signIn) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await signIn();

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
      _currentUser = null;
      final msg = e.toString();
      if (msg.contains("CANCELLED")) {
        _error = null; // ผู้ใช้ปิดหน้าต่าง Google เอง ไม่ต้องแจ้ง
      } else if (msg.contains("PASSWORD_WRONG")) {
        _error = "รหัสผ่านไม่ถูกต้อง";
      } else if (msg.contains("ADMIN_ACCOUNT")) {
        _error = "บัญชีนี้เป็นบัญชีแอดมิน กรุณาใช้หน้าหลังบ้าน";
      } else if (msg.contains("GOOGLE_NOT_LINKED")) {
        _error =
            "บัญชี Google นี้ยังไม่ได้เชื่อมกับช่าง กรุณาเข้าสู่ระบบด้วยเบอร์โทรก่อน แล้วกดเชื่อมบัญชี Google";
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
