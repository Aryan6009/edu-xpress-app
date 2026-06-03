import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:edu_xpress_frontend/services/api_config.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _passwordStrength = "";
  Color _strengthColor = Colors.grey;
  
  final _formKey = GlobalKey<FormState>();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '243640116424-g2snk2o9vln6511ttovlgpuhhvg5hubc.apps.googleusercontent.com',
  );

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
    phoneController.dispose();
    otpController.dispose();
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

    String registerUrl = "${ApiConfig.baseUrl}/register";
    try {
      final res = await http.post(
        Uri.parse(registerUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": usernameController.text.trim(),
          "email": emailController.text.trim(),
          "password": passwordController.text.trim()
        }),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body);
      if (res.statusCode == 201) {
        _showSuccess(body["message"]);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showError(body["error"] ?? "Registration failed (Status: ${res.statusCode})");
      }
    } catch (e) {
      _showError("Connection error: $e\nURL: $registerUrl");
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
        Uri.parse("${ApiConfig.baseUrl}/google-login"),
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
    _showSuccess("Welcome back!");
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green[800],
        margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
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
      errorStyle: const TextStyle(color: Colors.redAccent),
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
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Lottie.asset('assets/signup_anim.json', height: 180),
                Text(
                  "Join Edu-Xpress",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create your account to start learning",
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
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
                            color: Colors.deepOrange.withOpacity(0.3),
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
                
                const SizedBox(height: 25),
                
                // --- Social Signups ---
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
                    _socialBtn("Apple", "assets/apple.png", () => _showComingSoon("Apple Signup"), isAsset: false, icon: Icons.apple),
                    _socialBtn("Phone", "assets/phone.png", _showPhoneLogin, isAsset: false, icon: Icons.phone_android),
                  ],
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
              Text(_isOTPSent ? "Verify OTP" : "Sign Up with Mobile", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                      final res = await http.post(
                        Uri.parse("${ApiConfig.baseUrl}/send-otp"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({"phone": phoneController.text.trim()}),
                      );
                      if (res.statusCode == 200) {
                        setModalState(() => _isOTPSent = true);
                        setState(() => _isOTPSent = true);
                      }
                    } else {
                      final res = await http.post(
                        Uri.parse("${ApiConfig.baseUrl}/mobile-login"),
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
                  child: Text(_isOTPSent ? "Verify & Sign Up" : "Send OTP"),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        _isOTPSent = false;
        phoneController.clear();
        otpController.clear();
      });
    });
  }
}
