import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_xpress_frontend/widgets/chatbot_fab.dart';
import 'package:edu_xpress_frontend/services/api_config.dart';

class ProfileScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const ProfileScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String username = "User";
  String email = "";
  bool loading = true;

  Future<void> fetchProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token == null) {
        if (mounted) {
          setState(() => loading = false);
        }
        return;
      }

      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/profile"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            username = data["username"] ?? "User";
            email = data["email"] ?? "";
            loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => loading = false);
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  Widget quickButton(IconData icon, String text, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Colors.deepOrange),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget listItem(IconData icon, String text, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.deepOrange),
      title: Text(text),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✨ $feature feature coming soon!", textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        margin: const EdgeInsets.only(bottom: 20, left: 60, right: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showProfileDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Profile Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _detailRow(Icons.person, "Username", username),
            _detailRow(Icons.email, "Email", email),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              child: const Text("Close", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepOrange),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Settings"),
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // PROFILE HEADER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.deepOrange,
                          child: Icon(Icons.person, size: 40, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(username,
                                  style: const TextStyle(
                                      fontSize: 22, fontWeight: FontWeight.bold)),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: TextStyle(color: theme.hintColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // QUICK OPTIONS
                  Row(
                    children: [
                      quickButton(
                        Icons.shopping_bag_outlined,
                        "Orders",
                        () => Navigator.pushNamed(context, "/orders"),
                      ),
                      quickButton(
                        Icons.chat_bubble_outline,
                        "Support",
                        () => Navigator.pushNamed(context, "/chat"),
                      ),
                      quickButton(
                        Icons.favorite_border,
                        "Wishlist",
                        () => _showComingSoon("Wishlist"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // WALLET CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.deepOrange, Colors.orange]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Edu-Xpress Cash",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text("Balance: ₹0", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => _showComingSoon("Wallet"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepOrange,
                            minimumSize: const Size(100, 40),
                          ),
                          child: const Text("Add"),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Your Information",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    child: Column(
                      children: [
                        listItem(Icons.currency_rupee, "Your Refunds", () => _showComingSoon("Refunds")),
                        listItem(Icons.card_giftcard, "E-Gift Cards", () => _showComingSoon("Gift Cards")),
                        listItem(Icons.support_agent, "Help & Support", () => Navigator.pushNamed(context, "/chat")),
                        listItem(Icons.location_on_outlined, "Saved Addresses", () => Navigator.pushNamed(context, "/addresses")),
                        listItem(Icons.person_outline, "Profile Details", _showProfileDetails),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Settings",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text("Dark Mode"),
                          value: widget.isDark,
                          onChanged: (val) {
                            widget.toggleTheme(val);
                          },
                          secondary: const Icon(Icons.dark_mode, color: Colors.deepOrange),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text("Logout", style: TextStyle(color: Colors.red)),
                          onTap: logout,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: const ChatBotFAB(),
    );
  }
}