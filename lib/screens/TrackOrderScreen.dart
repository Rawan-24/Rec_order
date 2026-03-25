import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
 //Done

class TrackOrderScreen extends StatefulWidget {
  final String orderId; 
  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Track Order",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: DatabaseService().getOrderStream(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Order not found or was deleted."));
          }

          var orderData = snapshot.data!.data() as Map<String, dynamic>;
          String status = orderData['status'] ?? "Pending";
          double total = (orderData['totalPrice'] as num).toDouble();
          String orderNumber = orderData['orderNumber'] ?? "N/A";
          List items = orderData['items'] ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildVoiceHeader(),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildArrivalCard(status),
                      const SizedBox(height: 20),
                      _buildMapSection(),
                      const SizedBox(height: 20),
                      
                      // --- Dynamic Stepper ---
                      _buildSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Order Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            _buildStatusStep(
                              title: "Order Confirmed",
                              subtitle: "Restaurant is preparing",
                              icon: Icons.check,
                              isCompleted: true,
                              showLine: true,
                            ),
                            _buildStatusStep(
                              title: "Food Ready",
                              subtitle: "Waiting for pickup",
                              icon: Icons.inventory_2_outlined,
                              isCompleted: ["Ready", "On the Way", "Delivered"].contains(status),
                              showLine: true,
                            ),
                            _buildStatusStep(
                              title: "On the Way",
                              subtitle: "Driver is heading to you",
                              icon: Icons.local_shipping_outlined,
                              isCompleted: ["On the Way", "Delivered"].contains(status),
                              isInProgress: status == "On the Way",
                              showLine: true,
                            ),
                            _buildStatusStep(
                              title: "Delivered",
                              subtitle: "Enjoy your meal!",
                              icon: Icons.home_outlined,
                              isCompleted: status == "Delivered",
                              showLine: false,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildDriverSection(),
                      const SizedBox(height: 20),

                      // --- Final Order Summary ---
                      _buildSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Order Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            _buildDetailRow("Order ID", "#$orderNumber"),
                            _buildDetailRow("Restaurant", orderData['restaurantName'] ?? "RecOrder Partner"),
                            _buildDetailRow("Items", "${items.length} items"),
                            const Divider(height: 30),
                            _buildDetailRow("Total", "\$${total.toStringAsFixed(2)}", isTotal: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI Components ---

  Widget _buildVoiceHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 35,
            backgroundColor: Color(0xFFEB1B33),
            child: Icon(Icons.mic, color: Colors.white, size: 35),
          ),
          const SizedBox(height: 15),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 25),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              children: [
                Icon(Icons.mic, color: Color(0xFFEB1B33), size: 20),
                SizedBox(width: 10),
                Text('Say "Where is my order?"', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalCard(String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          colors: [Color(0xFF4527A0), Color(0xFF00695C)],
        ),
      ),
      child: Column(
        children: [
          const Text("Estimated Arrival", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 5),
          Text(status == "Delivered" ? "Arrived" : "12 min", 
               style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
          const Text("Your food is almost there!", style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Image.network(
        'https://images.unsplash.com/photo-1600891964599-f61ba0e24092?auto=format&fit=crop&w=1200&q=80',
        height: 200, width: double.infinity, fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildDriverSection() {
    return _buildSectionCard(
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Color(0xFFEB1B33), child: Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("John Doe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("4.9 ★ Rider", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.call, color: Color(0xFF00695C))),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)],
      ),
      child: child,
    );
  }

  Widget _buildStatusStep({required String title, required String subtitle, required IconData icon, required bool isCompleted, required bool showLine, bool isInProgress = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFFEB1B33) : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isCompleted ? Colors.white : Colors.grey[600], size: 22),
            ),
            if (showLine) Container(width: 2, height: 40, color: isCompleted ? const Color(0xFFEB1B33) : Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              if (isInProgress) const AnimatedDots(),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14)),
      ],
    );
  }
}

// --- Animation Helper ---

class AnimatedDots extends StatefulWidget {
    const AnimatedDots({super.key});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }


  @override
  Future<void> dispose() async { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        children: List.generate(3, (i) => Opacity(
          opacity: (_controller.value * 3).floor() == i ? 1.0 : 0.2,
          child: const Padding(padding: EdgeInsets.all(2), child: Text("•", style: TextStyle(color: Color(0xFFEB1B33), fontSize: 24))),
        )),
      ),
    );
  }
}