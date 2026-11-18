import 'package:flutter/foundation.dart' show kIsWeb;
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

  // ---------------------------------------------------------------------------
  // Google
  // ช่างต้องล็อกอินด้วยเบอร์ + รหัสผ่านก่อน แล้วกด "เชื่อมบัญชี Google" ครั้งเดียว
  // Google จึงผูกกับบัญชีเดิม (uid เดิม) ไม่ต้องแก้ Security Rules และคนที่สมัคร
  // Google เองโดยไม่ได้เชื่อม จะไม่เจอเอกสารช่างใด ๆ
  // ---------------------------------------------------------------------------

  GoogleAuthProvider _googleProvider() =>
      GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});

  static const _cancelCodes = {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-canceled',
    'web-context-cancelled',
    'canceled',
    'cancelled',
  };

  /// อีเมล Google ที่เชื่อมกับบัญชีนี้อยู่ (null = ยังไม่ได้เชื่อม)
  String? get linkedGoogleEmail {
    final user = _auth.currentUser;
    if (user == null) return null;
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return info.email ?? '';
    }
    return null;
  }

  /// เข้าสู่ระบบด้วยบัญชี Google ที่เชื่อมไว้แล้ว
  Future<UserModel> loginWithGoogle() async {
    final UserCredential cred;
    try {
      cred = kIsWeb
          ? await _auth.signInWithPopup(_googleProvider())
          : await _auth.signInWithProvider(_googleProvider());
    } on FirebaseAuthException catch (e) {
      if (_cancelCodes.contains(e.code)) throw Exception('CANCELLED');
      rethrow;
    }

    final technician = await _fetchTechnician(
      uid: cred.user!.uid,
      // Google ที่ยังไม่ได้เชื่อม จะได้บัญชีใหม่เปล่า ๆ ลบทิ้งเพื่อไม่ให้ค้าง
      // และไม่ให้บัญชี Google นั้นถูกล็อกไว้จนเชื่อมกับช่างไม่ได้
      deleteIfNew: cred.additionalUserInfo?.isNewUser ?? false,
      notFoundCode: 'GOOGLE_NOT_LINKED',
    );
    return UserModel(
      id: technician.id,
      name: technician['name'],
      token: cred.user!.uid,
    );
  }

  /// เชื่อมบัญชี Google กับช่างที่ล็อกอินอยู่ คืนค่าอีเมล Google ที่เชื่อม
  Future<String> linkGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('NOT_SIGNED_IN');
    try {
      final cred = kIsWeb
          ? await user.linkWithPopup(_googleProvider())
          : await user.linkWithProvider(_googleProvider());
      for (final info in cred.user?.providerData ?? const <UserInfo>[]) {
        if (info.providerId == 'google.com') return info.email ?? '';
      }
      return cred.user?.email ?? '';
    } on FirebaseAuthException catch (e) {
      if (_cancelCodes.contains(e.code)) throw Exception('CANCELLED');
      if (e.code == 'provider-already-linked') throw Exception('ALREADY_LINKED');
      if (e.code == 'credential-already-in-use' ||
          e.code == 'email-already-in-use') {
        throw Exception('GOOGLE_IN_USE');
      }
      if (e.code == 'requires-recent-login') throw Exception('REAUTH');
      rethrow;
    }
  }

  /// ดึงเอกสารช่างที่ผูกกับ authUid นี้
  /// การผูก authUid ทำโดยแอดมินเท่านั้น (scripts/add-technician.js หรือ
  /// scripts/migrate-auth.js) — แอปไม่ผูกเองแล้ว เพื่อไม่ให้บัญชีที่สมัครเอง
  /// ยึดเอกสารช่างคนอื่นได้
  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchTechnician({
    required String uid,
    bool deleteIfNew = false,
    String notFoundCode = 'USER_NOT_FOUND',
  }) async {
    final byUid = await _db
        .collection('technicians')
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (byUid.docs.isEmpty) {
      // บัญชีแอดมินที่ไม่ใช่ช่าง ใช้หลังบ้านแทนแอปช่าง
      final token = await _auth.currentUser?.getIdTokenResult();
      final isAdmin = token?.claims?['role'] == 'admin';
      if (deleteIfNew && !isAdmin) {
        try {
          await _auth.currentUser?.delete();
        } catch (_) {
          // ลบไม่ได้ก็ไม่เป็นไร บัญชีนี้ไม่มีสิทธิ์อ่านอะไรอยู่แล้ว
        }
      }
      // มีบัญชี Auth แต่ยังไม่ได้ผูกกับช่าง: ออกจากระบบแล้วแจ้งให้ติดต่อแอดมิน
      await _auth.signOut();
      throw Exception(isAdmin ? 'ADMIN_ACCOUNT' : notFoundCode);
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
