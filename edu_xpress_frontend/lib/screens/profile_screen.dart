import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  String username = "";
  String email = "";
  bool loading = true;

  Future<void> fetchProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final res = await http.get(
      Uri.parse("http://10.50.236.237:5000/profile"),
      headers: {"Authorization": "Bearer $token"},
    );

    final data = jsonDecode(res.body);

    setState(() {
      username = data["username"];
      email = data["email"];
      loading = false;
    });
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, "/login");
  }

Widget quickButton(IconData icon, String text, VoidCallback onTap) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center)
          ],
        ),
      ),
    ),
  );
}

Widget listItem(IconData icon, String text, VoidCallback onTap) {
  return ListTile(
    leading: Icon(icon),
    title: Text(text),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    onTap: onTap,
  );
}

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [

                    /// PROFILE HEADER
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          child: Icon(Icons.person, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(username,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(
  email,
  style: TextStyle(
    color: Theme.of(context).textTheme.bodyMedium!.color,
  ),
)
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// QUICK OPTIONS
                Row(
  children: [
    quickButton(
      Icons.shopping_bag_outlined,
      "Your\nOrders",
      () => Navigator.pushNamed(context, "/orders"),
    ),
    quickButton(
      Icons.chat_bubble_outline,
      "Help &\nSupport",
      () {},
    ),
    quickButton(
      Icons.favorite_border,
      "Your\nWishlist",
      () {},
    ),
  ],
),

                    const SizedBox(height: 20),

                    /// WALLET CARD
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Edu-Xpress Cash",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text("Available Balance ₹0"),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            child: const Text("Add Balance"),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// INFORMATION TITLE
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Your Information",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// INFORMATION LIST
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                       listItem(Icons.currency_rupee, "Your Refunds", () {}),
listItem(Icons.favorite_border, "Your Wishlist", () {}),
listItem(Icons.card_giftcard, "E-Gift Cards", () {}),
listItem(Icons.support_agent, "Help & Support", () {}),
listItem(Icons.location_on_outlined, "Saved Addresses", () {}),
listItem(Icons.person_outline, "Profile", () {}),
listItem(Icons.card_giftcard_outlined, "Rewards", () {}),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// THEME SWITCH
                    Card(
                      child: SwitchListTile(
                        title: const Text("Dark Mode"),
                        value: widget.isDark,
                        onChanged: (val) {
                          widget.toggleTheme(val);
                        },
                        secondary: const Icon(Icons.dark_mode),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// LOGOUT
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text("Logout"),
                        onTap: logout,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}