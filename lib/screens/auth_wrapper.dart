import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'nav_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AuthProvider>().tryAutoLogin());
  }

  @override
Widget build(BuildContext context) {
  final auth = context.watch<AuthProvider>();

  if (auth.user != null) {
    return const NavScreen();
  } else {
    return const LoginScreen();
  }
}
}
