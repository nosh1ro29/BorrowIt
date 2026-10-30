import 'package:flutter/material.dart';

import '../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController(text: 'student@school.edu');
  final _pass = TextEditingController(text: '123456');

  bool _isLogin = true;
  bool _hide = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await login(_email.text.trim(), _pass.text);
      } else {
        await register(_name.text.trim(), _email.text.trim(), _pass.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = authMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyColor = Color(0xFF1E284A);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 24,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo image from assets folder
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/borrowit_logo.png',
                          width: 150,
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.image_not_supported,
                            size: 80,
                            color: BorrowColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Full name (only shown when registering)
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _name,
                          style: const TextStyle(fontSize: 14, color: navyColor),
                          decoration: _inputDecoration(
                            label: 'Full name',
                            icon: Icons.person_outline,
                          ),
                          validator: (v) => v!.trim().isEmpty ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // School email field
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 14, color: navyColor),
                        decoration: _inputDecoration(
                          label: 'School email',
                          icon: Icons.mail_outline,
                        ),
                        validator: (v) => v!.contains('@') ? null : 'Enter a valid email',
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _pass,
                        obscureText: _hide,
                        style: const TextStyle(fontSize: 14, color: navyColor),
                        decoration: _inputDecoration(
                          label: 'Password',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            splashRadius: 18,
                            icon: Icon(
                              _hide ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 19,
                              color: const Color(0xFF6B7280),
                            ),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) => v!.length < 6 ? 'At least 6 characters' : null,
                      ),

                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navyColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Toggle Register / Sign In with extra bold emphasis
                      InkWell(
                        onTap: () => setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                fontFamily: 'sans-serif',
                              ),
                              children: [
                                TextSpan(
                                  text: _isLogin
                                      ? "Don't have an account? "
                                      : "Already have an account? ",
                                ),
                                TextSpan(
                                  text: _isLogin ? "Register" : "Sign In",
                                  style: const TextStyle(
                                    color: navyColor,
                                    fontWeight: FontWeight.w800,
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
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF374151)),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFF1E284A), width: 1.5),
      ),
    );
  }
}