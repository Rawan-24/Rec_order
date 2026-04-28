import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/CartScreen.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';
import 'TrackOrderScreen.dart';

/// Describes which guided step the voice flow is currently in.
enum _VoiceStep {
  /// Waiting for user to say "active orders" or "past orders".
  awaitingTabChoice,

  /// Active-orders tab is shown; waiting for a restaurant/order name to track.
  awaitingActiveOrderName,

  /// Past-orders tab is shown; waiting for a restaurant name to reorder.
  awaitingPastOrderName,
}

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage>
    with SingleTickerProviderStateMixin {
  // ── Tab controller ──────────────────────────────────────────────────────────
  late final TabController _tabController;

  // ── Voice flow state ────────────────────────────────────────────────────────
  _VoiceStep _voiceStep = _VoiceStep.awaitingTabChoice;
  bool _shouldListen = true;
  bool _isProcessing = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp = Provider.of<LanguageProvider>(context, listen: false);
      await Future.delayed(const Duration(milliseconds: 500));
      await audio.initSpeech();
      await _speakIntro(lp);
    });
  }

  @override
  void dispose() {
    _shouldListen = false;
    _tabController.dispose();
    super.dispose();
  }

  // ── Intro speech (step 1 of flow) ───────────────────────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();

    setState(() => _voiceStep = _VoiceStep.awaitingTabChoice);

    await audio.speak(
      lp.isEnglish
          ? "Order history. Say active orders to track a current order, "
          "or say past orders to reorder something. You can also say go back."
          : "سجل الطلبات. قل الطلبات النشطة لتتبع طلب جارٍ، "
          "أو قل الطلبات السابقة لإعادة طلب سابق. يمكنك أيضاً قول ارجع.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  // ── Listening loop ──────────────────────────────────────────────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;
        debugPrint("USER SAID (History): $text");

        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();
        debugPrint("AI COMMAND (History): $command");

        await _handleCommand(command, response, text, lp);
        _isProcessing = false;

        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) _startListening(lp);
        });
      },
      onError: (errorMsg) {
        if (!_shouldListen || !mounted || _isProcessing) return;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_shouldListen && mounted && !_isProcessing) _startListening(lp);
        });
      },
    );
  }

  // ── Master command router ───────────────────────────────────────────────────
  Future<void> _handleCommand(
      String command,
      Map<String, dynamic> response,
      String rawText,
      LanguageProvider lp,
      ) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // ── Global: go back is always available ───────────────────────────────────
    if (command == "go_back") {
      _shouldListen = false;
      await audio.stop();
      if (mounted) Navigator.pop(context);
      return;
    }

    // ── Route based on current voice step ────────────────────────────────────
    switch (_voiceStep) {
      case _VoiceStep.awaitingTabChoice:
        await _handleTabChoice(command, rawText, lp);
        break;

      case _VoiceStep.awaitingActiveOrderName:
        await _handleActiveOrderName(command, response, rawText, lp);
        break;

      case _VoiceStep.awaitingPastOrderName:
        await _handlePastOrderName(command, response, rawText, lp);
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 1 ── Tab choice
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _handleTabChoice(
      String command,
      String rawText,
      LanguageProvider lp,
      ) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final lower = rawText.toLowerCase();

    final bool wantsActive = command == "open_active_orders" ||
        command == "track_active_order" ||
        command == "open_track" ||
        lower.contains("active") ||
        lower.contains("current") ||
        lower.contains("نشط") ||
        lower.contains("الجارية") ||
        lower.contains("الحالية");

    final bool wantsPast = command == "open_past_orders" ||
        command == "reorder_last" ||
        command == "open_history" ||
        lower.contains("past") ||
        lower.contains("previous") ||
        lower.contains("history") ||
        lower.contains("سابق") ||
        lower.contains("قديم") ||
        lower.contains("السابقة");

    if (wantsActive) {
      // Switch to active tab
      _tabController.animateTo(0);
      setState(() => _voiceStep = _VoiceStep.awaitingActiveOrderName);

      await audio.speak(
        lp.isEnglish
            ? "Showing active orders. Which order would you like to track? "
            "Say the restaurant name."
            : "عرض الطلبات النشطة. أي طلب تريد تتبعه؟ قل اسم المطعم.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    } else if (wantsPast) {
      // Switch to past tab
      _tabController.animateTo(1);
      setState(() => _voiceStep = _VoiceStep.awaitingPastOrderName);

      await audio.speak(
        lp.isEnglish
            ? "Showing past orders. Which order would you like to reorder? "
            "Say the restaurant name."
            : "عرض الطلبات السابقة. أي طلب تريد إعادته؟ قل اسم المطعم.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    } else {
      await audio.speak(
        lp.isEnglish
            ? "Please say active orders or past orders."
            : "من فضلك قل الطلبات النشطة أو الطلبات السابقة.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 2A ── Active orders: user says restaurant / order name → track
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _handleActiveOrderName(
      String command,
      Map<String, dynamic> response,
      String rawText,
      LanguageProvider lp,
      ) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Allow "go back" to restart from intro
    if (command == "go_back") {
      await _speakIntro(lp);
      return;
    }

    final valueFromAI = (response['value'] ?? "").toString().trim();
    final itemName = valueFromAI.isNotEmpty
        ? valueFromAI.toLowerCase()
        : _extractSubject(rawText);

    await audio.speak(
      lp.isEnglish ? "Looking up your order." : "جاري البحث عن طلبك.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    await _trackByItemName(itemName, lp);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 2B ── Past orders: user says restaurant name → reorder → cart
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _handlePastOrderName(
      String command,
      Map<String, dynamic> response,
      String rawText,
      LanguageProvider lp,
      ) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Allow "go back" to restart from intro
    if (command == "go_back") {
      await _speakIntro(lp);
      return;
    }

    final valueFromAI = (response['value'] ?? "").toString().trim();
    final restaurantName = valueFromAI.isNotEmpty
        ? valueFromAI.toLowerCase()
        : _extractSubject(rawText);

    await audio.speak(
      lp.isEnglish
          ? "Looking up your past orders."
          : "جاري البحث في الطلبات السابقة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    await _reorderByRestaurant(restaurantName, lp);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Strips filler words to leave a clean search term.
  String _extractSubject(String rawText) {
    return rawText
        .toLowerCase()
        .replaceAll(
      RegExp(
        r'\b(i want to|i want|i would like|reorder|order again|order|track|my|the|a|an|please|from|past|history|أعد|أريد|تتبع|طلب|من|الطلب|السابق|سابق)\b',
      ),
      '',
    )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ── Track active order by restaurant / item name ────────────────────────────
  Future<void> _trackByItemName(String itemName, LanguageProvider lp) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fast path — no composite index needed
    try {
      final id = await DatabaseService().getActiveOrderId();
      if (id != null) {
        if (itemName.isEmpty) {
          await audio.speak(
            lp.isEnglish ? "Opening tracking." : "جاري فتح التتبع.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          _navigateToTrack(id, lp);
          return;
        }

        final doc =
        await FirebaseFirestore.instance.collection('orders').doc(id).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final restaurantName =
          (data['restaurantName'] ?? '').toString().toLowerCase();
          final List<dynamic> items = data['items'] ?? [];

          final matchesRestaurant = restaurantName.contains(itemName) ||
              itemName.contains(restaurantName);
          final matchesItem = items.any((item) {
            final name = (item['name'] ?? '').toString().toLowerCase();
            return name.contains(itemName) || itemName.contains(name);
          });

          if (matchesRestaurant || matchesItem || items.isEmpty) {
            await audio.speak(
              lp.isEnglish ? "Opening tracking." : "جاري فتح التتبع.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            _navigateToTrack(id, lp);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("getActiveOrderId error: $e");
    }

    // Slow path — stream query
    try {
      final snapshot = await DatabaseService()
          .getActiveOrders(user.uid)
          .first
          .timeout(const Duration(seconds: 5));

      if (snapshot.docs.isEmpty) {
        await audio.speak(
          lp.isEnglish ? "No active orders found." : "لا توجد طلبات نشطة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        // Go back to tab-choice step so the user can try again
        await _resetToTabStep(lp);
        return;
      }

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final restaurantName =
        (data['restaurantName'] ?? '').toString().toLowerCase();
        final List<dynamic> items = data['items'] ?? [];

        final matchesRestaurant = itemName.isEmpty ||
            restaurantName.contains(itemName) ||
            itemName.contains(restaurantName);

        final matchesItem = items.any((item) {
          final name = (item['name'] ?? '').toString().toLowerCase();
          return name.contains(itemName) || itemName.contains(name);
        });

        if (matchesRestaurant || matchesItem) {
          await audio.speak(
            lp.isEnglish ? "Opening tracking." : "جاري فتح التتبع.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          _navigateToTrack(doc.id, lp);
          return;
        }
      }

      await audio.speak(
        lp.isEnglish
            ? "Could not find that order. Please try another restaurant name."
            : "لم أجد هذا الطلب. حاول باسم مطعم آخر.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      // Stay in awaitingActiveOrderName so user can retry
    } catch (e) {
      debugPrint("Track stream error: $e");
      await audio.speak(
        lp.isEnglish
            ? "Could not load orders. Please try again."
            : "تعذر تحميل الطلبات. حاول مرة أخرى.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    }
  }

  // ── Reorder past order by restaurant name ──────────────────────────────────
  Future<void> _reorderByRestaurant(
      String restaurantQuery, LanguageProvider lp) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot =
      await DatabaseService().getPastOrders(user.uid).first;

      if (snapshot.docs.isEmpty) {
        await audio.speak(
          lp.isEnglish ? "No past orders found." : "لا توجد طلبات سابقة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _resetToTabStep(lp);
        return;
      }

      // If user gave no specific name, reorder the most recent past order
      if (restaurantQuery.isEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        await _addOrderToCart(data, cart);
        await audio.speak(
          lp.isEnglish
              ? "Added your last order to cart. Opening cart."
              : "تمت إضافة آخر طلب للسلة. جاري فتح السلة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        _navigateToCart(lp);
        return;
      }

      // Search for a matching restaurant
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final restaurantName =
        (data['restaurantName'] ?? '').toString().toLowerCase();

        if (restaurantName.contains(restaurantQuery) ||
            restaurantQuery.contains(restaurantName)) {
          await _addOrderToCart(data, cart);
          final displayName = data['restaurantName'] ?? '';
          await audio.speak(
            lp.isEnglish
                ? "Added order from $displayName to cart. Opening cart."
                : "تمت إضافة طلب $displayName للسلة. جاري فتح السلة.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          _navigateToCart(lp);
          return;
        }
      }

      await audio.speak(
        lp.isEnglish
            ? "Could not find an order from that restaurant. Please try another name."
            : "لم أجد طلبًا من هذا المطعم. حاول باسم آخر.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      // Stay in awaitingPastOrderName so user can retry
    } catch (e) {
      debugPrint("Reorder error: $e");
      await audio.speak(
        lp.isEnglish
            ? "Error processing reorder."
            : "خطأ في إعادة الطلب.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    }
  }

  /// Adds all items from an order document to the cart.
  Future<void> _addOrderToCart(
      Map<String, dynamic> data, CartProvider cart) async {
    final List<dynamic> items = data['items'] ?? [];
    final String restaurantName = data['restaurantName'] ?? '';
    for (final im in items) {
      cart.addItem(CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() +
            (im['name'] ?? ''),
        name: im['name'] ?? 'Unknown',
        price: (im['price'] as num?)?.toDouble() ?? 0.0,
        quantity: im['quantity'] ?? 1,
        restaurant: restaurantName,
        details: im['details'] ?? '',
        image: im['image'] ?? '',
      ));
    }
  }

  /// After a failed search, re-announce which step we're on.
  Future<void> _resetToTabStep(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    setState(() => _voiceStep = _VoiceStep.awaitingTabChoice);
    await audio.speak(
      lp.isEnglish
          ? "Say active orders or past orders."
          : "قل الطلبات النشطة أو الطلبات السابقة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────
  void _navigateToTrack(String orderId, LanguageProvider lp) {
    _shouldListen = false;
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TrackOrderScreen(orderId: orderId)),
      ).then((_) {
        _shouldListen = true;
        _isProcessing = false;
        _speakIntro(lp);
      });
    }
  }

  void _navigateToCart(LanguageProvider lp) {
    _shouldListen = false;
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      ).then((_) {
        _shouldListen = true;
        _isProcessing = false;
        _speakIntro(lp);
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);
    const primaryRed = Color(0xFFD32F2F);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            lp.getText('order_history'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            onTap: (index) {
              // Manual tap: switch step context so voice still works
              setState(() {
                _voiceStep = index == 0
                    ? _VoiceStep.awaitingActiveOrderName
                    : _VoiceStep.awaitingPastOrderName;
              });
            },
            tabs: [
              Tab(text: lp.getText('active_orders')),
              Tab(text: lp.getText('past_orders')),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Voice-step hint banner ──────────────────────────────────────
            _VoiceStepBanner(step: _voiceStep, lp: lp),

            // ── Tab content ────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderList(
                    DatabaseService().getActiveOrders(user.uid),
                    primaryRed,
                    true,
                    lp,
                  ),
                  _buildOrderList(
                    DatabaseService().getPastOrders(user.uid),
                    primaryRed,
                    false,
                    lp,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: audio.isListening ? Colors.green : primaryRed,
          onPressed: () {
            if (!audio.speech.isListening && !_isProcessing) {
              _shouldListen = true;
              _startListening(lp);
            }
          },
          child: Icon(
            audio.isListening ? Icons.graphic_eq : Icons.mic,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Order list (shared by both tabs)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildOrderList(
      Stream<QuerySnapshot> stream,
      Color accent,
      bool isActive,
      LanguageProvider lp,
      ) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(lp.getText('error_something_wrong')));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status =
          (data['status'] ?? '').toString().toLowerCase().trim();
          return isActive
              ? status != 'delivered' && status != 'cancelled'
              : status == 'delivered';
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(lp.getText('no_orders'),
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: filteredDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildOrderCard(
              context: context,
              orderId: doc.id,
              data: data,
              accent: accent,
              isActive: isActive,
              lp: lp,
            );
          }).toList(),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Order card
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildOrderCard({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> data,
    required Color accent,
    required bool isActive,
    required LanguageProvider lp,
  }) {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    final String restaurant =
        data['restaurantName'] ?? lp.getText('unknown_restaurant');
    final String status = data['status'] ?? "Pending";
    final String price =
        "${(data['totalPrice'] ?? 0).toStringAsFixed(2)} EGP";
    final String date = data['timestamp'] != null
        ? DateFormat('MMM d, yyyy')
        .format((data['timestamp'] as Timestamp).toDate())
        : lp.getText('recently');

    Color statusColor;
    String statusText;
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
      child: InkWell(
        onTap: () {
          audio.speak(
            lp.isEnglish
                ? "Your order from $restaurant is currently $statusText"
                : "طلبك من $restaurant حالته حالياً هي $statusText",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── Header row ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text(
                        "${(data['items'] as List).length} ${lp.getText('items_label')} • $date",
                        style:
                        const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  Text(price,
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              const Divider(height: 30),
              // ── Status + action row ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status dot + label
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),

                  // Track / Reorder button
                  if (isActive)
                    ElevatedButton(
                      onPressed: () {
                        _shouldListen = false;
                        audio.speak(
                          lp.isEnglish
                              ? "Opening tracking."
                              : "جاري فتح التتبع.",
                          lp.isEnglish ? "en-US" : "ar-SA",
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TrackOrderScreen(orderId: orderId),
                          ),
                        ).then((_) {
                          _shouldListen = true;
                          _isProcessing = false;
                          final l = Provider.of<LanguageProvider>(context,
                              listen: false);
                          _speakIntro(l);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(lp.getText('track_order')),
                    )
                  else
                    OutlinedButton(
                      onPressed: () {
                        audio.speak(
                          lp.isEnglish
                              ? "Adding items to your cart."
                              : "تمت إضافة الطلب إلى السلة.",
                          lp.isEnglish ? "en-US" : "ar-SA",
                        );
                        final List<dynamic> orderItemsData =
                            data['items'] ?? [];
                        for (var itemMap in orderItemsData) {
                          cart.addItem(CartItem(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString() +
                                (itemMap['name'] ?? ""),
                            name: itemMap['name'] ?? "Unknown",
                            price: (itemMap['price'] as num?)?.toDouble() ??
                                0.0,
                            quantity: itemMap['quantity'] ?? 1,
                            restaurant: restaurant,
                            details: itemMap['details'] ?? "",
                            image: itemMap['image'] ?? "",
                          ));
                        }
                        _shouldListen = false;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CartScreen()),
                        ).then((_) {
                          _shouldListen = true;
                          _isProcessing = false;
                          final l = Provider.of<LanguageProvider>(context,
                              listen: false);
                          _speakIntro(l);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accent),
                        foregroundColor: accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(lp.getText('reorder')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small banner that shows the user which voice step is active
// ─────────────────────────────────────────────────────────────────────────────
class _VoiceStepBanner extends StatelessWidget {
  final _VoiceStep step;
  final LanguageProvider lp;

  const _VoiceStepBanner({required this.step, required this.lp});

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;

    switch (step) {
      case _VoiceStep.awaitingTabChoice:
        message = lp.isEnglish
            ? 'Say "active orders" or "past orders"'
            : 'قل "الطلبات النشطة" أو "الطلبات السابقة"';
        icon = Icons.swap_horiz_rounded;
        break;
      case _VoiceStep.awaitingActiveOrderName:
        message = lp.isEnglish
            ? 'Say the restaurant name to track'
            : 'قل اسم المطعم للتتبع';
        icon = Icons.location_on_outlined;
        break;
      case _VoiceStep.awaitingPastOrderName:
        message = lp.isEnglish
            ? 'Say the restaurant name to reorder'
            : 'قل اسم المطعم لإعادة الطلب';
        icon = Icons.replay_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFD32F2F).withOpacity(0.08),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFD32F2F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}