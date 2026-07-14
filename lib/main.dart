import 'package:flutter/material.dart';
import 'package:project_techniqian/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/job_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.init();
  await setupFCM();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final title = message.notification?.title ?? "";
    final body = message.notification?.body ?? "";

    // ใช้ local notification แสดง
    NotificationService.showNotification(title, body);
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// BACKGROUND HANDLER
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // ขอ permission (ตอนเริ่มแอปยังไม่รู้ว่าใครล็อกอิน
  // จึงบันทึก FCM token ให้ช่างจริงตอน login แทน — ดู AuthProvider.login)
  await messaging.requestPermission(alert: true, badge: true, sound: true);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Techniqian',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(primaryColor: Color(0xFF1E3A8A)),

      home: const AuthWrapper(),
    );
  }
}
