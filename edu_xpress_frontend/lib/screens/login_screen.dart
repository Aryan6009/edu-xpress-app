import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '884721662496-950q8lorggjhj1l3nta469e1ijmdip7v.apps.googleusercontent.com',
  );

  final String baseUrl = "http://10.184.119.237:5000";

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text.trim()
        }),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _handleLoginSuccess(body["access_token"]);
      } else if (res.statusCode == 403) {
        _showVerificationDialog(emailController.text.trim());
      } else {
        _showError(body["error"] ?? "Login failed");
      }
    } catch (e) {
      _showError("Connection error. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final res = await http.post(
        Uri.parse("$baseUrl/google-login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id_token": googleAuth.idToken}),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _handleLoginSuccess(body["access_token"]);
      } else {
        _showError(body["error"] ?? "Google Sign-In failed");
      }
    } catch (e) {
      _showError("Google Sign-In Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLoginSuccess(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", token);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Welcome back!", textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pushReplacementNamed(context, "/home");
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
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
      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Lottie.asset('assets/signup_anim.json', height: 200),
                Text(
                  "Welcome Back",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Login to your Edu-Xpress account",
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
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
                    onPressed: () {},
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
                            color: Colors.deepOrange.withOpacity(0.3),
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
                
                const SizedBox(height: 25),
                
                // --- Social Logins ---
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.dividerColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("OR", style: TextStyle(color: theme.hintColor, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: theme.dividerColor)),
                  ],
                ),
                
                const SizedBox(height: 25),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _socialBtn("Google", "assets/google.png", _handleGoogleSignIn, isAsset: false, icon: Icons.g_mobiledata),
                    _socialBtn("Apple", "assets/apple.png", () => _showComingSoon("Apple Login"), isAsset: false, icon: Icons.apple),
                    _socialBtn("Phone", "assets/phone.png", _showPhoneLogin, isAsset: false, icon: Icons.phone_android),
                  ],
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

  Widget _socialBtn(String label, String asset, VoidCallback onTap, {bool isAsset = true, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 60,
        width: 80,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Center(
          child: icon != null 
            ? Icon(icon, size: 30, color: label == "Google" ? Colors.red : (label == "Apple" ? (isDark ? Colors.white : Colors.black) : Colors.blue))
            : Image.asset(asset, height: 30),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✨ $feature coming soon!", textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        margin: const EdgeInsets.only(bottom: 20, left: 60, right: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isOTPSent = false;

  void _showPhoneLogin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isOTPSent ? "Verify OTP" : "Login with Mobile", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_isOTPSent ? "Enter the 6-digit code sent to your phone" : "We'll send an OTP to your number", style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 25),
              if (!_isOTPSent)
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration("Phone Number", Icons.phone).copyWith(
                    prefixText: "+91 ",
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              else
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: _buildInputDecoration("Enter OTP", Icons.lock_clock_outlined),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!_isOTPSent) {
                      // Send OTP
                      final res = await http.post(
                        Uri.parse("$baseUrl/send-otp"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({"phone": phoneController.text.trim()}),
                      );
                      if (res.statusCode == 200) {
                        setModalState(() => _isOTPSent = true);
                        setState(() => _isOTPSent = true);
                      }
                    } else {
                      // Verify OTP
                      final res = await http.post(
                        Uri.parse("$baseUrl/mobile-login"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({
                          "phone": phoneController.text.trim(),
                          "otp": otpController.text.trim()
                        }),
                      );
                      final body = jsonDecode(res.body);
                      if (res.statusCode == 200) {
                        Navigator.pop(context);
                        _handleLoginSuccess(body["access_token"]);
                      } else {
                        _showError(body["error"] ?? "Invalid OTP");
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(_isOTPSent ? "Verify & Login" : "Send OTP"),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Reset state when modal closes
      setState(() {
        _isOTPSent = false;
        phoneController.clear();
        otpController.clear();
      });
    });
  }
}
