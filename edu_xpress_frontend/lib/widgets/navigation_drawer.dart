import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFFEBD6),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.deepOrange,
            ),
            child: Column(
              children: [
                Lottie.asset("assets/drawer_anim.json", height: 70),
                const SizedBox(height: 10),
                const Text(
                  "Edu-Xpress",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.deepOrange),
            title: const Text('Home'),
            onTap: () => Navigator.pushReplacementNamed(context, "/home"),
          ),
          ListTile(
            leading: const Icon(Icons.search, color: Colors.deepOrange),
            title: const Text('Search'),
            onTap: () => Navigator.pushReplacementNamed(context, "/search"),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart, color: Colors.deepOrange),
            title: const Text('Cart'),
            onTap: () => Navigator.pushReplacementNamed(context, "/cart"),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.deepOrange),
            title: const Text('Orders'),
            onTap: () => Navigator.pushReplacementNamed(context, "/orders"),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.deepOrange),
            title: const Text('Profile'),
            onTap: () => Navigator.pushReplacementNamed(context, "/profile"),
          ),
          const Divider(thickness: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () => logout(context),
          ),
        ],
      ),
    );
  }
}
