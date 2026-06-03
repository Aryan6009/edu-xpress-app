import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_xpress_frontend/services/live_tracking_service.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = ModalRoute.of(context)!.settings.arguments as Map;
    final theme = Theme.of(context);
    
    // In our backend, we get individual orders. If multiple items were in one payment, 
    // they are currently returned as separate order records or we might need to handle a list.
    // Based on app.py, /orders returns a list of orders where each order is one product.
    // However, the UI expects an 'items' list. We will adapt to show the single product details if items is null.
    
    final List items = order['items'] != null 
        ? order['items'] as List 
        : [
            {
              'product_name': order['product_name'] ?? 'Unknown Book',
              'product_image': order['product_image'],
              'quantity': order['quantity'] ?? 1,
              'price': (order['total_amount'] ?? 0) / (order['quantity'] ?? 1),
            }
          ];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text("Order #ORD${order['id']}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(order, theme),
            const SizedBox(height: 25),
            const Text("Items Ordered", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item['product_image'] != null
                            ? Image.network(item['product_image'], width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.book, size: 40))
                            : const Icon(Icons.book, size: 40, color: Colors.deepOrange),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['product_name'] ?? "Book", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text("Qty: ${item['quantity']}", style: TextStyle(color: theme.hintColor, fontSize: 13)),
                          ],
                        ),
                      ),
                      Text("₹${(item['price'] ?? 0) * (item['quantity'] ?? 1)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.deepOrange.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Paid", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("₹${order['total_amount']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.deepOrange)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text("Delivery Address", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Colors.deepOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        order['address'] ?? "No address provided",
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Map order, ThemeData theme) {
    String orderIdStr = order['id'].toString();
    bool wasDeliveredThisSession = LiveTrackingService().isDeliveredLocally(orderIdStr);
    
    String status = wasDeliveredThisSession ? "Delivered" : (order['status'] ?? "Pending");
    Color statusColor = Colors.orange;
    if (status.toLowerCase() == "paid" || status.toLowerCase() == "delivered") statusColor = Colors.green;
    if (status.toLowerCase() == "cancelled") statusColor = Colors.red;

    // Use created_at instead of timestamp
    String dateStr = "N/A";
    if (order['created_at'] != null) {
      try {
        dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['created_at']));
      } catch (e) {
        dateStr = order['created_at'];
      }
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.info_outline, color: statusColor),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ORDER STATUS", style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text("Placed on $dateStr", 
                    style: TextStyle(color: statusColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
