import 'package:flutter/material.dart';

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
            _buildActiveOrders(primaryRed),
            _buildPastOrders(primaryRed),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrders(Color accent) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOrderCard(
          restaurant: "Pizza Paradise",
          date: "Just now",
          status: "Preparing",
          statusColor: Colors.orange,
          items: "2 items",
          price: "\$55.80",
          showTrackButton: true,
          accent: accent,
        ),
      ],
    );
  }

  Widget _buildPastOrders(Color accent) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOrderCard(
          restaurant: "Burger Bros",
          date: "Feb 25, 2026",
          status: "Delivered",
          statusColor: Colors.green,
          items: "3 items",
          price: "\$42.50",
          accent: accent,
        ),
        _buildOrderCard(
          restaurant: "Sushi Station",
          date: "Feb 23, 2026",
          status: "Delivered",
          statusColor: Colors.green,
          items: "4 items",
          price: "\$68.20",
          accent: accent,
        ),
        _buildOrderCard(
          restaurant: "Taco Town",
          date: "Feb 18, 2026",
          status: "Cancelled",
          statusColor: Colors.red,
          items: "1 item",
          price: "\$15.00",
          accent: accent,
        ),
      ],
    );
  }

  Widget _buildOrderCard({
    required String restaurant,
    required String date,
    required String status,
    required Color statusColor,
    required String items,
    required String price,
    required Color accent,
    bool showTrackButton = false,
  }) {
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
                    onPressed: () {},
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
                    onPressed: () {},
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