import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// แปลงเบอร์โทรเป็นอีเมลภายในระบบ เพื่อใช้กับ Firebase Auth (Email/Password)
  /// เช่น 0812345678 -> 0812345678@daisenkohero.local
  String _emailForPhone(String phone) => '${phone.trim()}@daisenkohero.local';

  /// เข้าสู่ระบบ:
  /// 1) ยืนยันรหัสผ่านผ่าน Firebase Auth (รหัสผ่านถูก hash โดย Firebase)
  ///    เพื่อให้ request.auth ใช้งานได้ใน Security Rules
  /// 2) ดึงโปรไฟล์ช่างจาก Firestore ที่ผูกด้วย authUid (แอดมินผูกไว้แล้ว)
  Future<UserModel> login({
    required String phone,
    required String password,
  }) async {
    final UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(
        email: _emailForPhone(phone),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // แปลง error ของ Firebase ให้เข้ากับ flow เดิมของแอป
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('PASSWORD_WRONG');
      }
      if (e.code == 'user-not-found') {
        throw Exception('USER_NOT_FOUND');
      }
      rethrow;
    }

    final uid = cred.user!.uid;
    final technician = await _fetchTechnician(uid: uid);
    return UserModel(id: technician.id, name: technician['name'], token: uid);
  }

  /// ดึงเอกสารช่างที่ผูกกับ authUid นี้
  /// การผูก authUid ทำโดยแอดมินเท่านั้น (scripts/add-technician.js หรือ
  /// scripts/migrate-auth.js) — แอปไม่ผูกเองแล้ว เพื่อไม่ให้บัญชีที่สมัครเอง
  /// ยึดเอกสารช่างคนอื่นได้
  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchTechnician({
    required String uid,
  }) async {
    final byUid = await _db
        .collection('technicians')
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (byUid.docs.isEmpty) {
      // มีบัญชี Auth แต่ยังไม่ได้ผูกกับช่าง: ออกจากระบบแล้วแจ้งให้ติดต่อแอดมิน
      await _auth.signOut();
      throw Exception('USER_NOT_FOUND');
    }
    return byUid.docs.first;
  }

  Future<UserModel> getProfile(String userId) async {
    final doc = await _db.collection('technicians').doc(userId).get();
    final data = doc.data()!;
    return UserModel(
      id: doc.id,
      name: data['name'],
      token: _auth.currentUser?.uid ?? '',
    );
  }
}
