import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'dart:async'; // Add this import



class TrackOrderScreen extends StatefulWidget {
  final String? orderId; // Nullable to handle entries from Home with no order
  const TrackOrderScreen({super.key, this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();


}

class _TrackOrderScreenState extends State<TrackOrderScreen> {


  @override
  Widget build(BuildContext context) {
    // --- 1. PREVENT CRASH: Guard clause for empty or null ID ---
    if (widget.orderId == null || widget.orderId!.isEmpty) {
      return _buildNoOrderState();
    }

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
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFEB1B33)));
          }

          // --- 2. PREVENT CRASH: Check if document exists in Firestore ---
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildNoOrderState();
          }

          // Extracting the map from Firestore
          var orderData = snapshot.data!.data() as Map<String, dynamic>;

// --- DYNAMIC DATA MAPPING ---

// 1. Get the list of items from Firestore
          List items = orderData['items'] ?? [];

// 2. Extract every restaurant name, remove duplicates (toSet),
// and join them with a comma.
          String restaurantDisplay = items
              .map((item) => item['restaurant']?.toString() ?? "") // Get all names
              .where((name) => name.isNotEmpty)                   // Remove empty ones
              .toSet()                                            // Remove duplicates
              .join(", ");                                        // Result: "Pizza Hut, KFC"

// 3. Fallback if something goes wrong
          if (restaurantDisplay.isEmpty) {
            restaurantDisplay = orderData['restaurantName'] ?? "RecOrder Partner";
          }
// Try the top level field first
          String? topName = orderData['restaurantName'];

// If that's empty, try to get it from the first item in the list

          String? itemName = (items.isNotEmpty) ? items.first['restaurant'] : null;

// The final name to display

// 1. First, try to get the top-level 'restaurantName'
          String topLevelName = orderData['restaurantName'] ?? "";

// 2. Second, get all names from the items list (as a backup or for multiple)

          String itemsNames = items.map((i) => i['restaurant']?.toString() ?? "").toSet().where((name) => name.isNotEmpty).join(", ");


          String driverName = orderData['driverName'] ?? "Searching for driver...";
          String driverRating = orderData['driverRating'] ?? "5.0";
// 3. DYNAMIC ITEM COUNT
// Instead of just items.length, we sum the 'quantity' from each CartItem
          int totalQuantity = items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 1));

// 4. OTHER FIELDS
          String status = orderData['status'] ?? "Pending";
          double total = (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
          String orderNumber = orderData['orderNumber'] ?? widget.orderId!.substring(0, 5);
// 1. DYNAMIC TIME CALCULATION




          String estimate ;
          String footer = "Your food is almost there!";

          if (status == "Delivered") {
            estimate = "Arrived";
          } else if (status == "Preparing") {
            estimate = "20";
          } else if (status == "Ready") {
            estimate = "15";
          } else if (status == "On the Way") {
            estimate = "10";
          } else {
            // This handles "Pending" or any unexpected status from DB
            estimate = "25";
          }
// 2. APPLYING THE MULTI-RESTAURANT LOGIC
          int restaurantCount = items.map((i) => i['restaurant']).toSet().length;

          if (restaurantCount > 1 && status != "Delivered" && status != "Pending") {
            // Parse the base number we just set above
            int currentMin = int.tryParse(estimate) ?? 15;
            estimate = "${currentMin + (restaurantCount - 1) * 8} min";
          } else if (status != "Delivered") {
            // Add "min" suffix if it hasn't been added yet
            estimate = estimate.contains("min") ? estimate : "$estimate min";
          }
// 3. SETTING THE RED STATUS BOOLEANS
// This logic makes the steps turn red ONLY when the DB status matches
          bool isConfirmed = true;
          bool isReady = ["Ready", "On the Way", "Delivered"].contains(status);
          bool isOnWay = ["On the Way", "Delivered"].contains(status);
          bool isDelivered = status == "Delivered";
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildVoiceHeader(),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildArrivalCard(status, estimate), // Pass the new string here // Dynamic arrival info
                      const SizedBox(height: 20),
                      _buildMapSection(),
                      const SizedBox(height: 20),

                      // --- Dynamic Stepper Logic ---
                      _buildSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Order Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),

                            // Step 1: Confirmed
                            _buildStatusStep(
                              title: "Order Confirmed",
                              subtitle: "Restaurant has received your request",
                              icon: Icons.check,
                              isCompleted: isConfirmed, // Red immediately
                              showLine: true,
                            ),

                            // Step 2: Food Ready
                            _buildStatusStep(
                              title: "Food Ready",
                              subtitle: "Chef has finished preparing",
                              icon: Icons.inventory_2_outlined,
                              isCompleted: isReady, // Turns red when time <= 15 mins
                              isInProgress: status == "Preparing" && !isReady,
                              showLine: true,
                            ),

                            // Step 3: On the Way
                            _buildStatusStep(
                              title: "On the Way",
                              subtitle: "Driver is heading to you",
                              icon: Icons.local_shipping_outlined,
                              isCompleted: isOnWay, // Turns red when time <= 10 mins
                              isInProgress: status == "On the Way" && !isOnWay,
                              showLine: true,
                            ),

                            // Step 4: Delivered
                            _buildStatusStep(
                              title: "Delivered",
                              subtitle: "Enjoy your meal!",
                              icon: Icons.home_outlined,
                              isCompleted: isDelivered, // Turns red at 0 mins or Delivered status
                              showLine: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDriverSection(driverName, driverRating), // Dynamic Driver info
                      const SizedBox(height: 20),

                      // --- Final Order Summary ---
                      _buildSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Order Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            _buildDetailRow("Order ID", "#$orderNumber"),
                            // Shows all unique restaurants in this order
                            _buildDetailRow("Restaurant", restaurantDisplay),

                            // Shows total quantity (e.g., if I bought 2 pizzas, it shows 2 items)
                            _buildDetailRow("Items", "$totalQuantity items"),
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

  // --- Helper: No Order State UI ---
  Widget _buildNoOrderState() {
    // REMOVE: Scaffold and AppBar here
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            "No Active Orders",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "You don't have any orders to track right now.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEB1B33),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Go Back", style: TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
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
  Widget _buildArrivalCard(String status, String arrivalTime) {
    String footer = "Your food is almost there!";

    if (status == "Delivered") {
      footer = "Order completed";
    } else if (status == "Preparing") {
      footer = "Chef is cooking your meal";
    } else if (status == "On the Way") {
      footer = "Driver is heading to your location";
    }

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
          Text(
            arrivalTime, // Use the dynamic string here!
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
          ),
          Text(footer, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
  Widget _buildMapSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Image.network(
        'https://images.unsplash.com/photo-1526628953301-3e589a6a8b74?q=80&w=2006&auto=format&fit=crop',
        height: 200, width: double.infinity, fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildDriverSection(String name, String rating) {
    return _buildSectionCard(
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Color(0xFFEB1B33), child: Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("$rating ★ Rider", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.call, color: Color(0xFF00695C))
          ),
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
// Inside _buildStatusStep helper
            if (showLine)
              Container(
                  width: 2,
                  height: 40,
                  color: isCompleted ? const Color(0xFFEB1B33) : Colors.grey[300]
              ),          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isCompleted ? Colors.black : Colors.grey)),
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
        Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14, color: isTotal ? const Color(0xFFEB1B33) : Colors.black)),
      ],
    );
  }
}

// --- Animation Helper (Keep as is) ---
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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