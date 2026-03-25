import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart'; // Ensure correct import

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFD32F2F);
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Payment Methods", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
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
            
            // Logic to handle empty card lists
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
                    (card['cardHolder'] ?? 'Unknown').toString().toUpperCase(),
                    card['cardNumber'] ?? '**** **** **** ****',
                    card['expiry'] ?? '--/--',
                    [const Color(0xFFB71C1C), const Color(0xFFD32F2F)],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  const Text(
                    "Other Payment Methods",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  
                  const SizedBox(height: 15),

                  _buildPaymentOption(Icons.account_balance_wallet_outlined, "Google Pay", primaryRed),
                  _buildPaymentOption(Icons.paypal_outlined, "PayPal", primaryRed),
                  
                  // Add New Method Action
                  _buildPaymentOption(
                    Icons.add_circle_outline, 
                    "Add New Method", 
                    primaryRed, 
                    isAction: true,
                    onTap: () {
                      _showAddCardDialog(context, currentUserId);
                    }
                  ),

                  const SizedBox(height: 40),
                  
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 5),
                        Text(
                          "Secure 256-bit SSL Encrypted Payment",
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

  // Helper to simulate adding a card
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
              // Example Data
              DatabaseService().addPaymentMethod(userId, {
                'cardHolder': 'John Doe',
                'cardNumber': '**** **** **** 1234',
                'expiry': '12/28',
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
                  Text("CARD HOLDER",
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("EXPIRES",
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
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