import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePaymentMethods();
    });
  }

  void _announcePaymentMethods() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop(); // Stops any lingering audio from the Cart/Checkout

    if (lp.isRTL) {
      audio.speak("صفحة طرق الدفع. يمكنك قول 'أضف بطاقة' أو 'الرجوع'.", "ar-EG");
    } else {
      audio.speak("Payment methods. You can say 'Add card' or 'Go back'.", "en-US");
    }
  }

  void _handleVoiceInteraction(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      // Detection for "Add Card" (Supports multiple Egyptian variations)
      if (command.contains("add") || command.contains("new") ||
          command.contains("أضف") || command.contains("جديد") ||
          command.contains("ضيف") || command.contains("كارت")) {

        audio.speak(lp.isRTL ? "جاري فتح إضافة البطاقة" : "Opening card form", lp.currentLanguage);
        if (mounted) _showAddCardDialog(context, currentUserId);
      }
      // Navigation Command
      else if (command.contains("back") || command.contains("رجوع") || command.contains("ارجع")) {
        await audio.stop();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFEB1B33);
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        title: Text(lp.isRTL ? "طرق الدفع" : "Payment Methods",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () async {
            await audio.stop();
            if (mounted) Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic,
                color: audio.isListening ? Colors.green : primaryRed),
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
            return const Center(child: CircularProgressIndicator(color: primaryRed));
          }

          var userData = snapshot.data?.data() as Map<String, dynamic>?;
          List methods = userData?['payment_methods'] ?? [];

          // Default "Placeholder" card if none exists
          Map<String, dynamic> card = methods.isNotEmpty
              ? methods[0]
              : {
            'cardHolder': 'Rawan Magdy',
            'cardNumber': '**** **** **** 0000',
            'expiry': 'MM/YY',
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Using your custom widget with an upgraded shadow
                _buildCreditCard(
                  (card['cardHolder'] ?? 'Rawan Magdy').toString().toUpperCase(),
                  card['cardNumber'] ?? '**** **** **** 0000',
                  card['expiry'] ?? 'MM/YY',
                  [const Color(0xFF1A1A1A), const Color(0xFF323232)],
                ),

                const SizedBox(height: 35),
                Text(
                  lp.isRTL ? "طرق دفع أخرى" : "Other Payment Methods",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                _buildPaymentOption(Icons.account_balance_wallet_outlined, "Google Pay", primaryRed),
                _buildPaymentOption(Icons.paypal_outlined, "PayPal", primaryRed),
                _buildPaymentOption(
                    Icons.add_card_outlined,
                    lp.isRTL ? "أضف بطاقة جديدة" : "Add New Card",
                    primaryRed,
                    isAction: true,
                    onTap: () => _showAddCardDialog(context, currentUserId)
                ),

                const SizedBox(height: 50),
                _buildSecureFooter(lp),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecureFooter(LanguageProvider lp) {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, size: 16, color: Colors.green[600]),
              const SizedBox(width: 8),
              Text(
                lp.isRTL ? "دفع آمن بتشفير SSL" : "Secure 256-bit SSL Encryption",
                style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Opacity(
            opacity: 0.5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.credit_card, size: 20),
                const SizedBox(width: 10),
                const Icon(Icons.payment, size: 20),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showAddCardDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(Provider.of<LanguageProvider>(context, listen: false).isRTL ? "إضافة بطاقة" : "Add New Card"),
        content: const Text("Would you like to simulate adding a new card to your wallet?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey[600]))
          ),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEB1B33),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () {
                DatabaseService().addPaymentMethod(userId, {
                  'cardHolder': 'Rawan Magdy',
                  'cardNumber': '**** **** **** 1234',
                  'expiry': '12/30',
                });
                Navigator.pop(context);
              },
              child: const Text("Confirm", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(String name, String number, String expiry, List<Color> colors) {
    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.wifi, color: Colors.white54, size: 24),
              Text("VISA", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
            ],
          ),
          Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w600, fontFamily: 'Courier'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("HOLDER", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("VALID THRU", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                  Text(expiry, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Icon(icon, color: isAction ? accent : Colors.black87),
        title: Text(title, style: TextStyle(fontWeight: isAction ? FontWeight.bold : FontWeight.w500, color: isAction ? accent : Colors.black87)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black26),
        onTap: onTap ?? () {},
      ),
    );
  }
}