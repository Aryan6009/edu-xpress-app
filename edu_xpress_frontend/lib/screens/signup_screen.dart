import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lottie/lottie.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _passwordStrength = "";
  Color _strengthColor = Colors.grey;
  
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    passwordController.removeListener(_checkPasswordStrength);
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    String p = passwordController.text;
    if (p.isEmpty) {
      setState(() {
        _passwordStrength = "";
        _strengthColor = Colors.grey;
      });
      return;
    }

    int strength = 0;
    if (p.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(p)) strength++;
    if (RegExp(r'\d').hasMatch(p)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p)) strength++;

    setState(() {
      if (strength <= 1) {
        _passwordStrength = "Weak";
        _strengthColor = Colors.red;
      } else if (strength == 2) {
        _passwordStrength = "Medium";
        _strengthColor = Colors.orange;
      } else if (strength == 3) {
        _passwordStrength = "Strong";
        _strengthColor = Colors.blue;
      } else {
        _passwordStrength = "Very Strong";
        _strengthColor = Colors.green;
      }
    });
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("http://10.46.51.170:5000/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": usernameController.text.trim(),
          "email": emailController.text.trim(),
          "password": passwordController.text.trim()
        }),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body["message"]),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.deepOrange,
          ),
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body["error"] ?? "Registration failed"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Connection error. Please try again."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrange,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.deepOrange),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.deepOrange, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Lottie.asset('assets/signup_anim.json', height: 180),
                const Text(
                  "Join Edu-Xpress",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                const Text("Create your account to start learning", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                
                // Username Field
                TextFormField(
                  controller: usernameController,
                  validator: (value) => value!.length < 3 ? "Enter a valid username" : null,
                  decoration: _buildInputDecoration("Username", Icons.person_outline),
                ),
                const SizedBox(height: 16),
                
                // Email Field
                TextFormField(
                  controller: emailController,
                  validator: (value) => !RegExp(r"[^@]+@[^@]+\.[^@]+").hasMatch(value!) ? "Enter a valid email" : null,
                  decoration: _buildInputDecoration("Email Address", Icons.email_outlined),
                ),
                const SizedBox(height: 16),
                
                // Password Field
                TextFormField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  validator: (value) => value!.length < 8 ? "Minimum 8 characters required" : null,
                  decoration: _buildInputDecoration("Password", Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                
                // Password Strength Indicator
                if (_passwordStrength.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Row(
                      children: [
                        const Text("Strength: ", style: TextStyle(fontSize: 12)),
                        Text(_passwordStrength, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _strengthColor)),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 30),
                
                // Signup Button
                GestureDetector(
                  onTap: _isLoading ? null : registerUser,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 55,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.orange[200] : Colors.deepOrange,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        if (!_isLoading)
                          BoxShadow(
                            color: Colors.deepOrange.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?"),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, "/login"),
                      child: const Text("Login", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
