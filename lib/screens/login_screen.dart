import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'nav_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool canLogin = false;
  bool isPasswordVisible = false;

  void _validate() {
    setState(() {
      canLogin = usernameCtrl.text.isNotEmpty && passwordCtrl.text.isNotEmpty;
    });
  }

  @override
  void initState() {
    super.initState();
    usernameCtrl.addListener(_validate);
    passwordCtrl.addListener(_validate);
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: Stack(
        children: [
          /// BACKGROUND
          Container(
            height: size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF60A5FA), Color(0xFF1E3A8A)],
              ),
            ),
          ),

          /// CONTENT
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// LOGO
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Image.asset('assets/images/logo.png', height: 42),
                  ),

                  const SizedBox(height: 28),

                  /// LOGIN CARD
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _inputField(
                          controller: usernameCtrl,
                          hint: 'Phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _inputField(
                          controller: passwordCtrl,
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        const SizedBox(height: 22),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: canLogin && !auth.isLoading
                                ? () async {
                                    await context.read<AuthProvider>().login(
                                      usernameCtrl.text,
                                      passwordCtrl.text,
                                    );

                                    final updatedAuth = context
                                        .read<AuthProvider>();

                            
                                    if (updatedAuth.error != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(updatedAuth.error!),
                                        ),
                                      );
                                    }
                                    
                                    else {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const NavScreen(),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              disabledBackgroundColor: AppColors.buttonDisabled,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// LOADING OVERLAY
          if (auth.isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? !isPasswordVisible : obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint),
          prefixIcon: Icon(icon, color: AppColors.iconSecondary),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}
