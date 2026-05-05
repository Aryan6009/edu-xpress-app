import 'package:edu_xpress_frontend/services/live_tracking_service.dart';
import 'package:edu_xpress_frontend/widgets/navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:edu_xpress_frontend/widgets/chatbot_fab.dart';

const String baseUrl = "http://10.184.119.237:5000";

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List orders = [];
  bool loading = true;

  Future<void> fetchOrders() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token == null) {
        if (mounted) setState(() => loading = false);
        return;
      }

      final res = await http.get(
        Uri.parse("$baseUrl/orders"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            orders = (data["orders"] ?? []).reversed.toList(); // Newest first
            loading = false;
          });
        }
      } else {
        if (mounted) setState(() => loading = false);
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetchOrders();
    // Listen to tracking service to refresh UI if needed
    LiveTrackingService().addListener(_onTrackingUpdate);
  }

  void _onTrackingUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LiveTrackingService().removeListener(_onTrackingUpdate);
    super.dispose();
  }

  String formatDate(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return "${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return timestamp;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid': return Colors.blue;
      case 'confirmed': return Colors.orange;
      case 'delivered': return Colors.green;
      case 'picked up': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeOrder = LiveTrackingService().activeOrder;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Order History", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: fetchOrders,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
            : orders.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      // Check if this is the active order being simulated
                      bool isActive = activeOrder != null && index == 0; // Simplified for demo
                      String displayStatus = isActive ? activeOrder.status : order['status'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Order #ORD${order['id']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(formatDate(order['created_at']), style: TextStyle(color: theme.hintColor, fontSize: 12)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(displayStatus).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      displayStatus.toUpperCase(),
                                      style: TextStyle(color: _getStatusColor(displayStatus), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Container(
                                    height: 50,
                                    width: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.book, color: Colors.deepOrange),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Total: ₹${order['total_amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text("${order['quantity']} Item(s)", style: TextStyle(color: theme.hintColor, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  if (displayStatus.toLowerCase() != 'delivered')
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context, 
                                          "/track_order",
                                          arguments: {
                                            "address": order['address'] ?? "Delivery Address",
                                            "lat": order['latitude'] ?? 26.8467,
                                            "lng": order['longitude'] ?? 80.9462,
                                          }
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        minimumSize: const Size(80, 36),
                                        backgroundColor: Colors.deepOrange,
                                      ),
                                      child: const Text("Track", style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: const ChatBotFAB(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset("assets/no_orders.json", height: 220),
          const SizedBox(height: 20),
          const Text("No orders yet!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Your past orders will appear here.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
