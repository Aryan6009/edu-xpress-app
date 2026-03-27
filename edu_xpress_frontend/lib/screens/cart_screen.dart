import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';

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

  final String baseUrl = "http://10.50.236.237:5000"; 

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
   backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Your Cart"),
        backgroundColor: Colors.deepOrange,
      ),
    body: loading
    ? const Center(
        child: CircularProgressIndicator(color: Colors.deepOrange),
      )
    : cart.isEmpty
        ? Center(
            child: Lottie.asset("assets/empty_cart.json", height: 220),
          )
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    final item = cart[index];

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 6,
                            color: Colors.black12,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.menu_book,
                          color: Colors.deepOrange,
                          size: 32,
                        ),
                        title: Text(
                          item['product_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "₹${item['price']} • Qty ${item['quantity']}",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => removeItem(item['product_id'])
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
                
      bottomNavigationBar: Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    boxShadow: const [
      BoxShadow(
        blurRadius: 10,
        color: Colors.black12,
        offset: Offset(0, -2),
      )
    ],
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total",
            style: TextStyle(fontSize: 14),
          ),
          Text(
            "₹${totalAmount.toStringAsFixed(0)}",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
      ElevatedButton(
        onPressed: initiatePayment,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 14,
          ),
        ),
        child: const Text("Checkout"),
      )
    ],
  ),
),
    );
  }
}
