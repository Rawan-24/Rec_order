import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/screens/CartProvider.dart';

class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({super.key});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Voice Command Header ---
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 25),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFFEB1B33),
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
                        Icon(Icons.mic, color: const Color(0xFFEB1B33), size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Say "Where is my order?" or "Call driver"',
                          style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // --- Estimated Arrival Card ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4527A0), Color(0xFF00695C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Column(
                      children: [
                        Text("Estimated Arrival", style: TextStyle(color: Colors.white70, fontSize: 16)),
                        SizedBox(height: 5),
                        Text("12 min", style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                        Text("Your food is almost there!", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Rider Map/Image Section ---
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1600891964599-f61ba0e24092?auto=format&fit=crop&w=1200&q=80',
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: 15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.red, size: 18),
                              SizedBox(width: 5),
                              Text("0.8 km away", style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- Order Status Stepper Section ---
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
                          isCompleted: true,
                          showLine: true,
                        ),
                        _buildStatusStep(
                          title: "On the Way",
                          subtitle: "Driver is heading to you",
                          icon: Icons.local_shipping_outlined,
                          isCompleted: true,
                          isInProgress: true, // Shows animated dots
                          showLine: true,
                        ),
                        _buildStatusStep(
                          title: "Delivered",
                          subtitle: "Enjoy your meal!",
                          icon: Icons.home_outlined,
                          isCompleted: false,
                          showLine: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Your Driver Section ---
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Your Driver", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFFEB1B33),
                              child: Text("JD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 15),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("John Doe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.orange, size: 16),
                                    Text(" 4.9 • 1,200+ deliveries", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call, color: Colors.white),
                          label: const Text("Call Driver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Order Details Summary Section ---
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Order Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        // 2. UPDATE THESE LINES HERE:
                        _buildDetailRow("Order ID", "#ORD-12345"),
                        _buildDetailRow("Restaurant", cart.items.isNotEmpty ? cart.items.first.restaurant : "N/A"),
                        _buildDetailRow("Items", "${cart.items.length} items"), // <--- HERE
                        const Divider(height: 30),
                        _buildDetailRow("Total", "\$${cart.total.toStringAsFixed(2)}", isTotal: true), // <--- AND HERE
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatusStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required bool showLine,
    bool isInProgress = false,
  }) {
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
            if (showLine)
              Container(
                width: 2,
                height: isInProgress ? 60 : 45,
                color: isCompleted ? const Color(0xFFEB1B33) : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              if (isInProgress) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    AnimatedDots(),
                    SizedBox(width: 8),
                    Text(
                      "In Progress",
                      style: TextStyle(color: const Color(0xFFEB1B33), fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 15),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 18 : 15,
              color: isTotal ? const Color(0xFFEB1B33) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Animated Dots Component ---

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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            double opacity = 0.2;
            double val = _controller.value * 3;
            if (val.floor() == index) opacity = 1.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFEB1B33).withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}