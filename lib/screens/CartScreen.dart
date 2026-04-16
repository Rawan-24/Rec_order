import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/PaymentScreen.dart';

class CartScreen extends StatefulWidget {
  static const String routeName = "CartScreen";
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late LanguageProvider lp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCartSummary();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    lp = Provider.of<LanguageProvider>(context);
  }

  void _announceCartSummary() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Stop previous audio to clear the queue
    await audio.stop();

    if (cart.items.isEmpty) {
      await audio.speak(lp.isRTL ? "سلة التسوق فارغة" : "Your cart is empty", lp.currentLanguage);
    } else {
      // Logic for EGP announcement
      if (lp.isRTL) {
        await audio.speak("سلتك تحتوي على ${cart.items.length} أصناف.", "ar-EG");
        await audio.speak("المجموع الكلي هو ${cart.total.toStringAsFixed(0)} جنيه مصري.", "ar-EG");
      } else {
        await audio.speak("Your cart has ${cart.items.length} items. Your total is ${cart.total.toStringAsFixed(0)} EGP.", "en-US");
      }
    }
  }

  void _handleVoiceInteraction() {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      if (command.contains("checkout") || command.contains("pay") || command.contains("دفع") || command.contains("أكد")) {
        await audio.speak(lp.isRTL ? "جاري الانتقال لصفحة الدفع" : "Proceeding to payment", lp.currentLanguage);
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen()));
        }
      }
      else if (command.contains("back") || command.contains("ارجع")) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(lp.getText('your_cart'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildVoiceHeader(audio),
          Expanded(
            child: cart.items.isEmpty
                ? Center(child: Text(lp.isRTL ? "السلة فارغة" : "Your cart is empty"))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return _buildCartItem(item, cart, audio);
              },
            ),
          ),
          _buildSummarySection(cart, audio),
        ],
      ),
    );
  }

  Widget _buildVoiceHeader(AppAudioProvider audio) {
    return Column(
      children: [
        GestureDetector(
          onTap: _handleVoiceInteraction,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: audio.isListening ? Colors.green : const Color(0xFFEB1B33),
            child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFD6E0E0), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                Icon(Icons.mic, color: audio.isListening ? Colors.green : Colors.teal, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    audio.isListening ? (audio.lastWords.isEmpty ? "Listening..." : audio.lastWords) : lp.getText('cart_voice_hint'),
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItem item, CartProvider cart, AppAudioProvider audio) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                    Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(item.restaurant, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    // Say "Removed [Item Name]" properly in mixed languages
                    if (lp.isRTL) {
                      await audio.speak("تم حذف", "ar-EG");
                      await audio.speak(item.name, "en-US");
                    } else {
                      await audio.speak("Removed ${item.name}", "en-US");
                    }
                    cart.removeItem(item.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _qtyBtn(Icons.remove, () {
                      if (item.quantity > 1) cart.updateQuantity(item.id, item.quantity - 1);
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text("${item.quantity}", style: const TextStyle(fontSize: 16)),
                    ),
                    _qtyBtn(Icons.add, () => cart.updateQuantity(item.id, item.quantity + 1)),
                  ],
                ),
                Text(
                  "${(item.price * item.quantity).toStringAsFixed(2)} EGP",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEB1B33)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.black),
      ),
    );
  }

  Widget _buildSummarySection(CartProvider cart, AppAudioProvider audio) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _summaryRow(lp.getText('subtotal'), cart.subtotal),
          _summaryRow(lp.getText('delivery_fee'), cart.deliveryFee),
          _summaryRow(lp.getText('tax'), cart.tax),
          const Divider(),
          _summaryRow(lp.getText('total'), cart.total, isBold: true),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEB1B33),
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () async {
              await audio.speak(lp.isRTL ? "جاري الانتقال لصفحة الدفع" : "Going to payment", lp.currentLanguage);
              if (mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen()));
              }
            },
            child: Text(lp.getText('proceed_to_checkout'), style: const TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text("${value.toStringAsFixed(2)} EGP",
              style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: isBold ? const Color(0xFFEB1B33) : Colors.black)),
        ],
      ),
    );
  }
}