import '../models/user_model.dart';

class AuthRepository {
  Future<UserModel> getProfile() async {
    await Future.delayed(const Duration(seconds: 1));

    return UserModel(id: "1", name: "Test User", token: "mock_token_123");
  }

  Future<UserModel> login({
    required String phone,
    required String password,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    if (phone == "0999999999" && password == "1234") {
      return UserModel(id: "1", name: "Mock User", token: "mock_token_123");
    } else {
      throw Exception("LOGIN_FAILED");
    }
  }
}
