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
    // Use addPostFrameCallback to ensure the context is ready for Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePaymentMethods();
    });
  }

  // FIXED: Added proper await logic and stops previous speech
  void _announcePaymentMethods() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop(); // Clear any audio from the Cart Screen

    if (lp.isRTL) {
      await audio.speak("صفحة طرق الدفع.", "ar-EG");
      await Future.delayed(const Duration(milliseconds: 300));
      await audio.speak("يمكنك قول 'أضف بطاقة جديدة' لتحديث بياناتك.", "ar-EG");
    } else {
      await audio.speak("Payment methods. You can say 'Add new card' to update your info.", "en-US");
    }
  }

  void _handleVoiceInteraction(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      // Trigger Add New Card
      if (command.contains("add") || command.contains("new") || command.contains("أضف") || command.contains("جديدة")) {
        await audio.speak(lp.isRTL ? "جاري فتح نموذج الإضافة" : "Opening card form", lp.currentLanguage);
        if (mounted) _showAddCardDialog(context, currentUserId);
      }
      // Go Back
      else if (command.contains("back") || command.contains("ارجع")) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFEB1B33); // Matched your project red
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4), // Standardized background
      appBar: AppBar(
        title: Text(lp.isRTL ? "طرق الدفع" : "Payment Methods",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No user data found."));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          List methods = userData['payment_methods'] ?? [];

          // Standardized card mapping
          Map<String, dynamic> card = methods.isNotEmpty
              ? methods[0]
              : {
            'cardHolder': 'NO CARD ADDED',
            'cardNumber': '**** **** **** ****',
            'expiry': '--/--',
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCreditCard(
                  (card['cardHolder'] ?? 'Rawan Magdy').toString().toUpperCase(),
                  card['cardNumber'] ?? '**** **** **** 5678',
                  card['expiry'] ?? '05/29',
                  [const Color(0xFF1A1A1A), const Color(0xFF424242)], // Sleek dark theme
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
              Icon(Icons.lock_outline, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 5),
              Text(
                lp.isRTL ? "دفع آمن بتشفير SSL" : "Secure 256-bit SSL Encryption",
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Image.network(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Visa_Inc._logo.svg/2560px-Visa_Inc._logo.svg.png',
            height: 20,
            color: Colors.grey.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  void _showAddCardDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(Provider.of<LanguageProvider>(context).isRTL ? "إضافة بطاقة" : "Add New Card"),
        content: const Text("This opens the secure Firebase payment gateway."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEB1B33)),
              onPressed: () {
                DatabaseService().addPaymentMethod(userId, {
                  'cardHolder': 'Rawan Magdy',
                  'cardNumber': '**** **** **** 1234',
                  'expiry': '12/30',
                });
                Navigator.pop(context);
              },
              child: const Text("Add Card", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(String name, String number, String expiry, List<Color> colors) {
    return Container(
      width: double.infinity,
      height: 210,
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
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 10),
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
              const Text(
                "VISA",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.w500),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CARD HOLDER", style: TextStyle(color: Colors.white60, fontSize: 9)),
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("EXPIRES", style: TextStyle(color: Colors.white60, fontSize: 9)),
                  Text(expiry, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Icon(icon, color: isAction ? accent : Colors.black87),
        title: Text(title, style: TextStyle(fontWeight: isAction ? FontWeight.bold : FontWeight.normal, color: isAction ? accent : Colors.black87)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        onTap: onTap ?? () {},
      ),
    );
  }
}