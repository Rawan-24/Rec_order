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
import 'TrackOrderScreen.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late LanguageProvider lp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceHistoryStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    lp = Provider.of<LanguageProvider>(context);
  }

  void _announceHistoryStatus() {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    String msg = lp.isRTL
        ? "سجل الطلبات. يمكنك تتبع طلباتك الحالية أو إعادة طلب وجباتك السابقة."
        : "Order history. You can track active orders or reorder from your past meals.";
    audio.speak(msg, lp.currentLanguage);
  }

  void _handleVoiceCommand(BuildContext context, AppAudioProvider audio) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      if (command.contains("تتبع") || command.contains("فين") || command.contains("track")) {
        audio.speak(lp.isRTL ? "بفتح صفحة التتبع" : "Opening tracking page", lp.currentLanguage);
        String? id = await DatabaseService().getActiveOrderId();
        if (mounted && id != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => TrackOrderScreen(orderId: id)));
        } else {
          audio.speak(lp.isRTL ? "لا توجد طلبات نشطة حالياً" : "No active orders found", lp.currentLanguage);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFD32F2F);
    final audio = Provider.of<AppAudioProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(lp.getText('order_history'), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: lp.getText('active_orders')),
              Tab(text: lp.getText('past_orders')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList(DatabaseService().getActiveOrders(user.uid), primaryRed, true),
            _buildOrderList(DatabaseService().getPastOrders(user.uid), primaryRed, false),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: audio.isListening ? Colors.green : primaryRed,
          onPressed: () => _handleVoiceCommand(context, audio),
          child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildOrderList(Stream<QuerySnapshot> stream, Color accent, bool isActive) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(lp.getText('error_something_wrong')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(lp.getText('no_orders'), style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildOrderCard(
              context: context,
              orderId: doc.id,
              data: data,
              accent: accent,
              isActive: isActive,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOrderCard({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> data,
    required Color accent,
    required bool isActive,
  }) {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    String restaurant = data['restaurantName'] ?? lp.getText('unknown_restaurant');
    String status = data['status'] ?? "Pending";
    String price = "${(data['totalPrice'] ?? 0).toStringAsFixed(2)} EGP";
    String date = data['timestamp'] != null
        ? DateFormat('MMM d, yyyy').format((data['timestamp'] as Timestamp).toDate())
        : lp.getText('recently');

    Color statusColor;
    String statusText;
    switch (status.toLowerCase()) {
      case 'preparing': statusColor = Colors.orange; statusText = lp.getText('status_preparing'); break;
      case 'delivered': statusColor = Colors.green; statusText = lp.getText('status_delivered'); break;
      case 'cancelled': statusColor = Colors.red; statusText = lp.getText('status_cancelled'); break;
      case 'on the way': statusColor = Colors.blue; statusText = lp.getText('status_on_way'); break;
      default: statusColor = Colors.grey; statusText = status;
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
          String speechStatus = lp.isRTL
              ? "طلبك من $restaurant حالته حالياً هي $statusText"
              : "Your order from $restaurant is currently $statusText";
          audio.speak(speechStatus, lp.currentLanguage);
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
                      Text(restaurant, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text("${(data['items'] as List).length} ${lp.getText('items_label')} • $date",
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  if (isActive)
                    ElevatedButton(
                      onPressed: () {
                        audio.speak(lp.isRTL ? "جاري فتح تفاصيل التتبع" : "Opening tracking details", lp.currentLanguage);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => TrackOrderScreen(orderId: orderId)));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(lp.getText('track_order')),
                    )
                  else
                    OutlinedButton(
                      onPressed: () {
                        // 1. Voice feedback (Immediate start, doesn't block code)
                        audio.speak(
                            lp.isRTL ? "تم إضافة الطلب إلى السلة" : "Adding items to your cart",
                            lp.currentLanguage
                        );

                        // 2. Add items to cart
                        final List<dynamic> orderItemsData = data['items'] ?? [];
                        for (var itemMap in orderItemsData) {
                          cart.addItem(CartItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString() + (itemMap['name'] ?? ""),
                            name: itemMap['name'] ?? "Unknown",
                            price: (itemMap['price'] as num?)?.toDouble() ?? 0.0,
                            quantity: itemMap['quantity'] ?? 1,
                            restaurant: restaurant,
                            details: itemMap['details'] ?? "",
                            image: itemMap['image'] ?? "",
                          ));
                        }

                        // 3. Navigation (Immediate)
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const CartScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accent),
                        foregroundColor: accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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