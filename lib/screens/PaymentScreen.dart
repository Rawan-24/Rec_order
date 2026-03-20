import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/TrackOrderScreen.dart';

class PaymentScreen extends StatefulWidget {
  static const String routeName = "PaymentScreen";
  PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // State to track selected payment method
  String selectedMethod = 'card'; // 'card' or 'cash'
  bool isVoiceConfirmed = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Payment", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Voice Command Section
            const Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFEB1B33),
                child: Icon(Icons.mic, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD6E0E0),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mic, color: Colors.teal, size: 20),
                  SizedBox(width: 10),
                  Text('Say "Pay with card" or "Cash on delivery"',
                      style: TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text("Select Payment Method",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // Payment Options
            _buildPaymentOption(
              id: 'card',
              title: "Credit / Debit Card",
              subtitle: "Secure payment",
              icon: Icons.credit_card,
            ),
            const SizedBox(height: 10),
            _buildPaymentOption(
              id: 'cash',
              title: "Cash on Delivery",
              subtitle: "Pay when you receive",
              icon: Icons.money,
            ),

            const SizedBox(height: 30),

            // Conditional Card Details Section
            if (selectedMethod == 'card') ...[
              const Text("Card Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildTextField("Card Number", "1234 5678 9012 3456"),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTextField("Expiry Date", "MM/YY")),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField("CVV", "123")),
                ],
              ),
              const SizedBox(height: 25),
              const Text("Confirmation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildVoicePinButton(),
            ],

            const SizedBox(height: 20),
            _buildSecurePaymentNote(),
            const SizedBox(height: 20),
            _buildOrderSummary(),
            const SizedBox(height: 100), // Padding for bottom button
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomPayButton(),
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

  Widget _buildVoicePinButton() {
    // Define colors based on state
    final Color backgroundColor = isVoiceConfirmed ? const Color(0xFFEB1B33) : Colors.white;
    final Color contentColor = isVoiceConfirmed ? Colors.white : Colors.black87;
    final Color subTextColor = isVoiceConfirmed ? Colors.white70 : Colors.grey;

    return Material(
      color: backgroundColor,
      elevation: isVoiceConfirmed ? 0 : 2, // Slight shadow when white
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          setState(() {
            isVoiceConfirmed = !isVoiceConfirmed; // Toggles the state for demo purposes
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Optional: Add a light border when white to match your "not selected" image
            border: isVoiceConfirmed ? null : Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              Icon(Icons.mic_none, color: contentColor, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Voice PIN Confirmation",
                      style: TextStyle(
                        color: contentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      "Speak your 4-digit PIN",
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Only show the checkmark if confirmed
              if (isVoiceConfirmed)
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildSecurePaymentNote() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.withOpacity(0.2))),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.green, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text("Secure Payment\nYour payment information is encrypted and secure.", style: TextStyle(color: Colors.black54, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final cart = Provider.of<CartProvider>(context); // Sync money

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal"), Text("\$${cart.subtotal.toStringAsFixed(2)}")]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Delivery Fee"), Text("\$${cart.deliveryFee.toStringAsFixed(2)}")]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Tax"), Text("\$${cart.tax.toStringAsFixed(2)}")]),
          const Divider(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text("\$${cart.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFEB1B33)))
          ]),
        ],
      ),
    );
  }

  Widget _buildBottomPayButton() {
    final cart = Provider.of<CartProvider>(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      color: Colors.white,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEB1B33),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => TrackOrderScreen()));
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
                "Confirm & Pay \$${cart.total.toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
    );
  }
}