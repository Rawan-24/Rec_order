import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/TrackOrderScreen.dart';
import 'package:grad_project/Models/AddressModel.dart';

import 'Delivery_Address.dart';

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

    await audio.stop();

    if (lp.isRTL) {
      await audio.speak("لقد وصلت لصفحة الدفع.", "ar-EG");
      await Future.delayed(const Duration(milliseconds: 300));
      await audio.speak("اختر وسيلة الدفع أو قل 'تأكيد بالبصمة الصوتية'.", "ar-EG");
    } else {
      await audio.speak("You are at the payment screen. Select a method or say 'Confirm with voice PIN'.", "en-US");
    }
  }

  void _handleVoiceInteraction(AppAudioProvider audio, LanguageProvider lp, CartProvider cart) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      if (command.contains("cash") || command.contains("كاش") || command.contains("نقدي")) {
        setState(() => selectedMethod = 'cash');
        await audio.speak(lp.isRTL ? "تم التبديل للدفع النقدي" : "Switched to cash", lp.currentLanguage);
      } else if (command.contains("card") || command.contains("بطاقة")) {
        setState(() => selectedMethod = 'card');
        await audio.speak(lp.isRTL ? "تم التبديل للدفع بالبطاقة" : "Switched to card payment", lp.currentLanguage);
      }

      if (command.contains("pin") || command.contains("confirm") || command.contains("تأكيد")) {
        setState(() => isVoiceConfirmed = true);
        await audio.speak(lp.isRTL ? "تم التأكيد بالبصمة الصوتية" : "Voice PIN confirmed", lp.currentLanguage);
      }

      if (command.contains("place order") || command.contains("اطلب الآن")) {
        _processPayment(lp, cart);
      }
    });
  }

  Future<void> _processPayment(LanguageProvider lp, CartProvider cart) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      // 1. Show Loading indicator immediately
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFEB1B33)))
      );

      // 2. CHECK: Does the user have a delivery address?
      final addresses = await DatabaseService().getAddresses(user.uid).first;

      if (addresses.isEmpty) {
        if (mounted) Navigator.pop(context); // Remove loading

        await audio.speak(
            lp.isRTL ? "من فضلك أضف عنواناً أولاً" : "Please add a delivery address first",
            lp.currentLanguage
        );

        if (mounted) _showNoAddressDialog(lp);
        return;
      }

      // 3. PROCEED: If address exists, check payment verification
      if (selectedMethod == 'cash' || isVoiceConfirmed) {
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

        await audio.speak(lp.isRTL ? "تم تأكيد طلبك بنجاح" : "Your order has been placed successfully", lp.currentLanguage);

        cart.clearCart();
        if (mounted) {
          Navigator.pop(context); // Remove loading
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TrackOrderScreen(orderId: orderId)));
        }
      } else {
        if (mounted) Navigator.pop(context); // Remove loading
        await audio.speak(lp.isRTL ? "من فضلك أكد البصمة الصوتية أولاً" : "Please confirm your voice PIN first", lp.currentLanguage);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lp.getText('confirm_voice_first'))));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${lp.getText('error')}: $e")));
      }
    }
  }

  void _showNoAddressDialog(LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lp.isRTL ? "العنوان مطلوب" : "Address Required", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(lp.isRTL
            ? "يجب إضافة عنوان توصيل واحد على الأقل قبل إتمام الطلب."
            : "You must add at least one delivery address before placing your order."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lp.getText('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEB1B33),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DeliveryAddressesPage()));
            },
            child: Text(lp.isRTL ? "إضافة عنوان" : "Add Address", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(lp.getText('payment_title'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: () => _handleVoiceInteraction(audio, lp, cart),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: audio.isListening ? Colors.green : const Color(0xFFEB1B33),
                  child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildVoiceHint(audio, lp),
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
              _buildTextField(lp.getText('card_number'), "1234 5678 9012 3456"),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTextField(lp.getText('expiry_date'), "MM/YY")),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField(lp.getText('cvv'), "123")),
                ],
              ),
              const SizedBox(height: 25),
              Text(lp.getText('confirmation'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildVoicePinButton(lp),
            ],
            const SizedBox(height: 20),
            _buildSecurePaymentNote(lp),
            const SizedBox(height: 20),
            _buildOrderSummary(lp, cart),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomPayButton(lp, cart),
    );
  }

  // UI Helper widgets remain unchanged to maintain your design...
  Widget _buildVoiceHint(AppAudioProvider audio, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFD6E0E0), borderRadius: BorderRadius.circular(15)),
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
      child: Container(
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
            if (isSelected) const Icon(Icons.check_circle_outline, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildVoicePinButton(LanguageProvider lp) {
    final Color backgroundColor = isVoiceConfirmed ? const Color(0xFFEB1B33) : Colors.white;
    final Color contentColor = isVoiceConfirmed ? Colors.white : Colors.black87;
    final Color subTextColor = isVoiceConfirmed ? Colors.white70 : Colors.grey;

    return Material(
      color: backgroundColor,
      elevation: isVoiceConfirmed ? 0 : 2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => setState(() => isVoiceConfirmed = !isVoiceConfirmed),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isVoiceConfirmed ? null : Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              const Icon(Icons.mic_none, color: Colors.blueAccent, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lp.getText('voice_pin_title'), style: TextStyle(color: contentColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(lp.getText('voice_pin_sub'), style: TextStyle(color: subTextColor, fontSize: 13)),
                  ],
                ),
              ),
              if (isVoiceConfirmed) const Icon(Icons.check_circle_outline, color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurePaymentNote(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.withOpacity(0.2))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(lp.getText('secure_note'), style: const TextStyle(color: Colors.black54, fontSize: 12))),
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(lp.getText('subtotal')), Text("${cart.subtotal.toStringAsFixed(2)} EGP")]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(lp.getText('delivery_fee')), Text("${cart.deliveryFee.toStringAsFixed(2)} EGP")]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(lp.getText('tax')), Text("${cart.tax.toStringAsFixed(2)} EGP")]),
          const Divider(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(lp.getText('total'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text("${cart.total.toStringAsFixed(2)} EGP", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFEB1B33)))
          ]),
        ],
      ),
    );
  }

  Widget _buildBottomPayButton(LanguageProvider lp, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      color: Colors.white,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEB1B33),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: () => _processPayment(lp, cart),
        child: Text("${lp.getText('confirm_and_pay')} - ${cart.total.toStringAsFixed(2)} EGP", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}