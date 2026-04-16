import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
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
        ? "سجل الطلبات. المساعد الشخصي جاهز، يمكنك قول تتبع الطلب."
        : "Order history. Assistant mode is active, you can say track my order.";
    audio.speak(msg, lp.currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text(lp.getText('order_history'), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
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
        // Local FAB removed. GlobalVoiceWrapper handles the mic now.
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
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120), // Added bottom padding
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildOrderCard(
              context: context,
              orderId: doc.id,
              restaurant: data['restaurantName'] ?? lp.getText('unknown_restaurant'),
              date: data['timestamp'] != null
                  ? DateFormat('MMM d, yyyy').format((data['timestamp'] as Timestamp).toDate())
                  : lp.getText('recently'),
              status: data['status'] ?? "Pending",
              items: "${data['items']?.length ?? 0} ${lp.getText('items_label')}",
              price: "${(data['totalPrice'] ?? 0).toStringAsFixed(0)} EGP",
              accent: accent,
              showTrackButton: isActive,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOrderCard({
    required BuildContext context,
    required String orderId,
    required String restaurant,
    required String date,
    required String status,
    required String items,
    required String price,
    required Color accent,
    bool showTrackButton = false,
  }) {
    Color statusColor;
    String statusText;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    switch (status.toLowerCase()) {
      case 'preparing':
        statusColor = Colors.orange;
        statusText = lp.getText('status_preparing');
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusText = lp.getText('status_delivered');
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
                      Text("$items • $date", style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
                  if (showTrackButton)
                    ElevatedButton(
                      onPressed: () {
                        audio.speak(lp.isRTL ? "جاري فتح تتبع الطلب" : "Opening tracking", lp.currentLanguage);
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
                        audio.speak(lp.isRTL ? "إعادة الطلب" : "Reordering", lp.currentLanguage);
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