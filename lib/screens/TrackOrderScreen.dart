import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

import '../services/ai_service.dart';

class TrackOrderScreen extends StatefulWidget {
  final String? orderId;
  const TrackOrderScreen({super.key, this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final FlutterTts tts = FlutterTts();

  bool _introSpoken = false;
  String _lastStatus = "";

  // ── voice loop state ──────────────────────────────────────────────────────
  bool _shouldListen = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final audio = Provider.of<AppAudioProvider>(context, listen: false);
        await audio.stop();
      }
      await tts.stop();
    });
  }

  @override
  void dispose() {
    _shouldListen = false;
    tts.stop();
    super.dispose();
  }

  // ── speak intro then start listening ─────────────────────────────────────
  Future<void> _speakOrderIntro(
      Map<String, dynamic> orderData, LanguageProvider lp) async {
    if (!mounted) return;

    final List items = orderData['items'] ?? [];
    final String status = orderData['status'] ?? "Pending";
    final double total =
        (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final String orderNumber =
        orderData['orderNumber'] ?? widget.orderId!.substring(0, 5);
    final int totalQuantity =
    items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 1));
    final String driverName =
        orderData['driverName'] ?? lp.getText('searching_driver');

    String restaurantName = items
        .map((item) => item['restaurant']?.toString() ?? "")
        .where((name) => name.isNotEmpty)
        .toSet()
        .join(", ");
    if (restaurantName.isEmpty) {
      restaurantName =
          orderData['restaurantName'] ?? lp.getText('recorder_partner');
    }

    int baseTime = status == "Preparing"
        ? 20
        : (status == "Ready" ? 15 : (status == "On the Way" ? 10 : 25));
    int restaurantCount = items.map((i) => i['restaurant']).toSet().length;
    int estimatedMinutes =
    restaurantCount > 1 ? baseTime + (restaurantCount - 1) * 8 : baseTime;

    _lastStatus = status;

    await tts.setLanguage(lp.isEnglish ? "en-US" : "ar-SA");

    final String message = lp.isEnglish
        ? "Tracking your order. "
        "Order number $orderNumber. "
        "Your order is from $restaurantName. "
        "You have $totalQuantity items. "
        "Total is ${total.toStringAsFixed(2)} Egyptian pounds. "
        "Estimated arrival in $estimatedMinutes minutes. "
        "Current status: $status. "
        "Your rider is $driverName. "
        "Your order will be updated automatically as it progresses. "
        "Say go back to return."
        : "جاري تتبع طلبك. "
        "رقم الطلب $orderNumber. "
        "طلبك من $restaurantName. "
        "لديك $totalQuantity أصناف. "
        "الإجمالي ${total.toStringAsFixed(2)} جنيه مصري. "
        "الوقت المتوقع للوصول $estimatedMinutes دقيقة. "
        "الحالة الحالية: $status. "
        "المندوب هو $driverName. "
        "سيتم تحديث طلبك تلقائياً مع تقدمه. "
        "قل ارجع للعودة.";

    // Use a Completer so we wait for TTS to finish before starting the mic
    final completer = Completer<void>();
    tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });

    await tts.speak(message);

    // Wait for speech to finish (max 45 s) then start listening
    try {
      await completer.future.timeout(const Duration(seconds: 45));
    } catch (_) {
      debugPrint("TTS completion timed out — continuing anyway");
    }

    if (mounted) {
      _shouldListen = true;
      final lp2 = Provider.of<LanguageProvider>(context, listen: false);
      _startListening(lp2);
    }
  }

  Future<void> _speakStatus(String status, LanguageProvider lp) async {
    if (!_introSpoken) return;
    if (status == _lastStatus) return;
    _lastStatus = status;

    await tts.setLanguage(lp.isEnglish ? "en-US" : "ar-SA");
    final String message = lp.getText('status_voice_prefix') +
        " " +
        lp.getText('status_${status.toLowerCase().replaceAll(' ', '_')}');
    await tts.speak(message);
  }

  // ── voice listening loop ──────────────────────────────────────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (Track): $text");
        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();
        debugPrint("AI COMMAND (Track): $command");

        await _handleCommand(command, lp);

        _isProcessing = false;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) _startListening(lp);
        });
      },
      onError: (_) {
        if (!_shouldListen || !mounted || _isProcessing) return;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_shouldListen && mounted && !_isProcessing) _startListening(lp);
        });
      },
    );
  }

  Future<void> _handleCommand(String command, LanguageProvider lp) async {
    if (!mounted) return;

    switch (command) {
      case "go_back":
        _shouldListen = false;
        await tts.stop();
        // Do NOT call audio.stop() — lets the previous screen restart its mic
        if (mounted) Navigator.pop(context);
        break;

      default:
        await tts.setLanguage(lp.isEnglish ? "en-US" : "ar-SA");
        await tts.speak(lp.isEnglish
            ? "Say go back to return to the previous screen."
            : "قل ارجع للعودة للشاشة السابقة.");
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

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
          icon: Icon(
              lp.isEnglish ? Icons.arrow_back : Icons.arrow_forward,
              color: Colors.black),
          onPressed: () {
            _shouldListen = false;
            tts.stop();
            Navigator.pop(context);
          },
        ),
        title: Text(
          lp.getText('track_order_title'),
          style:
          const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                CircularProgressIndicator(color: Color(0xFFEB1B33)));
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return _buildNoOrderState(lp);
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          final List items = orderData['items'] ?? [];
          final String status = orderData['status'] ?? "Pending";

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!_introSpoken) {
              _introSpoken = true;
              _speakOrderIntro(orderData, lp);
            } else {
              _speakStatus(status, lp);
            }
          });

          String restaurantDisplay = items
              .map((item) => item['restaurant']?.toString() ?? "")
              .where((name) => name.isNotEmpty)
              .toSet()
              .join(", ");
          if (restaurantDisplay.isEmpty) {
            restaurantDisplay =
                orderData['restaurantName'] ?? lp.getText('recorder_partner');
          }

          final String driverName =
              orderData['driverName'] ?? lp.getText('searching_driver');
          final String driverRating = orderData['driverRating'] ?? "5.0";
          final int totalQuantity = items.fold(
              0, (sum, item) => sum + (item['quantity'] as int? ?? 1));
          final double total =
              (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
          final String orderNumber =
              orderData['orderNumber'] ?? widget.orderId!.substring(0, 5);

          String estimate;
          if (status == "Delivered") {
            estimate = lp.getText('status_arrived');
          } else {
            int baseTime = status == "Preparing"
                ? 20
                : (status == "Ready"
                ? 15
                : (status == "On the Way" ? 10 : 25));
            int restaurantCount =
                items.map((i) => i['restaurant']).toSet().length;
            int finalTime = restaurantCount > 1
                ? (baseTime + (restaurantCount - 1) * 8)
                : baseTime;
            estimate = "$finalTime ${lp.getText('unit_minutes')}";
          }

          final bool isConfirmed = true;
          final bool isReady =
          ["Ready", "On the Way", "Delivered"].contains(status);
          final bool isOnWay = ["On the Way", "Delivered"].contains(status);
          final bool isDelivered = status == "Delivered";

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
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        child: Column(
                          crossAxisAlignment: lp.isEnglish
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                            Text(lp.getText('order_status_header'),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
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
                          crossAxisAlignment: lp.isEnglish
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                            Text(lp.getText('order_details_header'),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            _buildDetailRow(
                                lp.getText('detail_order_id'),
                                "#$orderNumber",
                                lp),
                            _buildDetailRow(
                                lp.getText('detail_restaurant'),
                                restaurantDisplay,
                                lp),
                            _buildDetailRow(
                                lp.getText('detail_items'),
                                "$totalQuantity ${lp.getText('unit_items')}",
                                lp),
                            const Divider(height: 30),
                            _buildDetailRow(
                                lp.getText('detail_total'),
                                "\$${total.toStringAsFixed(2)}",
                                lp,
                                isTotal: true),
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

  // ── helper widgets ────────────────────────────────────────────────────────

  Widget _buildNoOrderState(LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(lp.getText('no_active_orders'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(lp.getText('no_active_orders_sub'),
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEB1B33),
              padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(lp.getText('go_back_btn'),
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildVoiceHeader(LanguageProvider lp) {
    return Consumer<AppAudioProvider>(
      builder: (context, audio, _) => Container(
        color: Colors.white,
        padding: const EdgeInsets.only(bottom: 25),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                if (!audio.speech.isListening && !_isProcessing) {
                  _shouldListen = true;
                  _startListening(lp);
                }
              },
              child: CircleAvatar(
                radius: 35,
                backgroundColor:
                audio.isListening ? Colors.green : const Color(0xFFEB1B33),
                child: Icon(
                  audio.isListening ? Icons.graphic_eq : Icons.mic,
                  color: Colors.white,
                  size: 35,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 25),
              padding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    audio.isListening ? Icons.graphic_eq : Icons.mic,
                    color: audio.isListening
                        ? Colors.green
                        : const Color(0xFFEB1B33),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      audio.isListening
                          ? (audio.lastWords.isEmpty
                          ? (lp.isEnglish ? "Listening..." : "أنا أسمعك...")
                          : audio.lastWords)
                          : lp.getText('voice_prompt_track'),
                      style: const TextStyle(
                          color: Colors.blueGrey, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalCard(
      String status, String arrivalTime, LanguageProvider lp) {
    String footer = lp.getText('footer_almost_there');
    if (status == "Delivered") footer = lp.getText('footer_completed');
    else if (status == "Preparing") footer = lp.getText('footer_cooking');
    else if (status == "On the Way") footer = lp.getText('footer_heading_to_you');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
            colors: [Color(0xFF4527A0), Color(0xFF00695C)]),
      ),
      child: Column(
        children: [
          Text(lp.getText('arrival_estimate_label'),
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 5),
          Text(arrivalTime,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold)),
          Text(footer,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDriverSection(
      String name, String rating, LanguageProvider lp) {
    return _buildSectionCard(
      child: Row(
        children: [
          const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFEB1B33),
              child: Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: lp.isEnglish
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text("$rating ★ ${lp.getText('rider_label')}",
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.call, color: Color(0xFF00695C))),
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03), blurRadius: 15)
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatusStep({
    required LanguageProvider lp,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required bool showLine,
    bool isInProgress = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection:
      lp.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFEB1B33)
                    : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isCompleted ? Colors.white : Colors.grey[600],
                  size: 22),
            ),
            if (showLine)
              Container(
                  width: 2,
                  height: 40,
                  color: isCompleted
                      ? const Color(0xFFEB1B33)
                      : Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: lp.isEnglish
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.black : Colors.grey)),
              Text(subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              if (isInProgress) const AnimatedDots(),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, LanguageProvider lp,
      {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection:
      lp.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 18 : 14,
                color: isTotal ? const Color(0xFFEB1B33) : Colors.black)),
      ],
    );
  }
}

// ── AnimatedDots ──────────────────────────────────────────────────────────────

class AnimatedDots extends StatefulWidget {
  const AnimatedDots({super.key});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
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
            return Opacity(
              opacity: (_controller.value * 3).floor() == i ? 1.0 : 0.2,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text("•",
                    style: TextStyle(
                        color: Color(0xFFEB1B33),
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ),
            );
          }),
        );
      },
    );
  }
}