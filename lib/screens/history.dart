import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart';

import 'TrackOrderScreen.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late LanguageProvider lp; // Declare it here

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This runs whenever the context is ready or changes
    lp = Provider.of<LanguageProvider>(context);
  }
  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFD32F2F);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title:  Text(lp.getText('order_history'), style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
             Tab(text: lp.getText('active_orders')),
               Tab(text: lp.getText('past_orders')),
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
        if (snapshot.hasError) return Center(child: Text(lp.getText('error_something_wrong')));
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
                Text(lp.getText('no_orders'), style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            // Localize the "items" string
            String itemsCount = "${data['itemCount'] ?? 0} ${lp.getText('items_label')}";
            return _buildOrderCard(
              context: context,
              orderId: doc.id,
              restaurant: data['restaurantName'] ??lp.getText('unknown_restaurant'),
              date: data['timestamp'] != null 
                  ? DateFormat('MMM d, yyyy').format((data['timestamp'] as Timestamp).toDate())
                 : lp.getText('recently'),
              status: data['status'] ?? "Pending",
              items: itemsCount,
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
    String statusText;
 // Localize Statuses
    switch (status.toLowerCase()) {
      case 'preparing': 
        statusColor = Colors.orange; 
        statusText = lp.getText('status_preparing');
        break;
      case 'delivered': 
        statusColor = Colors.green; 
        statusText = lp.getText('status_delivered');
        break;
      case 'cancelled': 
        statusColor = Colors.red; 
        statusText = lp.getText('status_cancelled');
        break;
      case 'on the way': 
        statusColor = Colors.blue; 
        statusText = lp.getText('status_on_way');
        break;
      default: 
        statusColor = Colors.grey;
        statusText = status;
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
                    child:  Text(lp.getText('track_order')),
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
                    child:  Text(lp.getText('reorder')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}