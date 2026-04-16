import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Added
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/TrackOrderScreen.dart';

class PaymentScreen extends StatefulWidget {
  static const String routeName = "PaymentScreen";
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = 'card';
  bool isVoiceConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePayment();
    });
  }

  void _announcePayment() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop(); // Stop any lingering "Added to cart" audio

    String msg = lp.isRTL
        ? "وصلنا للدفع. يمكنك اختيار كاش أو بطاقة، ثم اضغط على بصمة الصوت للتأكيد."
        : "Payment screen. Select cash or card, then use the Voice PIN to confirm.";
    audio.speak(msg, lp.currentLanguage);
  }

  // New: Voice recognition for the Confirmation Step
  void _handleVoiceConfirmation(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      if (command.contains("confirm") || command.contains("تأكيد") || command.contains("ادفع")) {
        setState(() => isVoiceConfirmed = true);
        await audio.speak(lp.isRTL ? "تم تأكيد الهوية صوتياً" : "Voice identity confirmed", lp.currentLanguage);
      } else {
        audio.speak(lp.isRTL ? "عذراً، لم أسمع كلمة تأكيد" : "Sorry, I didn't hear the confirmation word", lp.currentLanguage);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final cart = Provider.of<CartProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            await audio.stop();
            if (mounted) Navigator.pop(context);
          },
        ),
        title: Text(lp.getText('payment_title'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFFEB1B33),
                child: Icon(Icons.payment, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 20),
            _buildVoiceTip(lp, audio),
            const SizedBox(height: 30),
            Text(lp.getText('select_payment_method'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildPaymentOption(
              id: 'card',
              title: lp.getText('credit_card'),
              subtitle: lp.getText('secure_payment'),
              icon: Icons.credit_card,
            ),
            const SizedBox(height: 10),
            _buildPaymentOption(
              id: 'cash',
              title: lp.getText('cash_on_delivery'),
              subtitle: lp.getText('pay_on_receive'),
              icon: Icons.money,
            ),
            const SizedBox(height: 30),
            if (selectedMethod == 'card') ...[
              Text(lp.getText('card_details'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildTextField(lp.getText('card_number'), "**** **** **** 5678"),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTextField(lp.getText('expiry_date'), "MM/YY")),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField(lp.getText('cvv'), "CVV")),
                ],
              ),
              const SizedBox(height: 25),
              Text(lp.getText('confirmation'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildVoicePinButton(lp, audio), // Updated to pass audio provider
            ],
            const SizedBox(height: 20),
            _buildSecurePaymentNote(lp),
            const SizedBox(height: 20),
            _buildOrderSummary(lp, cart),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomPayButton(lp, cart, audio),
    );
  }

  Widget _buildVoiceTip(LanguageProvider lp, AppAudioProvider audio) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: audio.isListening ? Colors.green.withOpacity(0.1) : const Color(0xFFD6E0E0),
        borderRadius: BorderRadius.circular(15),
        border: audio.isListening ? Border.all(color: Colors.green) : null,
      ),
      child: Row(
        children: [
          Icon(Icons.mic, color: audio.isListening ? Colors.green : Colors.teal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                audio.isListening && audio.lastWords.isNotEmpty ? audio.lastWords : lp.getText('payment_voice_hint'),
                style: const TextStyle(color: Colors.black54, fontSize: 13)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({required String id, required String title, required String subtitle, required IconData icon}) {
    bool isSelected = selectedMethod == id;
    return GestureDetector(
      onTap: () => setState(() => selectedMethod = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEB1B33) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildVoicePinButton(LanguageProvider lp, AppAudioProvider audio) {
    final bool isListening = audio.isListening;
    final Color backgroundColor = isVoiceConfirmed ? Colors.green : (isListening ? Colors.orange : Colors.white);
    final Color contentColor = isVoiceConfirmed || isListening ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () => _handleVoiceConfirmation(audio, lp),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: isVoiceConfirmed || isListening ? null : Border.all(color: Colors.black12),
          boxShadow: isListening ? [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 10)] : [],
        ),
        child: Row(
          children: [
            Icon(isListening ? Icons.graphic_eq : Icons.mic_none, color: contentColor, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      isListening ? "Listening..." : (isVoiceConfirmed ? lp.getText('voice_confirmed') : lp.getText('voice_pin_title')),
                      style: TextStyle(color: contentColor, fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  Text(
                      isVoiceConfirmed ? "Identity Verified" : lp.getText('voice_pin_sub'),
                      style: TextStyle(color: contentColor.withOpacity(0.7), fontSize: 12)
                  ),
                ],
              ),
            ),
            if (isVoiceConfirmed) const Icon(Icons.verified_user, color: Colors.white, size: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurePaymentNote(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.withOpacity(0.2))
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(lp.getText('secure_note'), style: const TextStyle(color: Colors.black54, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(LanguageProvider lp, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _summaryRow(lp.getText('subtotal'), cart.subtotal),
          _summaryRow(lp.getText('delivery_fee'), cart.deliveryFee),
          _summaryRow(lp.getText('tax'), cart.tax),
          const Divider(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(lp.getText('total'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text("${cart.total.toStringAsFixed(2)} EGP", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFEB1B33)))
          ]),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label, style: const TextStyle(color: Colors.grey)), Text("${amount.toStringAsFixed(2)} EGP")]
      ),
    );
  }

  Widget _buildBottomPayButton(LanguageProvider lp, CartProvider cart, AppAudioProvider audio) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5))
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEB1B33),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: () async {
          if (selectedMethod == 'cash' || isVoiceConfirmed) {
            User? user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red)));

                String orderId = await DatabaseService().placeOrder(
                  userId: user.uid,
                  total: cart.total,
                  paymentMethod: selectedMethod,
                  restaurantName: cart.items.map((i) => i.restaurant).toSet().length > 1
                      ? "Multi-Restaurant Order"
                      : cart.items.first.restaurant,
                  restaurantImage: cart.items.isNotEmpty ? cart.items.first.image : "",
                  items: cart.items,
                  cartItems: cart.items,
                );

                await audio.stop();
                audio.speak(lp.isRTL ? "تم بنجاح! جاري تتبع الطلب" : "Success! Tracking your order now.", lp.currentLanguage);

                cart.clearCart();
                if (mounted) {
                  Navigator.pop(context); // Remove loading
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TrackOrderScreen(orderId: orderId)));
                }
              } catch (e) {
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${lp.getText('error')}: $e")));
              }
            }
          } else {
            audio.speak(lp.isRTL ? "من فضلك أكد هويتك بالصوت أولاً" : "Please confirm your identity by voice first", lp.currentLanguage);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lp.getText('confirm_voice_first'))));
          }
        },
        child: Text("${lp.getText('confirm_and_pay')}  ${cart.total.toStringAsFixed(2)} EGP", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}