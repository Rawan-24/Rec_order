import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Ensure this matches your provider name

class TrackOrderScreen extends StatefulWidget {
  final String? orderId;
  const TrackOrderScreen({super.key, this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> with SingleTickerProviderStateMixin {
  String lastStatus = "";
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Animation for the pulsing microphone
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

  /// Handles Natural Language Announcements
  Future<void> _handleVoiceAnnouncement(String status, LanguageProvider lp) async {
    if (status == lastStatus) return;
    lastStatus = status;

    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // 1. Format key (e.g. "On the Way" -> "on_the_way")
    String statusKey = status.toLowerCase().replaceAll(' ', '_');

    // 2. Get the full sentence (e.g. "Your food is on the way")
    String message = lp.getText('status_${statusKey}_full');

    // 3. Safety Check: Remove underscores if translation is missing
    if (message.contains('_')) {
      message = message.replaceAll('status_', '').replaceAll('_', ' ');
    }

    // 4. Speak using the active language ('ar' or 'en')
    Future.delayed(const Duration(milliseconds: 800), () {
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
    const primaryRed = Color(0xFFEB1B33);

    if (widget.orderId == null || widget.orderId!.isEmpty) {
      return Scaffold(body: _buildEmptyState(lp, primaryRed));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black),
          onPressed: () => _navigateToHome(context),
        ),
        title: Text(lp.getText('track_order_title'),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryRed));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyState(lp, primaryRed);
          }

          var orderData = snapshot.data!.data() as Map<String, dynamic>;
          String status = orderData['status'] ?? "Pending";

          // Trigger the natural voice update
          _handleVoiceAnnouncement(status, lp);

          return _buildUI(orderData, status, lp, primaryRed);
        },
      ),
    );
  }

  Widget _buildUI(Map<String, dynamic> data, String status, LanguageProvider lp, Color red) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildVoiceHeader(lp, red),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildArrivalCard(status, lp),
                const SizedBox(height: 20),
                _buildTrackerCard(status, lp, red),
                const SizedBox(height: 20),
                _buildDriverCard(data, lp, red),
                const SizedBox(height: 20),
                _buildOrderDetails(data, lp, red),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceHeader(LanguageProvider lp, Color red) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.15).animate(_pulseController),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: red.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: red.withOpacity(0.2), width: 2),
              ),
              child: Icon(Icons.mic, color: red, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(lp.getText('voice_monitoring_active'),
              style: TextStyle(color: red, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildArrivalCard(String status, LanguageProvider lp) {
    bool isDone = status == "Delivered";
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF2D3436), Color(0xFF000000)]),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lp.getText('arrival_estimate_label'), style: const TextStyle(color: Colors.white70)),
              Text(isDone ? lp.getText('status_arrived') : "15-20 ${lp.getText('unit_minutes')}",
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            ],
          ),
          const Icon(Icons.moped, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  Widget _buildTrackerCard(String status, LanguageProvider lp, Color red) {
    return _buildCard([
      Text(lp.getText('order_status_header'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 20),
      _buildStep(lp, lp.getText('step_confirmed_title'), Icons.check_circle, true, true, red),
      _buildStep(lp, lp.getText('step_ready_title'), Icons.restaurant,
          ["Ready", "On the Way", "Delivered"].contains(status), true, red, active: status == "Preparing"),
      _buildStep(lp, lp.getText('step_way_title'), Icons.local_shipping,
          ["On the Way", "Delivered"].contains(status), true, red, active: status == "On the Way"),
      _buildStep(lp, lp.getText('step_delivered_title'), Icons.home,
          status == "Delivered", false, red),
    ]);
  }

  Widget _buildStep(LanguageProvider lp, String title, IconData icon, bool done, bool line, Color red, {bool active = false}) {
    return Row(
      children: [
        Column(
          children: [
            Icon(icon, color: done ? red : Colors.grey[300], size: 24),
            if (line) Container(width: 2, height: 30, color: done ? red : Colors.grey[200]),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Text(title, style: TextStyle(
            fontWeight: done || active ? FontWeight.bold : FontWeight.normal,
            color: done || active ? Colors.black : Colors.grey,
          )),
        ),
        if (active) const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)),
      ],
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> data, LanguageProvider lp, Color red) {
    return _buildCard([
      Row(
        children: [
          CircleAvatar(backgroundColor: red.withOpacity(0.1), child: Icon(Icons.person, color: red)),
          const SizedBox(width: 15),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['driverName'] ?? lp.getText('searching_driver'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("${data['driverRating'] ?? '5.0'} ★", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )),
          IconButton(onPressed: () {}, icon: const Icon(Icons.phone, color: Colors.green)),
        ],
      ),
    ]);
  }

  Widget _buildOrderDetails(Map<String, dynamic> data, LanguageProvider lp, Color red) {
    return _buildCard([
      _row(lp.getText('detail_restaurant'), data['restaurantName'] ?? "---"),
      const Divider(height: 30),
      _row(lp.getText('detail_total'), "\$${data['totalPrice']}", isBold: true, color: red),
    ]);
  }

  Widget _row(String label, String val, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(val, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildEmptyState(LanguageProvider lp, Color red) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text(lp.getText('no_active_orders'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: red),
            onPressed: () => _navigateToHome(context),
            child: Text(lp.getText('go_back_btn'), style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}