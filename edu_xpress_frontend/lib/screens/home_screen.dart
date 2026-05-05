import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:edu_xpress_frontend/widgets/chatbot_fab.dart';

const String baseUrl = "http://10.184.119.237:5000";
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List products = [];
  List allProducts = [];
  bool loading = true;
  int cartCount = 0;
  TextEditingController searchController = TextEditingController();
  String selectedCategory = "All";
  String selectedAddress = "Select Address";
  late AnimationController _badgeController;

  List categories = ["All", "Programming", "Science", "School","Fiction","Competitive Exam"];
  
  // Timer for Flash Sale
  late Timer _countdownTimer;
  Duration _timeLeft = const Duration(hours: 2, minutes: 45, seconds: 0);

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _badgeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    fetchSelectedAddress();
    fetchProducts();
    fetchCartCount();
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _badgeController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}h ${twoDigits(d.inMinutes.remainder(60))}m ${twoDigits(d.inSeconds.remainder(60))}s";
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "All": return Icons.grid_view;
      case "Programming": return Icons.code;
      case "Science": return Icons.biotech;
      case "School": return Icons.school;
      case "Fiction": return Icons.auto_stories;
      case "Competitive Exam": return Icons.workspace_premium;
      default: return Icons.book;
    }
  }

  Future<void> fetchSelectedAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedAddress = prefs.getString("selected_address") ?? "Select Address";
    });
  }

  Future<void> fetchProducts() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/products")).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            products = body;
            allProducts = body;
            loading = false;
          });
        }
      } else {
        if (mounted) setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
      }
      debugPrint("Error fetching products: $e");
    }
  }

Map<int, int> quantities = {};

Widget buildQuantityControls(product) {

  int id = product['id'];
  int qty = quantities[id] ?? 0;

  if (qty == 0) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text("Add"),
        onPressed: () async {

          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? token = prefs.getString("token");

          if (token == null) return;

          final res = await http.post(
            Uri.parse("$baseUrl/cart/add"),
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

          if (res.statusCode == 201) {
            setState(() {
              quantities[id] = 1;
            });

            fetchCartCount();
          }
        },
      ),
    );
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [

IconButton(
  icon: const Icon(Icons.remove_circle, color: Colors.deepOrange),
  onPressed: () async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (token == null) return;

    int id = product['id'];

    final res = await http.post(
      Uri.parse("$baseUrl/cart/decrease/$id"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {

      setState(() {

        if (quantities[id]! > 1) {
          quantities[id] = quantities[id]! - 1;
        } else {
          quantities.remove(id);
        }

      });

      fetchCartCount();

    }

  },
),
      Text(
        qty.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),

      IconButton(
        icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
        onPressed: () async {

          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? token = prefs.getString("token");

          if (token == null) return;

          await http.post(
            Uri.parse("$baseUrl/cart/add"),
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

          setState(() {
            quantities[id] = qty + 1;
          });

          fetchCartCount();
        },
      ),
    ],
  );
}
  Future<void> searchProducts(String query) async {
  if (query.isEmpty) {
    fetchProducts();
    return;
  }

  try {
    final res = await http.get(
      Uri.parse("$baseUrl/search?q=$query"),
    );

    final body = jsonDecode(res.body);

    setState(() {
      products = body;
    });
  } catch (e) {
    debugPrint("Search error: $e");
  }
}

void filterByCategory(String category) {
  setState(() {
    selectedCategory = category;

    if (category == "All") {
      fetchProducts();
    } else {
   products = allProducts.where((p) {
  return (p['category'] ?? "")
      .toString()
      .toLowerCase() ==
      category.toLowerCase();
}).toList();
    }
  });
}
Future<void> fetchCartCount() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString("token");

if (token == null) {
  debugPrint("User not logged in");
  return;
}
  final res = await http.get(
    Uri.parse("$baseUrl/cart"),
    headers: {
      "Authorization": "Bearer $token",
    },
  );

  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);

    if (!mounted) return;
    setState(() {
      cartCount = 0;
      quantities.clear();
      for (var item in data["cart"]) {
        cartCount += item["quantity"] as int;
        int productId = item["product_id"] ?? 0;
        int quantity = item["quantity"] ?? 0;
        if (productId != 0) {
          quantities[productId] = quantity;
        }
      }
    });
  }
}

Widget buildShimmer() {  return GridView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 6,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.75,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemBuilder: (_, __) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        toolbarHeight: 90,
        elevation: 0,
        title: GestureDetector(
          onTap: () async {
            final result = await Navigator.pushNamed(context, "/addresses");
            if (result == true) fetchSelectedAddress();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Delivery in 15-20 mins",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.flash_on, size: 18, color: Colors.yellow[400]),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Text(
                    "To: ",
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Expanded(
                    child: Text(
                      selectedAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white70),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            onPressed: () => Navigator.pushNamed(context, "/profile"),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () async {
                  await Navigator.pushNamed(context, "/cart");
                  await fetchCartCount();
                },
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          )
        ],
      ),
      body: loading
          ? buildShimmer()
          : RefreshIndicator(
              color: Colors.deepOrange,
              onRefresh: fetchProducts,
              child: CustomScrollView(
                slivers: [
                  // ⚡ Search Bar Sticky
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.deepOrange,
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) => searchProducts(value),
                        decoration: InputDecoration(
                          hintText: "Search books, authors, genres...",
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),

                  // 🎁 Flash Sale Banner
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("FLASH SALE ⚡", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text("Ends in: ", style: TextStyle(color: Colors.white70, fontSize: 13)),
                                    Text(_formatDuration(_timeLeft), style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.deepPurple,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                    minimumSize: const Size(80, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text("GRAB NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Lottie.asset('assets/deals.json', height: 80, fit: BoxFit.contain),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 📂 Category Bubbles
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text("Shop by Category 📂", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              String category = categories[index];
                              bool isSelected = selectedCategory == category;
                              return GestureDetector(
                                onTap: () => filterByCategory(category),
                                child: Container(
                                  width: 80,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: isSelected ? Colors.deepOrange : Colors.white,
                                        child: Icon(
                                          _getCategoryIcon(category),
                                          color: isSelected ? Colors.white : Colors.deepOrange,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(category, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 📚 Product Grid
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          var product = products[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.05), offset: const Offset(0, 5))],
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        child: Image.network(
                                          product['image'].toString().startsWith("http") ? product['image'] : "$baseUrl/uploads/product_images/${product['image']}",
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => const Center(child: Icon(Icons.menu_book, size: 50)),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text("₹ ${product['price']}", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w900, fontSize: 15)),
                                          const SizedBox(height: 8),
                                          buildQuantityControls(product),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: FadeTransition(
                                    opacity: _badgeController,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                      child: const Text("BEST SELLER", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: products.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) Navigator.pushNamed(context, "/orders");
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Orders"),
        ],
      ),
      floatingActionButton: const ChatBotFAB(),
    );
  }
}