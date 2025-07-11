import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
import '../widgets/navigation_drawer.dart';

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

  final String baseUrl = "http://192.168.117.237:5000"; 

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
    cart = data["cart"] ?? [];
    totalAmount = cart.fold(0, (sum, item) => sum + item['price'] * item['quantity']);
    setState(() => loading = false);
  }

  Future<void> removeItem(int itemId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final res = await http.delete(
      Uri.parse("$baseUrl/cart/remove/$itemId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      Fluttertoast.showToast(msg: "🗑️ Item removed");
      fetchCart();
    } else {
      Fluttertoast.showToast(msg: "❌ Could not remove item");
    }
  }

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
      Fluttertoast.showToast(msg: "🛒 Cart is empty!");
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

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

    Navigator.of(context, rootNavigator: true).pop(); // close loader

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      var options = buildRazorpayOptions(
        amount: (totalAmount * 100).toInt(),
        orderId: data['order_id'],
      );
      try {
        _razorpay.open(options);
      } catch (e) {
        Fluttertoast.showToast(msg: "❌ Could not open Razorpay");
      }
    } else {
      Fluttertoast.showToast(msg: "❌ Payment initiation failed");
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();
    TextEditingController addressController = TextEditingController();

    // 📋 Ask for delivery details
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

    if (res.statusCode == 200) {
      Fluttertoast.showToast(msg: "Payment successful and order placed!");
      Navigator.pushReplacementNamed(context, "/orders");
    } else {
      Fluttertoast.showToast(msg: "Payment verification failed");
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    Fluttertoast.showToast(msg: "Payment Failed!");
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    Fluttertoast.showToast(msg: "Wallet selected: ${response.walletName}");
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: const Text("Your Cart"),
        backgroundColor: Colors.deepOrange,
      ),
      drawer: const AppDrawer(),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : cart.isEmpty
              ? Center(child: Lottie.asset("assets/empty_cart.json", height: 220))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          final item = cart[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const Icon(Icons.book, color: Colors.deepOrange),
                              title: Text(item['product_name']),
                              subtitle: Text("₹ ${item['price']} x ${item['quantity']}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => removeItem(item['id']),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Total Amount:",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("₹ $totalAmount",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: initiatePayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              minimumSize: const Size.fromHeight(45),
                            ),
                            icon: const Icon(Icons.payment),
                            label: const Text("Pay with Razorpay", style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
    );
  }
}
