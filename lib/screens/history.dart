import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:intl/intl.dart'; // For date formatting

import 'TrackOrderScreen.dart';

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFD32F2F);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Order History", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Active Orders"),
              Tab(text: "Past Orders"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList(DatabaseService().getActiveOrders(), primaryRed, true),
            _buildOrderList(DatabaseService().getPastOrders(), primaryRed, false),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(Stream<QuerySnapshot> stream, Color accent, bool isActive) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Something went wrong"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("No orders found", style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return _buildOrderCard(
              context: context,
              orderId: doc.id,
              restaurant: data['restaurantName'] ?? "Unknown Restaurant",
              date: data['timestamp'] != null 
                  ? DateFormat('MMM d, yyyy').format((data['timestamp'] as Timestamp).toDate())
                  : "Recently",
              status: data['status'] ?? "Pending",
              items: "${data['itemCount'] ?? 0} items",
              price: "\$${data['totalPrice']?.toStringAsFixed(2) ?? '0.00'}",
              accent: accent,
              showTrackButton: isActive,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOrderCard({
    required BuildContext context,
    required String orderId,
    required String restaurant,
    required String date,
    required String status,
    required String items,
    required String price,
    required Color accent,
    bool showTrackButton = false,
  }) {
    // Map status string to a specific color
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'preparing': statusColor = Colors.orange; break;
      case 'delivered': statusColor = Colors.green; break;
      case 'cancelled': statusColor = Colors.red; break;
      case 'on the way': statusColor = Colors.blue; break;
      default: statusColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text("$items • $date", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                Text(price, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                if (showTrackButton)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TrackOrderScreen(orderId: orderId)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Track Order"),
                  )
                else
                  OutlinedButton(
                    onPressed: () {
                      // Logic to add items back to cart would go here
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accent),
                      foregroundColor: accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Reorder"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}