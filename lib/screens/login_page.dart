import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _passwordVisible = false;
  bool _isLoading = false;

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return "Email required";
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!regex.hasMatch(value)) return "Invalid email";
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password required";
    if (value.length < 6) return "At least 6 characters";
    return null;
  }

  // Custom snackbar
  void _showSnackbar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color.withOpacity(0.9),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // Login logic
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      _showSnackbar("Login successful!", Colors.green, Icons.check_circle);

      Navigator.pushReplacementNamed(context, "/home");
    } on FirebaseAuthException catch (e) {
      final msg =
          {
            "user-not-found": "No user found.",
            "wrong-password": "Incorrect password.",
            "invalid-email": "Invalid email format.",
            "user-disabled": "Account disabled.",
          }[e.code] ??
          "An unexpected error occurred.";

      _showSnackbar(msg, Colors.redAccent, Icons.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Glow input style
  InputDecoration _glowInput({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.tealAccent),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(.07),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.tealAccent.withOpacity(.4),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.tealAccent, width: 1.8),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF0A0F14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // LOGO WITH GLOW
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.tealAccent.withOpacity(.3),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.tealAccent.withOpacity(.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset("assets/images/logo.png", height: 120),
                ),

                const SizedBox(height: 40),

                // FORM CARD
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(.1),
                      width: 1,
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // TITLE
                        const Text(
                          "Login",
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 25),

                        // EMAIL
                        TextFormField(
                          controller: _emailController,
                          validator: _validateEmail,
                          style: const TextStyle(color: Colors.white),
                          decoration: _glowInput(
                            label: "Email",
                            icon: Icons.email,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // PASSWORD
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          validator: _validatePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: _glowInput(
                            label: "Password",
                            icon: Icons.lock,
                            suffix: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.tealAccent,
                              ),
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // LOGIN BUTTON (GRADIENT)
                        GestureDetector(
                          onTap: _isLoading ? null : _login,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.tealAccent, Colors.teal],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.tealAccent.withOpacity(.4),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.lock_open,
                                          color: Colors.black,
                                          size: 22,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          "LOGIN",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // REGISTER LINK (badge style)
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, "/register"),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.tealAccent.withOpacity(.5),
                              ),
                            ),
                            child: const Text(
                              "Create an account",
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
