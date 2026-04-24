import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _db = FirebaseFirestore.instance;

  Future<UserModel> login({
    required String phone,
    required String password,
  }) async {
    final result = await _db
        .collection('technicians')
        .where('phone', isEqualTo: phone)
        .get();

    print("FOUND: ${result.docs.length}");

    if (result.docs.isNotEmpty) {
      final doc = result.docs.first;
      final dbPass = doc['password'];

      print("DB PASS: $dbPass");

      if (dbPass == password) {
        return UserModel(id: doc.id, name: doc['name'], token: "mock_token");
      } else {
        throw Exception("PASSWORD_WRONG");
      }
    } else {
      throw Exception("USER_NOT_FOUND");
    }
  }

  Future<UserModel> getProfile(String userId) async {
    final doc = await _db.collection('technicians').doc(userId).get();

    final data = doc.data()!;

    return UserModel(id: doc.id, name: data['name'], token: "mock_token");
  }
}
