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
  bool _isAdmin = false;
  bool _isApplicant = false;
  String? _error;

  // -------------------
  // GETTERS
  // -------------------

  UserModel? get user => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// ผู้ดูแล (role claim = admin) -> หน้า Dispatcher
  bool get isAdmin => _isAdmin;

  /// ล็อกอินด้วย Google แล้วแต่ยังไม่เป็นช่าง -> หน้าใบสมัคร
  bool get isApplicant => _isApplicant;

  AuthRepository get repository => _repository;
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

    // ผู้สมัครช่างที่ยังรออนุมัติ: มี session แต่ยังไม่มีโปรไฟล์ช่าง
    if (firebaseUser != null &&
        userId == null &&
        await _repository.hasApplication()) {
      _isApplicant = true;
      notifyListeners();
      return;
    }

    if (firebaseUser == null || userId == null) {
      await prefs.clear();
      notifyListeners();
      return;
    }

    _api.setToken(firebaseUser.uid);

    try {
      if (await _repository.currentUserIsAdmin()) {
        _currentUser = _repository.adminUser();
        _isAdmin = true;
      } else {
        _currentUser = await _repository.getProfile(userId);
        _isAdmin = false;
      }
    } catch (e) {
      await prefs.clear();
    }

    notifyListeners();
  }

  // -------------------
  // LOGIN
  // -------------------

  /// ใส่อีเมล = ผู้ดูแล, ใส่เบอร์โทร = ช่าง
  Future<void> login(String username, String password) => _runLogin(
    () => username.contains('@')
        ? _repository.loginAdmin(email: username, password: password)
        : _repository.login(phone: username, password: password),
  );

  /// เข้าสู่ระบบด้วย Google: ช่างที่เชื่อมแล้วเข้าแอปช่าง, แอดมินเข้า Dispatcher,
  /// บัญชีที่ยังไม่เป็นช่างไปหน้าใบสมัคร (isApplicant)
  Future<void> loginWithGoogle() => _runLogin(_repository.loginWithGoogle);

  /// หลังแอดมินอนุมัติใบสมัคร: เข้าแอปช่างด้วย session เดิม
  Future<void> completeApprovedSignup() =>
      _runLogin(_repository.technicianForCurrentUser);

  Future<void> submitApplication({
    required String name,
    required String phone,
    required String area,
    required int trainingLevel,
  }) =>
      _repository.submitApplication(
        name: name,
        phone: phone,
        area: area,
        trainingLevel: trainingLevel,
      );

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
    _isApplicant = false;
    notifyListeners();

    try {
      final user = await signIn();
      final prefs = await SharedPreferences.getInstance();

      if (await _repository.currentUserIsAdmin()) {
        // ผู้ดูแล: ไม่มีเอกสารช่าง จึงไม่อัปเดต technicians
        _currentUser = user;
        _isAdmin = true;
        await prefs.setString("userId", user.id);
        _api.setToken(user.token);
        await ActivityService.log(
          type: ActivityService.login,
          technicianId: user.id,
          meta: {"role": "admin"},
        );
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentUser = user;
      _isAdmin = false;

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
      _isAdmin = false;
      final msg = e.toString();
      if (msg.contains("APPLICANT")) {
        _isApplicant = true;
        _error = null;
      } else if (msg.contains("CANCELLED")) {
        _error = null; // ผู้ใช้ปิดหน้าต่าง Google เอง ไม่ต้องแจ้ง
      } else if (msg.contains("DISABLED")) {
        _error = "บัญชีนี้ถูกปิดใช้งาน กรุณาติดต่อแอดมิน";
      } else if (msg.contains("PASSWORD_WRONG")) {
        _error = "รหัสผ่านไม่ถูกต้อง";
      } else if (msg.contains("NOT_ADMIN")) {
        _error = "บัญชีนี้ไม่มีสิทธิ์ผู้ดูแล";
      } else if (msg.contains("ADMIN_ACCOUNT")) {
        _error = "บัญชีนี้เป็นบัญชีผู้ดูแล กรุณาเข้าสู่ระบบด้วยอีเมล";
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

    if (userId != null && !_isAdmin) {
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
    _isAdmin = false;
    _isApplicant = false;

    notifyListeners();
  }
}
