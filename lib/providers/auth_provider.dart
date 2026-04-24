import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../core/api/api_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final userId = prefs.getString("userId");

    if (token == null || userId == null) {
      notifyListeners();
      return;
    }

    _api.setToken(token);

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

      if (user != null) {
        print("LOGIN SUCCESS");

        _currentUser = user;

        await FirebaseFirestore.instance
            .collection('technicians')
            .doc(user.id)
            .update({
              'status': 'online',
              'lastLogin': FieldValue.serverTimestamp(),
            });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("userId", user.id);
        if (user.token != null) {
          await prefs.setString("token", user.token!);
          _api.setToken(user.token!);
        }
      } else {
        _error = "Invalid username or password";
      }
    } catch (e) {
      print("LOGIN ERROR: $e");
      _error = "Login failed";
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
          });
    }

    await prefs.clear();

    _currentUser = null;

    notifyListeners();
  }
}
