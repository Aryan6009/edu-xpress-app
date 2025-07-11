import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../widgets/navigation_drawer.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List products = [];
  bool loading = true;

  Future<void> fetchProducts() async {
    try {
      final res = await http.get(Uri.parse("http://192.168.117.237:5000/products"));
      final body = jsonDecode(res.body);
      setState(() {
        products = body;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      debugPrint("Error fetching products: $e");
    }
  }

  @override
  void initState() {
    fetchProducts();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E6), // background
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: const Text("Edu-Xpress", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.pushNamed(context, "/cart"),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : RefreshIndicator(
              color: Colors.deepOrange,
              onRefresh: fetchProducts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 🎉 Deals section
                  Lottie.asset('assets/deals.json', height: 150),
                  const SizedBox(height: 10),
                  const Text(
                    "Available Books 📚",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...products.map((product) => Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.menu_book, color: Colors.white),
                          ),
                          title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("₹ ${product['price'].toString()}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_shopping_cart, color: Colors.deepOrange),
                            onPressed: () async {
                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              String? token = prefs.getString("token");

                              final res = await http.post(
                                Uri.parse("http://192.168.117.237:5000/cart/add"),
                                headers: {
                                  "Content-Type": "application/json",
                                  "Authorization": "Bearer $token",
                                },
                                body: jsonEncode({
                                  "product_id": product['id'],
                                  "product_name": product['name'],
                                  "price": product['price']
                                }),
                              );

                              final msg = jsonDecode(res.body);
                              if (res.statusCode == 201) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg["message"] ?? "Added to cart")),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg["error"] ?? "Failed to add")),
                                );
                              }
                            },
                          ),
                        ),
                      )),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) Navigator.pushNamed(context, "/orders");
          if (index == 2) Navigator.pushNamed(context, "/profile");
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Orders"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
