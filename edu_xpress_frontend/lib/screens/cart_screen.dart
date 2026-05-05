import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:edu_xpress_frontend/services/live_tracking_service.dart';
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

  final String baseUrl = "http://10.184.119.237:5000";
  
  // Fixed Shop Location (e.g., Hazratganj, Lucknow)
  static const double SHOP_LAT = 26.8467;
  static const double SHOP_LNG = 80.9462;

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
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token == null) {
        if (mounted) setState(() => loading = false);
        return;
      }

      final res = await http.get(
        Uri.parse("$baseUrl/cart"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            cart = data["cart"] ?? [];
            totalAmount = cart.fold(0.0, (sum, item) {
              final price = double.tryParse(item['price'].toString()) ?? 0.0;
              final quantity = int.tryParse(item['quantity'].toString()) ?? 0;
              return sum + (price * quantity);
            });
            loading = false;
            isUpdating = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
          loading = false;
          isUpdating = false;
        });
        }
      }
    } catch (e) {
      debugPrint("Error fetching cart: $e");
      if (mounted) {
        setState(() {
          loading = false;
          isUpdating = false;
        });
      }
    }
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
        if (!mounted) return;
        setState(() => isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Update failed", textAlign: TextAlign.center),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e", textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),        ),
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
        SnackBar(
          content: const Text("🗑️ Item removed", textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),        ),
      );
      fetchCart();
    } else {
      setState(() => isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("❌ Could not remove item", textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),        ),
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
      _showSnackBar("🛒 Cart is empty!");
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    String? selectedAddr = prefs.getString("selected_address");
    String? selectedName = prefs.getString("selected_name");
    String? selectedPhone = prefs.getString("selected_phone");
    double? selectedLat = prefs.getDouble("selected_lat");
    double? selectedLng = prefs.getDouble("selected_lng");

    if (selectedAddr == null || selectedLat == null || selectedLng == null) {
      _showSnackBar("📍 Please select a delivery address first!");
      Navigator.pushNamed(context, "/addresses");
      return;
    }

    // --- POPUP: If recipient details are missing, ask for them now ---
    if (selectedName == null || selectedName.isEmpty || 
        selectedPhone == null || selectedPhone.isEmpty) {
      
      final nameCtrl = TextEditingController();
      final phoneCtrl = TextEditingController();
      
      bool? detailConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Complete Your Address"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("We need your name and phone for delivery.", style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 15),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Recipient Name", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Recipient Phone", border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                String name = nameCtrl.text.trim();
                String phone = phoneCtrl.text.trim();
                
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
                  return;
                }
                
                // --- Phone Number Validation ---
                if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("❌ Invalid phone number! Please enter exactly 10 digits."))
                  );
                  return;
                }
                
                Navigator.pop(context, true);
              },
              child: const Text("Save & Continue"),
            ),
          ],
        ),
      );

      if (detailConfirmed != true) return;

      // Save to SharedPreferences so it's remembered for the payment step
      await prefs.setString("selected_name", nameCtrl.text.trim());
      await prefs.setString("selected_phone", phoneCtrl.text.trim());
      
      // Update local variables for the rest of this function
      selectedName = nameCtrl.text.trim();
      selectedPhone = phoneCtrl.text.trim();

      // OPTIONAL: Update on backend if needed, but for now we have it locally for verification_payment call
    }

    // --- Distance Check (10km Radius) ---
    double distanceInMeters = Geolocator.distanceBetween(
      SHOP_LAT,
      SHOP_LNG,
      selectedLat,
      selectedLng,
    );

    if (distanceInMeters > 10000) { // 10km
      _showErrorDialog(
        "Out of Delivery Range",
        "Sorry, we only deliver within 10km of our shop. Your selected address is ${(distanceInMeters/1000).toStringAsFixed(1)}km away."
      );
      return;
    }

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
        _showSnackBar("❌ Could not open Razorpay");
      }
    } else {
      _showSnackBar("❌ Payment initiation failed");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    String savedAddr = prefs.getString("selected_address") ?? "";
    double savedLat = prefs.getDouble("selected_lat") ?? 0.0;
    double savedLng = prefs.getDouble("selected_lng") ?? 0.0;
    String savedName = prefs.getString("selected_name") ?? "";
    String savedPhone = prefs.getString("selected_phone") ?? "";

    TextEditingController nameController = TextEditingController(text: savedName);
    TextEditingController phoneController = TextEditingController(text: savedPhone);
    TextEditingController addressController = TextEditingController(text: savedAddr);

    if (!mounted) return;
    
    // Show dialog to collect details
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delivery Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone")),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: "Delivery Address"), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty || addressController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text("Confirm & Place Order"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading while verifying
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
    );

    try {
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
          "name": nameController.text.trim(),
          "phone": phoneController.text.trim(),
          "address": addressController.text.trim(),
          "latitude": savedLat,
          "longitude": savedLng,
        }),
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading

      if (res.statusCode == 200) {
        _showSnackBar("🎉 Payment successful and order placed!");
        
        // Start Global Live Tracking
        LiveTrackingService().startTracking(
          orderId: response.orderId ?? "ORD-${DateTime.now().millisecondsSinceEpoch}",
          lat: savedLat,
          lng: savedLng,
          address: addressController.text.trim(),
        );

        Navigator.pushReplacementNamed(
          context, 
          "/track_order",
          arguments: {
            "address": addressController.text.trim(),
            "lat": savedLat,
            "lng": savedLng,
          }
        );
      } else {
        final errorData = jsonDecode(res.body);
        _showSnackBar("❌ Verification failed: ${errorData['error'] ?? 'Unknown error'}");
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading
      _showSnackBar("❌ Connection error during verification");
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Payment Failed!", textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Wallet selected: ${response.walletName}", textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("My Cart", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.primary,
        centerTitle: true,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Lottie.asset("assets/empty_cart.json", height: 220),
                      const SizedBox(height: 20),
                      Text("Your cart is empty!", style: TextStyle(fontSize: 18, color: theme.hintColor)),
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
                          return _buildCartItem(item, theme);
                        },
                      ),
                    ),
                    const SizedBox(height: 10), // Spacing above bottom bar
                  ],
                ),
      bottomNavigationBar: _buildBottomBar(theme),
      floatingActionButton: const ChatBotFAB(),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10), // Slightly reduced padding
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Book Image (Reduced size)
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item['image'] != null
                  ? Image.network(
                      item['image'].toString().startsWith("http")
                          ? item['image']
                          : "$baseUrl/uploads/product_images/${item['image']}",
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.auto_stories, color: Colors.deepOrange, size: 25),
                    )
                  : const Icon(Icons.auto_stories, color: Colors.deepOrange, size: 25),
            ),
          ),
          const SizedBox(width: 8), // Reduced spacing
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['product_name'],
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "₹${item['price']}",
                  style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6), // Reduced spacing
          // Quantity Controls (Slightly more compact width)
          SizedBox(
            width: 95,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  IconButton(
                    onPressed: isUpdating ? null : () => updateQuantity(item['product_id'], "decrease"),
                    icon: Icon(Icons.remove, size: 14, color: theme.colorScheme.onSurface),
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    "${item['quantity']}",
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: isUpdating ? null : () => updateQuantity(item['product_id'], "increase"),
                    icon: const Icon(Icons.add, size: 14, color: Colors.deepOrange),
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4), // Reduced spacing
          // Delete Button
          IconButton(
            onPressed: isUpdating ? null : () => removeItem(item['product_id']),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 15,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Amount", style: TextStyle(color: theme.hintColor, fontSize: 13)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "₹${totalAmount.toStringAsFixed(0)}",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: ElevatedButton(
                onPressed: cart.isEmpty ? null : initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Checkout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
