import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:edu_xpress_frontend/widgets/chatbot_fab.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List cart = [];
  double totalAmount = 0;
  late Razorpay _razorpay;
  bool loading = true;
  bool isUpdating = false; // Loading state for quantity updates

  final String baseUrl = "http://10.46.51.170:5000";

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    fetchCart();
  }

  Future<void> fetchCart() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final res = await http.get(
      Uri.parse("$baseUrl/cart"),
      headers: {"Authorization": "Bearer $token"},
    );

    final data = jsonDecode(res.body);
    setState(() {
      cart = data["cart"] ?? [];
      totalAmount = cart.fold(0, (sum, item) => sum + item['price'] * item['quantity']);
      loading = false;
      isUpdating = false;
    });
  }

  // --- Quantity Control Actions ---

  Future<void> updateQuantity(int productId, String action) async {
    setState(() => isUpdating = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (token == null) return;

    try {
      final url = action == "increase"
          ? "$baseUrl/cart/add"
          : "$baseUrl/cart/decrease/$productId";

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: action == "increase"
            ? jsonEncode({
                "product_id": productId,
                "product_name": "placeholder", // Backend handles existing items
                "price": 0 // Backend handles existing items
              })
            : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchCart();
      } else {
        setState(() => isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Update failed"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } catch (e) {
      setState(() => isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrange,
        ),
      );
    }
  }

  Future<void> removeItem(int itemId) async {
    setState(() => isUpdating = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final res = await http.delete(
      Uri.parse("$baseUrl/cart/remove/$itemId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🗑️ Item removed"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrange,
        ),
      );
      fetchCart();
    } else {
      setState(() => isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Could not remove item"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrange,
        ),
      );
    }
  }

  // --- Razorpay & Payment Logic (Untouched Logic) ---

  Map<String, dynamic> buildRazorpayOptions({
    required int amount,
    String? orderId,
    String title = "Edu-Xpress",
    String description = "Book Order Payment",
  }) {
    return {
      'key': 'rzp_test_FTDi97Hi0qWYoH',
      'amount': amount,
      'currency': 'INR',
      'name': title,
      'description': description,
      if (orderId != null) 'order_id': orderId,
      'prefill': {
        'contact': '6307835749',
        'email': 'test@razorpay.com',
      },
      'theme': {
        'color': '#FF5722',
        'hide_topbar': false,
      }
    };
  }

  Future<void> initiatePayment() async {
    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🛒 Cart is empty!"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Lottie.asset("assets/payment_loader.json", height: 140),
      ),
    );

    final res = await http.post(
      Uri.parse("$baseUrl/create_order"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({"amount": totalAmount}),
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      var options = buildRazorpayOptions(
        amount: (totalAmount * 100).toInt(),
        orderId: data['order_id'],
      );
      try {
        _razorpay.open(options);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Could not open Razorpay"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Payment initiation failed"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrange,
        ),
      );
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();
    TextEditingController addressController = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Delivery Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone")),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: "Address")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final res = await http.post(
      Uri.parse("$baseUrl/verify_payment"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({
        "razorpay_payment_id": response.paymentId,
        "razorpay_order_id": response.orderId,
        "razorpay_signature": response.signature,
        "name": nameController.text,
        "phone": phoneController.text,
        "address": addressController.text,
      }),
    );

    if (!mounted) return;
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment successful and order placed!"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrange,
        ),
      );
      Navigator.pushReplacementNamed(context, "/orders");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment verification failed"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrange,
        ),
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Payment Failed!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Wallet selected: ${response.walletName}"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Modern subtle background
      appBar: AppBar(
        title: const Text("My Cart", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset("assets/empty_cart.json", height: 220),
                      const SizedBox(height: 20),
                      const Text("Your cart is empty!", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          final item = cart[index];
                          return _buildCartItem(item);
                        },
                      ),
                    ),
                    const SizedBox(height: 10), // Spacing above bottom bar
                  ],
                ),
      bottomNavigationBar: _buildBottomBar(),
      floatingActionButton: const ChatBotFAB(),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Book Image
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item['image'] != null
                  ? Image.network(
                      item['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.auto_stories, color: Colors.deepOrange, size: 30),
                    )
                  : const Icon(Icons.auto_stories, color: Colors.deepOrange, size: 30),
            ),
          ),
          const SizedBox(width: 16),
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "₹${item['price']}",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          // Quantity Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: isUpdating ? null : () => updateQuantity(item['product_id'], "decrease"),
                  icon: const Icon(Icons.remove, size: 18, color: Colors.black87),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    "${item['quantity']}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  onPressed: isUpdating ? null : () => updateQuantity(item['product_id'], "increase"),
                  icon: const Icon(Icons.add, size: 18, color: Colors.deepOrange),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Delete Button
          IconButton(
            onPressed: isUpdating ? null : () => removeItem(item['product_id']),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          )
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 15,
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Amount", style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(
                  "₹${totalAmount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: cart.isEmpty ? null : initiatePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("Checkout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
