import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grad_project/screens/CartItem.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> placeOrder({
    required String userId,
    required List<CartItem> items,
    required double total,
  }) async {
    // 1. Create a reference to the 'orders' collection
    DocumentReference orderRef = _db.collection('orders').doc();

    // 2. Prepare the data
    Map<String, dynamic> orderData = {
      'orderId': orderRef.id,
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(), // Converts list of objects to list of maps
      'totalPrice': total,
      'status': 'pending', // default status
      'paymentMethod': 'Cash on Delivery',
      'timestamp': FieldValue.serverTimestamp(), // Firestore server time
    };

    // 3. Save to Firestore
    await orderRef.set(orderData);
  }
}