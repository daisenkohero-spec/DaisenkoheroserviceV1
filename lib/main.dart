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

  // Firebase core is required — but never let a failure hang the whole app.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // Render the app immediately. Notifications/messaging are set up afterwards
  // and are fully optional — on iOS Safari web push can throw or hang, and it
  // must NEVER block the app from showing (that caused the infinite spinner).
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

  // Fire-and-forget, fully guarded — cannot affect rendering.
  _initMessaging();
}

/// Optional notifications / Firebase Messaging setup. Guarded so any failure
/// (common on web / iOS Safari) is logged and ignored.
Future<void> _initMessaging() async {
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService.init();
    await setupFCM();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? "";
      final body = message.notification?.body ?? "";
      NotificationService.showNotification(title, body);
    });
  } catch (e) {
    debugPrint("Messaging/notifications init skipped: $e");
  }
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
