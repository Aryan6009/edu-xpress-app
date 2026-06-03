import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_xpress_frontend/services/api_config.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool isLoading = false;
  int quantity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialQuantity();
    });
  }

  Future<void> _fetchInitialQuantity() async {
    final product = ModalRoute.of(context)!.settings.arguments as Map;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/cart"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final cartItems = data["cart"] as List;
        final item = cartItems.firstWhere(
          (i) => i['product_id'] == product['id'],
          orElse: () => null,
        );
        if (item != null && mounted) {
          setState(() {
            quantity = item['quantity'];
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch quantity error: $e");
    }
  }

  Future<void> _updateQuantity(Map product, bool increase) async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please login to manage cart")),
        );
      }
      setState(() => isLoading = false);
      return;
    }

    try {
      final url = increase
          ? "${ApiConfig.baseUrl}/cart/add"
          : "${ApiConfig.baseUrl}/cart/decrease/${product['id']}";

      final response = increase
          ? await http.post(
              Uri.parse(url),
              headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $token",
              },
              body: jsonEncode({
                "product_id": product['id'],
                "product_name": product['name'],
                "price": product['price']
              }),
            )
          : await http.post(
              Uri.parse(url),
              headers: {"Authorization": "Bearer $token"},
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          if (increase) {
            quantity++;
          } else {
            if (quantity > 0) quantity--;
          }
        });
      }
    } catch (e) {
      debugPrint("Update quantity error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = ModalRoute.of(context)!.settings.arguments as Map;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () {
                  final imageUrl = product['image'] != null
                      ? (product['image'].toString().startsWith("http")
                          ? product['image']
                          : "${ApiConfig.baseUrl}/uploads/product_images/${product['image']}")
                      : "";
                  if (imageUrl.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            iconTheme: const IconThemeData(color: Colors.white),
                          ),
                          body: Center(
                            child: InteractiveViewer(
                              child: Hero(
                                tag: 'product-${product['id']}',
                                child: Image.network(imageUrl),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Hero(
                  tag: 'product-${product['id']}',
                  child: Image.network(
                    product['image'] != null
                        ? (product['image'].toString().startsWith("http")
                            ? product['image']
                            : "${ApiConfig.baseUrl}/uploads/product_images/${product['image']}")
                        : "",
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Center(
                      child: Icon(Icons.auto_stories, size: 100, color: Colors.deepOrange),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product['name'],
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        "₹${product['price']}",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product['category'] ?? "General",
                          style: const TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Product Metadata Section
                  if (product['author'] != null || product['isbn'] != null || product['brand'] != null) ...[
                    const Text("Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (product['author'] != null) _buildDetailRow("Author", product['author']),
                    if (product['isbn'] != null) _buildDetailRow("ISBN", product['isbn']),
                    if (product['brand'] != null) _buildDetailRow("Brand", product['brand']),
                    if (product['specifications'] != null) _buildDetailRow("Specs", product['specifications']),
                    const SizedBox(height: 20),
                  ],

                  const Text(
                    "Description",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product['description'] ?? "No description available for this book. It's a great read though!",
                    style: TextStyle(color: theme.hintColor, height: 1.5, fontSize: 15),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: isLoading
            ? const Center(heightFactor: 1, child: CircularProgressIndicator())
            : quantity == 0
                ? ElevatedButton(
                    onPressed: () => _updateQuantity(product, true),
                    child: const Text("Add to Cart"),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _updateQuantity(product, false),
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.deepOrange, size: 32),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          quantity.toString(),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _updateQuantity(product, true),
                        icon: const Icon(Icons.add_circle_outline, color: Colors.deepOrange, size: 32),
                      ),
                    ],
                  ),
      ),
    );
  }
}
