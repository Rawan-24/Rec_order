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

enum _VoiceStep {
  awaitingTabChoice,
  awaitingActiveOrderIndex,
  awaitingPastOrderIndex,
}

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  _VoiceStep _voiceStep = _VoiceStep.awaitingTabChoice;
  bool _shouldListen = true;
  bool _isProcessing = false;

  // ✅ Local cached order lists for index-based selection
  List<Map<String, dynamic>> _activeOrdersList = [];
  List<String>               _activeOrderIds   = [];
  List<Map<String, dynamic>> _pastOrdersList   = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp    = Provider.of<LanguageProvider>(context, listen: false);
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

  // ── Intro ──────────────────────────────────────────────────────────────────
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

  // ── Listen loop ────────────────────────────────────────────────────────────
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

        final response = await AIService.sendMessage(text, screen: "order_history");
        final command  = (response['command'] ?? "unknown").toString();
        debugPrint("AI COMMAND (History): $command");

        await _handleCommand(command, response, text, lp);
        _isProcessing = false;
      },
      onError: (e) => debugPrint("STT error: $e"),
    );
  }

  // ── Master router ──────────────────────────────────────────────────────────
  Future<void> _handleCommand(
      String command,
      Map<String, dynamic> response,
      String rawText,
      LanguageProvider lp,
      ) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (command == "go_back") {
      _shouldListen = false;
      await audio.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.pop(context);
      return;
    }

    switch (_voiceStep) {
      case _VoiceStep.awaitingTabChoice:
        await _handleTabChoice(command, rawText, lp);
        break;
      case _VoiceStep.awaitingActiveOrderIndex:
        await _handleActiveOrderIndex(command, response, rawText, lp);
        break;
      case _VoiceStep.awaitingPastOrderIndex:
        await _handlePastOrderIndex(command, response, rawText, lp);
        break;
    }
  }

  // ── Step 1: Tab choice ─────────────────────────────────────────────────────
  Future<void> _handleTabChoice(
      String command,
      String rawText,
      LanguageProvider lp,
      ) async {
    final lower = rawText.toLowerCase();

    final bool wantsActive = command == "open_active_orders" ||
        command == "track_active_order" ||
        lower.contains("active") ||
        lower.contains("current") ||
        lower.contains("نشط") ||
        lower.contains("الجارية") ||
        lower.contains("الحالية") ||
        lower.contains("النشطة");

    final bool wantsPast = command == "open_past_orders" ||
        command == "reorder_last" ||
        lower.contains("past") ||
        lower.contains("previous") ||
        lower.contains("history") ||
        lower.contains("سابق") ||
        lower.contains("قديم") ||
        lower.contains("السابقة");

    if (wantsActive) {
      _tabController.animateTo(0);
      setState(() => _voiceStep = _VoiceStep.awaitingActiveOrderIndex);
      await _readActiveOrdersList(lp);
    } else if (wantsPast) {
      _tabController.animateTo(1);
      setState(() => _voiceStep = _VoiceStep.awaitingPastOrderIndex);
      await _readPastOrdersList(lp);
    } else {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      await audio.speak(
        lp.isEnglish
            ? "Please say active orders or past orders."
            : "من فضلك قل الطلبات النشطة أو الطلبات السابقة.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    }
  }

  // ── Read active orders aloud ───────────────────────────────────────────────
  Future<void> _readActiveOrdersList(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final user  = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await DatabaseService().getActiveOrders(user.uid).first;
      final docs = snapshot.docs.where((doc) {
        final data   = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString().toLowerCase().trim();
        return status != 'delivered' && status != 'cancelled';
      }).toList();

      _activeOrdersList = docs.map((d) => d.data() as Map<String, dynamic>).toList();
      _activeOrderIds   = docs.map((d) => d.id).toList();

      if (_activeOrdersList.isEmpty) {
        await audio.speak(
          lp.isEnglish ? "No active orders found." : "لا توجد طلبات نشطة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _resetToTabStep(lp);
        return;
      }

      await audio.speak(
        lp.isEnglish
            ? "You have ${_activeOrdersList.length} active orders."
            : "لديك ${_activeOrdersList.length} طلبات نشطة.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );

      for (int i = 0; i < _activeOrdersList.length; i++) {
        final order      = _activeOrdersList[i];
        final restaurant = order['restaurantName'] ?? '';
        final status     = order['status'] ?? '';
        final total      = (order['totalPrice'] ?? 0).toStringAsFixed(2);
        final items      = (order['items'] as List? ?? []);
        final itemNames  = items.map((it) => it['name'] ?? '').join(', ');

        await audio.speak(
          lp.isEnglish
              ? "Order ${i + 1}: $restaurant. $itemNames. Total $total pounds. Status: $status."
              : "طلب ${i + 1}: $restaurant. $itemNames. الإجمالي $total جنيه. الحالة: $status.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
      }

      await audio.speak(
        lp.isEnglish
            ? "Say order 1, order 2, or just the number to track it."
            : "قل طلب 1 أو طلب 2 أو فقط الرقم لتتبعه.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    } catch (e) {
      debugPrint("_readActiveOrdersList error: $e");
    }
  }

  // ── Read past orders aloud ─────────────────────────────────────────────────
  Future<void> _readPastOrdersList(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final user  = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await DatabaseService().getPastOrders(user.uid).first;
      final docs = snapshot.docs.where((doc) {
        final data   = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString().toLowerCase().trim();
        return status == 'delivered';
      }).toList();

      _pastOrdersList = docs.map((d) => d.data() as Map<String, dynamic>).toList();

      if (_pastOrdersList.isEmpty) {
        await audio.speak(
          lp.isEnglish ? "No past orders found." : "لا توجد طلبات سابقة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _resetToTabStep(lp);
        return;
      }

      await audio.speak(
        lp.isEnglish
            ? "You have ${_pastOrdersList.length} past orders."
            : "لديك ${_pastOrdersList.length} طلبات سابقة.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );

      for (int i = 0; i < _pastOrdersList.length; i++) {
        final order      = _pastOrdersList[i];
        final restaurant = order['restaurantName'] ?? '';
        final total      = (order['totalPrice'] ?? 0).toStringAsFixed(2);
        final items      = (order['items'] as List? ?? []);
        final itemNames  = items.map((it) => it['name'] ?? '').join(', ');

        await audio.speak(
          lp.isEnglish
              ? "Order ${i + 1}: $restaurant. $itemNames. Total $total pounds."
              : "طلب ${i + 1}: $restaurant. $itemNames. الإجمالي $total جنيه.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
      }

      await audio.speak(
        lp.isEnglish
            ? "Say order 1, order 2, or just the number to reorder."
            : "قل طلب 1 أو طلب 2 أو فقط الرقم لإعادة الطلب.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    } catch (e) {
      debugPrint("_readPastOrdersList error: $e");
    }
  }

  // ── Step 2A: Active order index handler ────────────────────────────────────
  Future<void> _handleActiveOrderIndex(
      String command,
      Map<String, dynamic> response,
      String rawText,
      LanguageProvider lp,
      ) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (command == "go_back") { await _speakIntro(lp); return; }

    // Get index from AI first, then fallback to raw text parser
    int? index;
    if (command == "select_order") {
      index = int.tryParse((response['value'] ?? "").toString().trim());
    }
    index ??= _parseIndexFromText(rawText);

    if (index == null || index < 1 || index > _activeOrdersList.length) {
      await audio.speak(
        lp.isEnglish
            ? "Please say a number between 1 and ${_activeOrdersList.length}."
            : "من فضلك قل رقم بين 1 و ${_activeOrdersList.length}.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      return;
    }

    final orderId = _activeOrderIds[index - 1];
    await audio.speak(
      lp.isEnglish
          ? "Opening tracking for order $index."
          : "فتح تتبع الطلب $index.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
    _navigateToTrack(orderId, lp);
  }

  // ── Step 2B: Past order index handler ─────────────────────────────────────
  Future<void> _handlePastOrderIndex(
      String command,
      Map<String, dynamic> response,
      String rawText,
      LanguageProvider lp,
      ) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final cart  = Provider.of<CartProvider>(context, listen: false);

    if (command == "go_back") { await _speakIntro(lp); return; }

    int? index;
    if (command == "select_order") {
      index = int.tryParse((response['value'] ?? "").toString().trim());
    }
    index ??= _parseIndexFromText(rawText);

    if (index == null || index < 1 || index > _pastOrdersList.length) {
      await audio.speak(
        lp.isEnglish
            ? "Please say a number between 1 and ${_pastOrdersList.length}."
            : "من فضلك قل رقم بين 1 و ${_pastOrdersList.length}.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      return;
    }

    final order      = _pastOrdersList[index - 1];
    final restaurant = order['restaurantName'] ?? '';
    await _addOrderToCart(order, cart);
    await audio.speak(
      lp.isEnglish
          ? "Added order $index from $restaurant to cart. Opening cart."
          : "تمت إضافة الطلب $index من $restaurant للسلة. جاري فتح السلة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
    _navigateToCart(lp);
  }

  // ── Parse index from raw speech ────────────────────────────────────────────
  int? _parseIndexFromText(String text) {
    final lower = text.toLowerCase().trim();

    // Arabic ordinals and numbers
    if (lower.contains('الأول')  || lower.contains('الاول')  ||
        lower.contains('واحد')   || lower.contains('أول')) return 1;
    if (lower.contains('الثاني') || lower.contains('التاني') ||
        lower.contains('اتنين')  || lower.contains('ثاني')   ||
        lower.contains('تاني'))  return 2;
    if (lower.contains('الثالث') || lower.contains('التالت') ||
        lower.contains('تلاتة') || lower.contains('ثالث')   ||
        lower.contains('تالت'))  return 3;
    if (lower.contains('الرابع') || lower.contains('اربعة')  ||
        lower.contains('رابع'))  return 4;
    if (lower.contains('الخامس') || lower.contains('خمسة')   ||
        lower.contains('خامس'))  return 5;

    // English and digits
    final match = RegExp(r'\b([1-9])\b').firstMatch(lower);
    if (match != null) return int.tryParse(match.group(1)!);

    return null;
  }

  // ── Add order items to cart ────────────────────────────────────────────────
  Future<void> _addOrderToCart(
      Map<String, dynamic> data,
      CartProvider cart,
      ) async {
    final items          = (data['items'] as List? ?? []);
    final restaurantName = data['restaurantName'] ?? '';
    for (final im in items) {
      cart.addItem(CartItem(
        id:         DateTime.now().millisecondsSinceEpoch.toString() + (im['name'] ?? ''),
        name:       im['name']       ?? 'Unknown',
        price:      (im['price'] as num?)?.toDouble() ?? 0.0,
        quantity:   im['quantity']   ?? 1,
        restaurant: restaurantName,
        details:    im['details']    ?? '',
        image:      im['image']      ?? '',
      ));
    }
  }

  // ── Reset to tab step ──────────────────────────────────────────────────────
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

  // ── Navigation ─────────────────────────────────────────────────────────────
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

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp         = Provider.of<LanguageProvider>(context);
    const primaryRed = Color(0xFFD32F2F);
    final user       = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(lp.getText('order_history'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            onTap: (index) {
              setState(() {
                _voiceStep = index == 0
                    ? _VoiceStep.awaitingActiveOrderIndex
                    : _VoiceStep.awaitingPastOrderIndex;
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
            // ✅ Only voice hint rebuilds when audio changes
            Consumer<AppAudioProvider>(
              builder: (_, audio, __) =>
                  _VoiceStepBanner(step: _voiceStep, lp: lp, audio: audio),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderList(
                    DatabaseService().getActiveOrders(user.uid),
                    primaryRed, true, lp,
                  ),
                  _buildOrderList(
                    DatabaseService().getPastOrders(user.uid),
                    primaryRed, false, lp,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Consumer<AppAudioProvider>(
          builder: (_, audio, __) => FloatingActionButton(
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
      ),
    );
  }

  // ── Order list ─────────────────────────────────────────────────────────────
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
          final data   = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase().trim();
          return isActive
              ? status != 'delivered' && status != 'cancelled'
              : status == 'delivered';
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(lp.getText('no_orders'),
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc  = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildOrderCard(
              context:  context,
              orderId:  doc.id,
              data:     data,
              index:    index + 1,
              accent:   accent,
              isActive: isActive,
              lp:       lp,
            );
          },
        );
      },
    );
  }

  // ── Order card ─────────────────────────────────────────────────────────────
  Widget _buildOrderCard({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> data,
    required int index,
    required Color accent,
    required bool isActive,
    required LanguageProvider lp,
  }) {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final cart  = Provider.of<CartProvider>(context, listen: false);

    final String restaurant = data['restaurantName'] ?? lp.getText('unknown_restaurant');
    final String status     = data['status'] ?? "Pending";
    final String price      = "${(data['totalPrice'] ?? 0).toStringAsFixed(2)} EGP";
    final String date       = data['timestamp'] != null
        ? DateFormat('MMM d, yyyy').format((data['timestamp'] as Timestamp).toDate())
        : lp.getText('recently');

    Color  statusColor;
    String statusText;
    switch (status.toLowerCase()) {
      case 'preparing':
        statusColor = Colors.orange;
        statusText  = lp.getText('status_preparing');
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusText  = lp.getText('status_delivered');
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText  = lp.getText('status_cancelled');
        break;
      case 'on the way':
        statusColor = Colors.blue;
        statusText  = lp.getText('status_on_way');
        break;
      default:
        statusColor = Colors.grey;
        statusText  = status;
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
                ? "Order $index: $restaurant is currently $statusText."
                : "الطلب $index: $restaurant حالته حالياً هي $statusText.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Show order number for blind user reference
                      Text(
                        "Order $index — $restaurant",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${(data['items'] as List).length} ${lp.getText('items_label')} • $date",
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
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
                  if (isActive)
                    ElevatedButton(
                      onPressed: () {
                        _shouldListen = false;
                        audio.speak(
                          lp.isEnglish ? "Opening tracking." : "جاري فتح التتبع.",
                          lp.isEnglish ? "en-US" : "ar-SA",
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TrackOrderScreen(orderId: orderId)),
                        ).then((_) {
                          _shouldListen = true;
                          _isProcessing = false;
                          _speakIntro(lp);
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
                              ? "Adding order $index to your cart."
                              : "تمت إضافة الطلب $index إلى السلة.",
                          lp.isEnglish ? "en-US" : "ar-SA",
                        );
                        final List<dynamic> orderItemsData = data['items'] ?? [];
                        for (var itemMap in orderItemsData) {
                          cart.addItem(CartItem(
                            id:         DateTime.now().millisecondsSinceEpoch.toString() +
                                (itemMap['name'] ?? ""),
                            name:       itemMap['name']     ?? "Unknown",
                            price:      (itemMap['price'] as num?)?.toDouble() ?? 0.0,
                            quantity:   itemMap['quantity'] ?? 1,
                            restaurant: restaurant,
                            details:    itemMap['details']  ?? "",
                            image:      itemMap['image']    ?? "",
                          ));
                        }
                        _shouldListen = false;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        ).then((_) {
                          _shouldListen = true;
                          _isProcessing = false;
                          _speakIntro(lp);
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

// ── Voice step banner ──────────────────────────────────────────────────────
class _VoiceStepBanner extends StatelessWidget {
  final _VoiceStep step;
  final LanguageProvider lp;
  final AppAudioProvider audio;

  const _VoiceStepBanner({
    required this.step,
    required this.lp,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    String  message;
    IconData icon;

    switch (step) {
      case _VoiceStep.awaitingTabChoice:
        message = lp.isEnglish
            ? 'Say "active orders" or "past orders"'
            : 'قل "الطلبات النشطة" أو "الطلبات السابقة"';
        icon = Icons.swap_horiz_rounded;
        break;
      case _VoiceStep.awaitingActiveOrderIndex:
        message = lp.isEnglish
            ? audio.lastWords.isNotEmpty
            ? audio.lastWords
            : 'Say "order 1", "order 2"... to track'
            : audio.lastWords.isNotEmpty
            ? audio.lastWords
            : 'قل "طلب 1" أو "طلب 2" للتتبع';
        icon = Icons.location_on_outlined;
        break;
      case _VoiceStep.awaitingPastOrderIndex:
        message = lp.isEnglish
            ? audio.lastWords.isNotEmpty
            ? audio.lastWords
            : 'Say "order 1", "order 2"... to reorder'
            : audio.lastWords.isNotEmpty
            ? audio.lastWords
            : 'قل "طلب 1" أو "طلب 2" لإعادة الطلب';
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
          Icon(
            audio.isListening ? Icons.graphic_eq : Icons.mic_none,
            size: 16,
            color: audio.isListening ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }
}