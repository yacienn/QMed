import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz/core/theme/app_theme.dart';
import 'package:quiz/feature/auth/controller/auth_vm.dart';
import 'package:quiz/widgets/text_field.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final userNameController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscurePassword = true; // Add this

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.read<AuthVm>();

    return Scaffold(
      backgroundColor: AppTheme.paperBeige,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Text
                  const Text(
                    "Welcome Back!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: AppTheme.neoBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Login to continue your quiz journey",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neoBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  NeoTextField(
                    controller: userNameController,
                    label: "ENTER USERNAME",
                    prefixIcon: Icons.person_outline,
                  ),

                  const SizedBox(height: 20),

                  // Password Field with show/hide button
                  NeoTextField(
                    controller: passwordController,
                    label: "ENTER PASSWORD",
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.neoBlack,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Login Button
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final success = await authVm.login(
                          userNameController.text,
                          passwordController.text,
                        );

                        if (success && context.mounted) {
                          Navigator.pushReplacementNamed(context, "/home");
                        } else if (context.mounted) {
                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Invalid username or password"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 260,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.neoBlack,
                            width: 3.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppTheme.neoBlack,
                              offset: Offset(4, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "LOG IN",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: AppTheme.neoBlack,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sign Up Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neoBlack,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, "/sign_up"); // Fixed route name
                        },
                        child: const Text(
                          "SIGN UP",
                          style: TextStyle(
                            color: AppTheme.accentMagenta,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.underline,
                            decorationThickness: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}