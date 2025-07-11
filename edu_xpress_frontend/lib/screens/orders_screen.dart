import 'package:edu_xpress_frontend/widgets/navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List orders = [];
  bool loading = true;

  Future<void> fetchOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final res = await http.get(
      Uri.parse("http://192.168.117.237:5000/orders"),
      headers: {"Authorization": "Bearer $token"},
    );

    final data = jsonDecode(res.body);
    setState(() {
      orders = data["orders"];
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  String formatDate(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E6),
      appBar: AppBar(
        title: const Text("Your Orders"),
        backgroundColor: Colors.deepOrange,
      ),
      drawer: const AppDrawer(),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : orders.isEmpty
              ? Center(child: Lottie.asset("assets/no_orders.json", height: 200))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                      child: ListTile(
                        leading: const Icon(Icons.receipt, color: Colors.deepOrange),
                        title: Text("₹ ${order['total_amount']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Date: ${formatDate(order['created_at'])}"),
                            Text("Status: ${order['status']}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
