import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';

class TrackOrderScreen extends StatefulWidget {
  final String? orderId;
  const TrackOrderScreen({super.key, this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final FlutterTts tts = FlutterTts();
  String lastStatus = "";

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Future<void> _speakStatus(String status, LanguageProvider lp) async {
    if (status == lastStatus) return; // Don't repeat if status hasn't changed
    lastStatus = status;

    await tts.setLanguage(lp.isEnglish ? "en-US" : "ar-SA");
    String message = lp.getText('status_voice_prefix') + " " + lp.getText('status_${status.toLowerCase().replaceAll(' ', '_')}');
    await tts.speak(message);
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    if (widget.orderId == null || widget.orderId!.isEmpty) {
      return Scaffold(body: _buildNoOrderState(lp));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(lp.isEnglish ? Icons.arrow_back : Icons.arrow_forward, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lp.getText('track_order_title'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFEB1B33)));
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildNoOrderState(lp);
          }

          var orderData = snapshot.data!.data() as Map<String, dynamic>;
          List items = orderData['items'] ?? [];
          String status = orderData['status'] ?? "Pending";

          // Trigger TTS for status updates
          _speakStatus(status, lp);

          // Restaurant Logic
          String restaurantDisplay = items
              .map((item) => item['restaurant']?.toString() ?? "")
              .where((name) => name.isNotEmpty)
              .toSet()
              .join(", ");

          if (restaurantDisplay.isEmpty) {
            restaurantDisplay = orderData['restaurantName'] ?? lp.getText('recorder_partner');
          }

          String driverName = orderData['driverName'] ?? lp.getText('searching_driver');
          String driverRating = orderData['driverRating'] ?? "5.0";
          int totalQuantity = items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 1));
          double total = (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
          String orderNumber = orderData['orderNumber'] ?? widget.orderId!.substring(0, 5);

          // Estimate Logic
          String estimate;
          if (status == "Delivered") {
            estimate = lp.getText('status_arrived');
          } else {
            int baseTime = status == "Preparing" ? 20 : (status == "Ready" ? 15 : (status == "On the Way" ? 10 : 25));
            int restaurantCount = items.map((i) => i['restaurant']).toSet().length;
            int finalTime = restaurantCount > 1 ? (baseTime + (restaurantCount - 1) * 8) : baseTime;
            estimate = "$finalTime ${lp.getText('unit_minutes')}";
          }

          bool isConfirmed = true;
          bool isReady = ["Ready", "On the Way", "Delivered"].contains(status);
          bool isOnWay = ["On the Way", "Delivered"].contains(status);
          bool isDelivered = status == "Delivered";

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildVoiceHeader(lp),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildArrivalCard(status, estimate, lp),
                      const SizedBox(height: 20),
                      _buildMapSection(),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        child: Column(
                          crossAxisAlignment: lp.isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Text(lp.getText('order_status_header'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            _buildStatusStep(
                              lp: lp,
                              title: lp.getText('step_confirmed_title'),
                              subtitle: lp.getText('step_confirmed_sub'),
                              icon: Icons.check,
                              isCompleted: isConfirmed,
                              showLine: true,
                            ),
                            _buildStatusStep(
                              lp: lp,
                              title: lp.getText('step_ready_title'),
                              subtitle: lp.getText('step_ready_sub'),
                              icon: Icons.inventory_2_outlined,
                              isCompleted: isReady,
                              isInProgress: status == "Preparing",
                              showLine: true,
                            ),
                            _buildStatusStep(
                              lp: lp,
                              title: lp.getText('step_way_title'),
                              subtitle: lp.getText('step_way_sub'),
                              icon: Icons.local_shipping_outlined,
                              isCompleted: isOnWay,
                              isInProgress: status == "On the Way",
                              showLine: true,
                            ),
                            _buildStatusStep(
                              lp: lp,
                              title: lp.getText('step_delivered_title'),
                              subtitle: lp.getText('step_delivered_sub'),
                              icon: Icons.home_outlined,
                              isCompleted: isDelivered,
                              showLine: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDriverSection(driverName, driverRating, lp),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        child: Column(
                          crossAxisAlignment: lp.isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Text(lp.getText('order_details_header'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            _buildDetailRow(lp.getText('detail_order_id'), "#$orderNumber", lp),
                            _buildDetailRow(lp.getText('detail_restaurant'), restaurantDisplay, lp),
                            _buildDetailRow(lp.getText('detail_items'), "$totalQuantity ${lp.getText('unit_items')}", lp),
                            const Divider(height: 30),
                            _buildDetailRow(lp.getText('detail_total'), "\$${total.toStringAsFixed(2)}", lp, isTotal: true),
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

  Widget _buildNoOrderState(LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(lp.getText('no_active_orders'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(lp.getText('no_active_orders_sub'), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEB1B33),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(lp.getText('go_back_btn'), style: const TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildVoiceHeader(LanguageProvider lp) {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic, color: Color(0xFFEB1B33), size: 20),
                const SizedBox(width: 10),
                Text(lp.getText('voice_prompt_track'), style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalCard(String status, String arrivalTime, LanguageProvider lp) {
    String footer = lp.getText('footer_almost_there');
    if (status == "Delivered") footer = lp.getText('footer_completed');
    else if (status == "Preparing") footer = lp.getText('footer_cooking');
    else if (status == "On the Way") footer = lp.getText('footer_heading_to_you');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(colors: [Color(0xFF4527A0), Color(0xFF00695C)]),
      ),
      child: Column(
        children: [
          Text(lp.getText('arrival_estimate_label'), style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 5),
          Text(arrivalTime, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
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

  Widget _buildDriverSection(String name, String rating, LanguageProvider lp) {
    return _buildSectionCard(
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Color(0xFFEB1B33), child: Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: lp.isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("$rating ★ ${lp.getText('rider_label')}", style: const TextStyle(color: Colors.grey)),
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

  Widget _buildStatusStep({required LanguageProvider lp, required String title, required String subtitle, required IconData icon, required bool isCompleted, required bool showLine, bool isInProgress = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: lp.isEnglish ? TextDirection.ltr : TextDirection.rtl,
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
              Container(width: 2, height: 40, color: isCompleted ? const Color(0xFFEB1B33) : Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: lp.isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
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

  Widget _buildDetailRow(String label, String value, LanguageProvider lp, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection: lp.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14, color: isTotal ? const Color(0xFFEB1B33) : Colors.black)),
      ],
    );
  }
}
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
    // Animates the dots every 1 second
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1000)
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
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // This logic makes the dots blink one after the other
            return Opacity(
              opacity: (_controller.value * 3).floor() == i ? 1.0 : 0.2,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  "•",
                  style: TextStyle(
                    color: Color(0xFFEB1B33),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}