import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz/core/theme/app_theme.dart';
import 'package:quiz/feature/auth/controller/auth_vm.dart';
import 'package:quiz/widgets/text_field.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
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
    final authVm = context.watch<AuthVm>(); // Use watch to listen to changes

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
                  // Title
                  const Text(
                    "CREATE ACCOUNT",
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
                    "Join the quiz community!",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neoBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Error Message Display
                  if (authVm.signUpError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.shade300,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authVm.signUpError!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => authVm.clearSignUpError(),
                            child: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Username Field
                  NeoTextField(
                    controller: userNameController,
                    label: "ENTER USERNAME",
                    prefixIcon: Icons.person_outline,
                    onChanged: (_) => authVm.clearSignUpError(), // Clear error on typing
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
                    onChanged: (_) => authVm.clearSignUpError(), // Clear error on typing
                  ),
                  const SizedBox(height: 8),

                  // Password hint
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      "Password must be at least 6 characters",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.neoBlack,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign Up Button
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        // Clear previous error
                        authVm.clearSignUpError();

                        // Basic validation
                        if (userNameController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please fill in all fields"),
                              backgroundColor: AppTheme.neoBlack,
                            ),
                          );
                          return;
                        }

                        if (passwordController.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Password must be at least 6 characters"),
                              backgroundColor: AppTheme.neoBlack,
                            ),
                          );
                          return;
                        }

                        final success = await authVm.signUp(
                          userNameController.text,
                          passwordController.text,
                        );

                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Account created successfully!"),
                              backgroundColor: AppTheme.accentTeal,
                            ),
                          );
                          Navigator.pushReplacementNamed(context, "/log_in");
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
                            "SIGN UP",
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

                  // Sign In Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neoBlack,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          authVm.clearSignUpError();
                          Navigator.pushReplacementNamed(context, "/log_in");
                        },
                        child: const Text(
                          "LOG IN",
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

                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          color: AppTheme.neoBlack,
                          thickness: 2,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "OR",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.neoBlack.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: AppTheme.neoBlack,
                          thickness: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Back to Login Button
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        authVm.clearSignUpError();
                        Navigator.pushReplacementNamed(context, "/log_in");
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.neoBlack,
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppTheme.neoBlack,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: AppTheme.neoBlack,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "BACK TO LOGIN",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.neoBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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