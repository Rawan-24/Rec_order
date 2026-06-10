import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/TrackOrderScreen.dart';

import '../services/ai_service.dart';
import 'Delivery_Address.dart';

class PaymentScreen extends StatefulWidget {
  static const String routeName = "PaymentScreen";
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _shouldListen = true;
  bool _isProcessing = false;
  bool _isPlacingOrder = false;

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

  // ─────────────────────────────────────────
  // FIX #2 — INTRO WITH FULL PRICE BREAKDOWN
  // ─────────────────────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    await audio.stop();
    await audio.speak(
      lp.isEnglish
          ? "Payment screen. "
          "Subtotal is ${cart.subtotal.toStringAsFixed(2)} pounds. "
          "Delivery fee is ${cart.deliveryFee.toStringAsFixed(2)} pounds. "
          "Tax is ${cart.tax.toStringAsFixed(2)} pounds. "
          "Your total is ${cart.total.toStringAsFixed(2)} Egyptian pounds. "
          "Payment is cash on delivery. "
          "Say confirm to place your order, or say cancel to go back."
          : "شاشة الدفع. "
          "المجموع الفرعي ${cart.subtotal.toStringAsFixed(2)} جنيه. "
          "رسوم التوصيل ${cart.deliveryFee.toStringAsFixed(2)} جنيه. "
          "الضريبة ${cart.tax.toStringAsFixed(2)} جنيه. "
          "إجمالي طلبك ${cart.total.toStringAsFixed(2)} جنيه مصري. "
          "الدفع عند الاستلام. "
          "قل أكد لتأكيد الطلب، أو قل إلغاء للرجوع.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  // ─────────────────────────────────────────
  // ALWAYS-ON LISTEN LOOP
  // ─────────────────────────────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (Payment): $text");
        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();
        debugPrint("AI COMMAND (Payment): $command");

        await _handleCommand(command, lp);

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

  // ─────────────────────────────────────────
  // COMMAND HANDLER
  // ─────────────────────────────────────────
  Future<void> _handleCommand(String command, LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    switch (command) {
      case "confirm_cash_order":
      case "sign_up": // safety net
        await _processOrder(lp, cart);
        break;

    // FIX #2 — read full breakdown on demand
      case "read_order_total":
      case "read_cart_total":
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

      case "cancel_order":
      case "go_back":
        _shouldListen = false;
        await audio.stop();
        if (mounted) Navigator.pop(context);
        break;

      default:
        await audio.speak(
          lp.isEnglish
              ? "Say confirm to place your order, or cancel to go back."
              : "قل أكد لتأكيد الطلب، أو إلغاء للرجوع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
    }
  }

  // ─────────────────────────────────────────
  // PROCESS CASH ORDER
  // ─────────────────────────────────────────
  Future<void> _processOrder(LanguageProvider lp, CartProvider cart) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    _shouldListen = false;
    await audio.stop();

    setState(() => _isPlacingOrder = true);

    try {
      // Check address exists
      final addressSnapshot =
      await DatabaseService().getAddresses(user.uid).first;

      if (addressSnapshot.isEmpty) {
        setState(() => _isPlacingOrder = false);
        await audio.speak(
          lp.isEnglish
              ? "Please add a delivery address first. Redirecting to addresses."
              : "من فضلك أضف عنوان توصيل أولاً. جاري التوجيه لصفحة العناوين.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeliveryAddressesPage()),
          ).then((_) {
            _shouldListen = true;
            _isProcessing = false;
            _speakIntro(lp);
          });
        }
        return;
      }

      // Place the order
      String orderId = await DatabaseService().placeOrder(
        userId: user.uid,
        total: cart.total,
        paymentMethod: "cash_on_delivery",
        restaurantName:
        cart.items.map((i) => i.restaurant).toSet().length > 1
            ? "Multi-Restaurant Order"
            : cart.items.first.restaurant,
        restaurantImage:
        cart.items.isNotEmpty ? cart.items.first.image : "",
        items: cart.items,
        cartItems: cart.items,
      );

      cart.clearCart();
      setState(() => _isPlacingOrder = false);

      // FIX #4 — stop audio before navigating so TrackOrder isn't fighting
      // this screen's TTS. TrackOrderScreen will speak its own intro.
      await audio.stop();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => TrackOrderScreen(orderId: orderId)),
        );
      }
    } catch (e) {
      setState(() => _isPlacingOrder = false);
      await audio.speak(
        lp.isEnglish
            ? "An error occurred. Please try again."
            : "حدث خطأ. من فضلك حاول مرة أخرى.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      _shouldListen = true;
      _startListening(lp);
      debugPrint("Order error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);
    final cart = Provider.of<CartProvider>(context);
    const primaryRed = Color(0xFFEB1B33);

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
        title: Text(lp.getText('payment_title'),
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ── Mic indicator ──────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                if (audio.isListening)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryRed.withOpacity(0.15),
                    ),
                  ),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryRed.withOpacity(0.1),
                  ),
                  child: Icon(
                    audio.isListening ? Icons.mic : Icons.mic_none,
                    color: primaryRed,
                    size: 45,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Listening status ───────────────────────────────
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8)
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    audio.isListening
                        ? Icons.graphic_eq
                        : Icons.mic_none,
                    size: 18,
                    color: primaryRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    audio.isListening
                        ? (lp.isEnglish ? "Listening..." : "أنا أسمعك...")
                        : (lp.isEnglish ? "Ready" : "جاهز"),
                    style:
                    TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Cash on delivery card ──────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.money, color: primaryRed, size: 50),
                  const SizedBox(height: 12),
                  Text(
                    lp.isEnglish
                        ? "Cash on Delivery"
                        : "الدفع عند الاستلام",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lp.isEnglish
                        ? "Pay with cash when your order arrives at your door."
                        : "ادفع كاش عند وصول طلبك لبابك.",
                    textAlign: TextAlign.center,
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Order summary ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _summaryRow(lp.getText('subtotal'), cart.subtotal, lp),
                  _summaryRow(
                      lp.getText('delivery_fee'), cart.deliveryFee, lp),
                  _summaryRow(lp.getText('tax'), cart.tax, lp),
                  const Divider(height: 30),
                  _summaryRow(lp.getText('total'), cart.total, lp,
                      isBold: true),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Voice commands hint ────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(15),
                border:
                Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mic_none,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lp.isEnglish
                          ? "Say \"confirm\" to place order\nSay \"how much\" to hear the breakdown\nSay \"cancel\" to go back"
                          : "قل \"أكد\" لتأكيد الطلب\nقل \"كام المبلغ\" لسماع التفاصيل\nقل \"إلغاء\" للرجوع",
                      style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          height: 1.6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Confirm button ─────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isPlacingOrder
                    ? null
                    : () async {
                  final lp2 = Provider.of<LanguageProvider>(context,
                      listen: false);
                  final cart2 =
                  Provider.of<CartProvider>(context, listen: false);
                  await _processOrder(lp2, cart2);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: _isPlacingOrder
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  lp.isEnglish
                      ? "Confirm Order · ${cart.total.toStringAsFixed(2)} EGP"
                      : "تأكيد الطلب · ${cart.total.toStringAsFixed(2)} جنيه",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Cancel button ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: () {
                  _shouldListen = false;
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryRed),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  lp.isEnglish ? "Cancel" : "إلغاء",
                  style: const TextStyle(
                      fontSize: 18,
                      color: primaryRed,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value, LanguageProvider lp,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                  isBold ? FontWeight.bold : FontWeight.normal)),
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