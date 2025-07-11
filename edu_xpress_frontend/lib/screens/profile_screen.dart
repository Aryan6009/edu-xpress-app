import 'package:edu_xpress_frontend/widgets/navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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
      Uri.parse("http://192.168.117.237:5000/profile"),
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

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E6),
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.deepOrange,
      ),
      drawer: const AppDrawer(),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : Column(
              children: [
                const SizedBox(height: 20),
                Lottie.asset("assets/profile_anim.json", height: 150),
                const SizedBox(height: 10),
                Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(email, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 30),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.settings, color: Colors.orange),
                    title: const Text("Settings"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Logout"),
                    onTap: logout,
                  ),
                ),
              ],
            ),
    );
  }
}
