import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/PaymentScreen.dart';

import '../services/ai_service.dart';

class CartScreen extends StatefulWidget {
  static const String routeName = "CartScreen";
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _shouldListen = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  // ── STEP 1: Updated _speakIntro with delete hint ──────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();
    await audio.speak(
      lp.isEnglish
          ? "Your cart. Say checkout to place your order, "
          "say delete followed by an item name to remove it, "
          "say clear cart to empty it, or say go back."
          : "سلتك. قل ادفع لإتمام الطلب، "
          "قل احذف ثم اسم العنصر لإزالته، "
          "قل امسح السلة لتفريغها، أو قل ارجع.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  // ── STEP 3: Updated call site — passes full response map ─────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (Cart): $text");
        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();
        debugPrint("AI COMMAND (Cart): $command");

        // ── STEP 3: Pass both command and full response map ──
        await _handleCommand(command, response, lp);

        _isProcessing = false;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) _startListening(lp);
        });
      },
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  // ── STEP 2 & 3: Updated signature + delete_cart_item case ────────────────
  Future<void> _handleCommand(
      String command, Map<String, dynamic> response, LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    switch (command) {
      case "proceed_to_checkout":
      case "confirm_cash_order":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Going to payment." : "جاري الانتقال لصفحة الدفع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentScreen()),
          ).then((_) {
            _shouldListen = true;
            _isProcessing = false;
            _speakIntro(lp);
          });
        }
        break;

      case "read_cart_total":
      case "read_order_total":
        await audio.speak(
          lp.isEnglish
              ? "Subtotal is ${cart.subtotal.toStringAsFixed(2)} pounds. "
              "Delivery fee is ${cart.deliveryFee.toStringAsFixed(2)} pounds. "
              "Tax is ${cart.tax.toStringAsFixed(2)} pounds. "
              "Your total is ${cart.total.toStringAsFixed(2)} Egyptian pounds."
              : "المجموع الفرعي ${cart.subtotal.toStringAsFixed(2)} جنيه. "
              "رسوم التوصيل ${cart.deliveryFee.toStringAsFixed(2)} جنيه. "
              "الضريبة ${cart.tax.toStringAsFixed(2)} جنيه. "
              "إجمالي طلبك ${cart.total.toStringAsFixed(2)} جنيه مصري.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "clear_cart":
        cart.clearCart();
        await audio.speak(
          lp.isEnglish ? "Cart cleared." : "تم مسح السلة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

    // ── FIX 1: Delete a named item from the cart ──────────────────────────
      case "delete_cart_item":
        final String itemName =
        (response['value'] ?? '').toString().trim().toLowerCase();
        if (itemName.isEmpty) {
          await audio.speak(
            lp.isEnglish
                ? "Which item would you like to delete?"
                : "أي عنصر تريد حذفه؟",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          break;
        }
        // Fuzzy match: remove first cart item whose name contains the spoken value
        final match = cart.items.firstWhere(
              (i) =>
          i.name.toLowerCase().contains(itemName) ||
              itemName.contains(i.name.toLowerCase()),
          orElse: () => null as dynamic,
        );
        if (match != null) {
          cart.removeItem(match.id);
          await audio.speak(
            lp.isEnglish
                ? "${match.name} removed from your cart."
                : "تم حذف ${match.name} من سلتك.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        } else {
          await audio.speak(
            lp.isEnglish
                ? "I could not find $itemName in your cart."
                : "لم أجد هذا العنصر في سلتك.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;

    // ── FIX 2: Go back ────────────────────────────────────────────────────
      case "go_back":
        _shouldListen = false;

        if (mounted) Navigator.pop(context);
        break;

      default:
        await audio.speak(
          lp.isEnglish
              ? "Say checkout to pay, how much for the total, or go back."
              : "قل ادفع للدفع، كام المبلغ للإجمالي، أو ارجع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
    }
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
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back,
              color: Colors.black),
          onPressed: () {
            _shouldListen = false;
            Navigator.pop(context);
          },
        ),
        title: Text(lp.getText('your_cart'),
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildVoiceHeader(audio, lp),
          Expanded(
            child: cart.items.isEmpty
                ? Center(
              child: Text(
                  lp.isEnglish ? "Your cart is empty" : "السلة فارغة"),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return _buildCartItem(item, cart, audio, lp);
              },
            ),
          ),
          _buildSummarySection(cart, audio, lp),
        ],
      ),
    );
  }

  Widget _buildVoiceHeader(AppAudioProvider audio, LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (!audio.speech.isListening && !_isProcessing) {
                _shouldListen = true;
                _startListening(lp);
              }
            },
            child: CircleAvatar(
              radius: 30,
              backgroundColor:
              audio.isListening ? Colors.green : const Color(0xFFEB1B33),
              child: Icon(
                audio.isListening ? Icons.graphic_eq : Icons.mic,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD6E0E0),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(Icons.mic,
                      color: audio.isListening ? Colors.green : Colors.teal,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      audio.isListening
                          ? (audio.lastWords.isEmpty
                          ? (lp.isEnglish
                          ? "Listening..."
                          : "أنا أسمعك...")
                          : audio.lastWords)
                          : lp.getText('cart_voice_hint'),
                      style:
                      const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, CartProvider cart,
      AppAudioProvider audio, LanguageProvider lp) {
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
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(item.restaurant,
                        style:
                        const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                  onPressed: () async {
                    await audio.speak(
                      lp.isEnglish
                          ? "Removed ${item.name}"
                          : "تم حذف ${item.name}",
                      lp.isEnglish ? "en-US" : "ar-SA",
                    );
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
                      if (item.quantity > 1)
                        cart.updateQuantity(item.id, item.quantity - 1);
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text("${item.quantity}",
                          style: const TextStyle(fontSize: 16)),
                    ),
                    _qtyBtn(Icons.add,
                            () => cart.updateQuantity(item.id, item.quantity + 1)),
                  ],
                ),
                Text(
                  "${(item.price * item.quantity).toStringAsFixed(2)} EGP",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEB1B33)),
                ),
              ],
            ),
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
        decoration:
        BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.black),
      ),
    );
  }

  Widget _buildSummarySection(
      CartProvider cart, AppAudioProvider audio, LanguageProvider lp) {
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
              _shouldListen = false;
              audio.speak(
                lp.isEnglish
                    ? "Going to payment."
                    : "جاري الانتقال لصفحة الدفع.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentScreen()),
                ).then((_) {
                  _shouldListen = true;
                  _isProcessing = false;
                  _speakIntro(lp);
                });
              }
            },
            child: Text(lp.getText('proceed_to_checkout'),
                style: const TextStyle(color: Colors.white, fontSize: 18)),
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
          Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            "${value.toStringAsFixed(2)} EGP",
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? const Color(0xFFEB1B33) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}