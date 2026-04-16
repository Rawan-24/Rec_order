import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

class TrackOrderScreen extends StatefulWidget {
  final String? orderId;
  const TrackOrderScreen({super.key, this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> with SingleTickerProviderStateMixin {
  String lastStatus = "";
  late AnimationController _pulseController;
  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Refined Voice Announcement with logic to prevent double-speaking
  Future<void> _handleVoiceAnnouncement(String status, LanguageProvider lp) async {
    // Only speak if the status has actually changed
    if (status == lastStatus) return;
    lastStatus = status;

    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Standardize status for key lookup
    String statusKey = status.toLowerCase().replaceAll(' ', '_');
    String message = lp.getText('status_${statusKey}_full');

    // Fallback if key doesn't exist in LanguageProvider
    if (message.contains('status_')) {
      message = lp.isRTL ? "تم تحديث حالة الطلب إلى $status" : "Order status updated to $status";
    }

    // Short delay to ensure the screen has transitioned before speaking
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        audio.speak(message, lp.currentLanguage);
      }
    });
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    if (widget.orderId == null || widget.orderId!.isEmpty) {
      return Scaffold(body: _buildEmptyState(lp));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black),
          onPressed: () => _navigateToHome(context),
        ),
        title: Text(lp.getText('track_order_title'),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFEB1B33)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyState(lp);
          }

          var orderData = snapshot.data!.data() as Map<String, dynamic>;
          String status = orderData['status'] ?? "Pending";

          // Trigger voice update
          _handleVoiceAnnouncement(status, lp);

          return _buildUI(orderData, status, lp);
        },
      ),
    );
  }

  Widget _buildUI(Map<String, dynamic> data, String status, LanguageProvider lp) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildVoiceHeader(lp),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                _buildArrivalCard(status, lp),
                const SizedBox(height: 20),
                _buildTrackerCard(status, lp),
                const SizedBox(height: 20),
                _buildDriverCard(data, lp),
                const SizedBox(height: 20),
                _buildOrderSummary(data, lp),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceHeader(LanguageProvider lp) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.2).animate(_pulseController),
            child: Icon(Icons.mic, color: primaryRed, size: 20),
          ),
          const SizedBox(width: 10),
          Text(lp.getText('voice_monitoring_active'),
              style: TextStyle(color: primaryRed, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildArrivalCard(String status, LanguageProvider lp) {
    bool isDone = status == "Delivered";
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF1A1A1A),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lp.getText('arrival_estimate_label'), style: const TextStyle(color: Colors.white60, fontSize: 14)),
                const SizedBox(height: 4),
                Text(isDone ? lp.getText('status_arrived') : "12-18 ${lp.getText('unit_minutes')}",
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 35),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerCard(String status, LanguageProvider lp) {
    return _buildCard([
      Text(lp.getText('order_status_header'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 25),
      _buildStep(lp.getText('step_confirmed_title'), Icons.receipt_long, true, true),
      _buildStep(lp.getText('step_ready_title'), Icons.outdoor_grill_rounded,
          ["Preparing", "Ready", "On the Way", "Delivered"].contains(status), true, active: status == "Preparing"),
      _buildStep(lp.getText('step_way_title'), Icons.moped_rounded,
          ["On the Way", "Delivered"].contains(status), true, active: status == "On the Way"),
      _buildStep(lp.getText('step_delivered_title'), Icons.check_circle_rounded,
          status == "Delivered", false),
    ]);
  }

  Widget _buildStep(String title, IconData icon, bool done, bool line, {bool active = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: done ? primaryRed : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: done ? Colors.white : Colors.grey[400], size: 18),
            ),
            if (line) Container(width: 2, height: 35, color: done ? primaryRed : Colors.grey[200]),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(title, style: TextStyle(
              fontWeight: active || done ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
              color: done ? Colors.black : (active ? primaryRed : Colors.grey),
            )),
          ),
        ),
        if (active) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)),
      ],
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> data, LanguageProvider lp) {
    return _buildCard([
      Row(
        children: [
          CircleAvatar(radius: 25, backgroundColor: primaryRed.withOpacity(0.1), child: Icon(Icons.person_rounded, color: primaryRed, size: 30)),
          const SizedBox(width: 15),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['driverName'] ?? lp.getText('searching_driver'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text("${data['driverRating'] ?? '4.9'}", style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          )),
          CircleAvatar(
            backgroundColor: Colors.green.withOpacity(0.1),
            child: IconButton(onPressed: () {}, icon: const Icon(Icons.call_rounded, color: Colors.green, size: 20)),
          ),
        ],
      ),
    ]);
  }

  Widget _buildOrderSummary(Map<String, dynamic> data, LanguageProvider lp) {
    return _buildCard([
      Row(
        children: [
          Icon(Icons.restaurant_menu_rounded, color: primaryRed, size: 20),
          const SizedBox(width: 10),
          Text(data['restaurantName'] ?? "---", style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      const Divider(height: 30),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(lp.getText('detail_total'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text("\$${data['totalPrice']}", style: TextStyle(fontWeight: FontWeight.w900, color: primaryRed, fontSize: 18)),
        ],
      ),
    ]);
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildEmptyState(LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(lp.getText('no_active_orders'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(lp.isRTL ? "ابحث عن وجبتك المفضلة وابدأ الطلب" : "Find your favorite meal and start ordering", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          SizedBox(
            width: 200, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () => _navigateToHome(context),
              child: Text(lp.getText('go_back_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}