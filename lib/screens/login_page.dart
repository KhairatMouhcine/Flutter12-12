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

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return "Email requis";
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!regex.hasMatch(value)) return "Email invalide";
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Mot de passe requis";
    if (value.length < 6) return "Au moins 6 caractères";
    return null;
  }

  void _showSnackbar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      _showSnackbar(
        "Connexion réussie !",
        const Color(0xFF4ade80),
        Icons.check_circle,
      );
      Navigator.pushReplacementNamed(context, "/home");
    } on FirebaseAuthException catch (e) {
      final msg =
          {
            "user-not-found": "Utilisateur non trouvé.",
            "wrong-password": "Mot de passe incorrect.",
            "invalid-email": "Format d'email invalide.",
            "user-disabled": "Compte désactivé.",
          }[e.code] ??
          "Une erreur est survenue.";

      _showSnackbar(msg, Colors.red[700]!, Icons.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e27),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0a0e27), Color(0xFF1a1f3a)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo avec glow
                  _buildLogo(),

                  const SizedBox(height: 40),

                  // Formulaire
                  _buildFormCard(),

                  const SizedBox(height: 30),

                  // Footer
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF667eea).withOpacity(0.3),
                const Color(0xFF764ba2).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Image.asset(
              "assets/images/logo.png",
              height: 70,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.apps, size: 70, color: Colors.white);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Bienvenue",
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Connectez-vous pour continuer",
          style: TextStyle(color: Colors.grey[500], fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF667eea).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email
            _buildTextField(
              controller: _emailController,
              label: "Email",
              hint: "votre@email.com",
              icon: Icons.email_outlined,
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 20),

            // Password
            _buildTextField(
              controller: _passwordController,
              label: "Mot de passe",
              hint: "••••••••",
              icon: Icons.lock_outline,
              validator: _validatePassword,
              obscureText: !_passwordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF667eea),
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),

            const SizedBox(height: 12),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Implement forgot password
                },
                child: Text(
                  "Mot de passe oublié ?",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Login Button
            _buildLoginButton(),

            const SizedBox(height: 24),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[700])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text("ou", style: TextStyle(color: Colors.grey[500])),
                ),
                Expanded(child: Divider(color: Colors.grey[700])),
              ],
            ),

            const SizedBox(height: 24),

            // Register Link
            _buildRegisterLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF667eea), size: 22),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF0a0e27),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: const Color(0xFF667eea).withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _login,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _isLoading ? Colors.grey[700] : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Text(
                      "Se connecter",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, "/register"),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_outlined, color: Color(0xFF667eea), size: 20),
            SizedBox(width: 10),
            Text(
              "Créer un compte",
              style: TextStyle(
                color: Color(0xFF667eea),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          "© 2024 EMSI - Lab 3",
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIcon(Icons.language),
            const SizedBox(width: 16),
            _buildSocialIcon(Icons.help_outline),
            const SizedBox(width: 16),
            _buildSocialIcon(Icons.info_outline),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.2)),
      ),
      child: Icon(icon, color: Colors.grey[500], size: 20),
    );
  }
}
