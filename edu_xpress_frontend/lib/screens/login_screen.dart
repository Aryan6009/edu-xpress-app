import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("http://10.46.51.170:5000/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text.trim()
        }),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", body["access_token"]);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Welcome back!"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.deepOrange,
          ),
        );
        Navigator.pushReplacementNamed(context, "/home");
      } else if (res.statusCode == 403) {
        // Handle unverified email
        _showVerificationDialog(emailController.text.trim());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body["error"] ?? "Login failed"),
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

  void _showVerificationDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Email Not Verified"),
        content: Text("A verification link was sent to $email. Please check your inbox (and spam folder) to activate your account."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Lottie.asset('assets/signup_anim.json', height: 200), // Using same anim for consistency
                const Text(
                  "Welcome Back",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                const Text("Login to your Edu-Xpress account", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                
                // Email Field
                TextFormField(
                  controller: emailController,
                  validator: (value) => value!.isEmpty ? "Email is required" : null,
                  decoration: _buildInputDecoration("Email Address", Icons.email_outlined),
                ),
                const SizedBox(height: 16),
                
                // Password Field
                TextFormField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  validator: (value) => value!.isEmpty ? "Password is required" : null,
                  decoration: _buildInputDecoration("Password", Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {}, // Implement forgot password later
                    child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Login Button
                GestureDetector(
                  onTap: _isLoading ? null : loginUser,
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
                        : const Text("Login", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, "/signup"),
                      child: const Text("Sign Up", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
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
