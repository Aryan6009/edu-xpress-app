import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

const String baseUrl = "http://10.50.236.237:5000";
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List products = [];
  List allProducts = [];
  bool loading = true;
int cartCount = 0;
TextEditingController searchController = TextEditingController();
String selectedCategory = "All";

List categories = ["All", "Programming", "Science", "School","Fiction","Competitive Exam"];
  Future<void> fetchProducts() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/products"));
      final body = jsonDecode(res.body);
      setState(() {
        products = body;
        allProducts = body;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
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
@override
void initState() {
super.initState();
fetchProducts();
fetchCartCount();
}
Widget buildShimmer() {
  return GridView.builder(
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: const Text("Edu-Xpress", style: TextStyle(color: Colors.white)),
        actions: [

/// 👤 Profile Icon
IconButton(
  icon: const Icon(Icons.account_circle, size: 28),
  onPressed: () {
    Navigator.pushNamed(context, "/profile");
  },
),

/// 🛒 Cart Icon
        Stack(
  children: [
    IconButton(
      icon: const Icon(Icons.shopping_cart),
      onPressed: () async {
 await Navigator.pushNamed(context, "/cart");
await fetchCartCount();
}
    ),

    if (cartCount > 0)
  Positioned(
    right: 6,
    top: 6,
    child: AnimatedScale(
      scale: cartCount > 0 ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: const BoxConstraints(
          minWidth: 18,
          minHeight: 18,
        ),
        child: Text(
          '$cartCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: const LinearGradient(
      colors: [
        Color(0xFFFF6A00),
        Color(0xFFFFA726),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  child: Row(
    children: [
      Icon(
        Icons.flash_on,
        color: Theme.of(context).cardColor,
        size: 40,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Delivery in 15 minutes ⚡",
              style: TextStyle(
                color: Theme.of(context).cardColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Get your books instantly with Edu-Xpress",
              style: TextStyle(
               color: Theme.of(context).cardColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),

const SizedBox(height: 16),
                  /// 🔍 Search Bar
TextField(
  controller: searchController,
  onChanged: (value) {
    searchProducts(value);
  },
  decoration: InputDecoration(
    hintText: "Search books...",
    prefixIcon: const Icon(Icons.search),
    filled: true,
    fillColor: Theme.of(context).cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
),

SizedBox(
  height: 40,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    itemCount: categories.length,
    itemBuilder: (context, index) {
      String category = categories[index];

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(category),
          selected: selectedCategory == category,
          selectedColor: Colors.deepOrange,
          backgroundColor: Theme.of(context).cardColor,
          onSelected: (_) {
            filterByCategory(category);
          },
        ),
      );
    },
  ),
),

const SizedBox(height: 16),
                  // 🎉 Deals section
                  Lottie.asset('assets/deals.json', height: 150),
                  const SizedBox(height: 10),
                  const Text(
                    "Available Books 📚",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
              
                  const SizedBox(height: 12),
                 GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: products.length,
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.75,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
  ),
  itemBuilder: (context, index) {
    var product = products[index];

    return AnimatedContainer(
  duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 📷 Product Image
            Expanded(
              child: product['image'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                     child: Image.network(
  product['image'].toString().startsWith("http")
      ? product['image']
      : "$baseUrl/uploads/product_images/${product['image']}",
  width: double.infinity,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return const Center(
      child: Icon(Icons.menu_book, size: 50),
    );
  },
),
                    )
                  : const Center(
                      child: Icon(Icons.menu_book, size: 50),
                    ),
            ),
            const SizedBox(height: 8),

            /// 📚 Product Name
            Text(
              product['name'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            /// 💰 Price
            Text(
              "₹ ${product['price']}",
              style: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Spacer(),

            /// 🛒 Add To Cart Button
           buildQuantityControls(product)
          ],
        ),
      ),
    );
  },
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
    );
  }}