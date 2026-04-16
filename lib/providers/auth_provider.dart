import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../core/api/api_client.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    _isLoading = true;
    notifyListeners();

    if (token == null) return;

    _api.setToken(token);

    try {
      final user = await _repository.getProfile();
      _currentUser = user;
    } catch (e) {
      await prefs.remove("token");
    }

    notifyListeners();
  }

  // -------------------
  // LOGIN
  // -------------------

  Future<void> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (phone.isEmpty || password.isEmpty) {
      _error = "กรุณากรอกข้อมูล";
      notifyListeners();
      return;
    }

    try {
      final user = await _repository.login(phone: phone, password: password);

      _currentUser = user;

      _api.setToken(user.token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", user.token);
    } catch (e) {
      _error = "เข้าสู่ระบบไม่สำเร็จ";
    }

    _isLoading = false;
    notifyListeners();
  }

  // -------------------
  // LOGOUT
  // -------------------

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
    _error = null;
    _currentUser = null;
    _api.setToken("");

    notifyListeners();
  }
}
