import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart'; // Import
import 'package:grad_project/providers/AudioProvider.dart';    // Import
import 'package:provider/provider.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    // Start the voice feedback when the user lands on the page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePaymentMethods();
    });
  }

  void _announcePaymentMethods() {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    String msg = lp.isRTL
        ? "صفحة طرق الدفع. يمكنك قول 'أضف بطاقة جديدة' لتحديث بياناتك."
        : "Payment methods. You can say 'Add new card' to update your info.";
    audio.speak(msg, lp.currentLanguage);
  }

  void _handleVoiceInteraction(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) {
      String command = words.toLowerCase();

      // Trigger Add New Card
      if (command.contains("add") || command.contains("new") || command.contains("أضف") || command.contains("جديدة")) {
        audio.speak(lp.isRTL ? "جاري فتح نموذج الإضافة" : "Opening card form", lp.currentLanguage);
        _showAddCardDialog(context, currentUserId);
      }
      // Go Back
      else if (command.contains("back") || command.contains("ارجع")) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFD32F2F);
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(lp.isRTL ? "طرق الدفع" : "Payment Methods", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic),
            onPressed: () => _handleVoiceInteraction(audio, lp),
          )
        ],
      ),
      body: currentUserId.isEmpty
          ? const Center(child: Text("Please log in to manage payments"))
          : StreamBuilder<DocumentSnapshot>(
        stream: DatabaseService().getUserStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No user data found."));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          List methods = userData['payment_methods'] ?? [];

          Map<String, dynamic> card = methods.isNotEmpty
              ? methods[0]
              : {
            'cardHolder': lp.isRTL ? 'لا توجد بطاقة' : 'NO CARD ADDED',
            'cardNumber': '**** **** **** ****',
            'expiry': '--/--',
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCreditCard(
                  (card['cardHolder'] ?? 'Unknown').toString().toUpperCase(),
                  card['cardNumber'] ?? '**** **** **** ****',
                  card['expiry'] ?? '--/--',
                  [const Color(0xFFB71C1C), const Color(0xFFD32F2F)],
                ),

                const SizedBox(height: 30),

                Text(
                  lp.isRTL ? "طرق دفع أخرى" : "Other Payment Methods",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                _buildPaymentOption(Icons.account_balance_wallet_outlined, "Google Pay", primaryRed),
                _buildPaymentOption(Icons.paypal_outlined, "PayPal", primaryRed),

                _buildPaymentOption(
                    Icons.add_circle_outline,
                    lp.isRTL ? "أضف طريقة جديدة" : "Add New Method",
                    primaryRed,
                    isAction: true,
                    onTap: () => _showAddCardDialog(context, currentUserId)
                ),

                const SizedBox(height: 40),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 5),
                      Text(
                        lp.isRTL ? "دفع آمن بتشفير SSL" : "Secure 256-bit SSL Encrypted Payment",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
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

  void _showAddCardDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Card"),
        content: const Text("This would normally open a secure form to enter card details."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                DatabaseService().addPaymentMethod(userId, {
                  'cardHolder': 'Rawan Magdy',
                  'cardNumber': '**** **** **** 5678',
                  'expiry': '05/29',
                });
                Navigator.pop(context);
              },
              child: const Text("Simulate Add")
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(String name, String number, String expiry, List<Color> colors) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.contactless, color: Colors.white, size: 30),
              Text(
                "VISA",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
          Text(
            number,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, letterSpacing: 2, fontWeight: FontWeight.w500),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CARD HOLDER", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("EXPIRES", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  Text(expiry, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPaymentOption(IconData icon, String title, Color accent, {bool isAction = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Icon(icon, color: isAction ? accent : Colors.black87),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isAction ? FontWeight.bold : FontWeight.normal,
            color: isAction ? accent : Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap ?? () {},
      ),
    );
  }
}