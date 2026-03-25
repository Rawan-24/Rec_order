import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:grad_project/Models/AddressModel.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:grad_project/Models/FavoriteModel.dart';
import 'package:grad_project/Models/MenuItemModel.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/screens/RestaurantData.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
Future<void> createUserProfile(String uid, String username, String phone) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'username': username,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'favorites': [], // Initialize empty favorites list for new users
      });
    } catch (e) {
      print("Error creating user: $e");
    }

}          









Future<void> updateUserLanguage(String language) async {



  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Use set with merge: true instead of update
      await _db.collection('users').doc(user.uid).set({
        'language': language,
      }, SetOptions(merge: true)); 
      
      print("Language updated to $language");
    }
  } catch (e) {
    debugPrint("Error updating language: $e");
    rethrow;
  }
}
Future<void> updateVoiceSettings(String uid, Map<String, dynamic> voiceData) async {
    try {
      await _db.collection('users').doc(uid).set({
        'voiceSettings': voiceData,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Could not update voice settings: $e");
    }
  }

  /// Fetches voice settings for the current user
  Future<Map<String, dynamic>?> getUserVoiceSettings(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['voiceSettings'] as Map<String, dynamic>?;
      }
    } catch (e) {
      print("Error fetching voice settings: $e");
    }
    return null;
  }





  // Inside your DatabaseService class
Future<void> addAddress(String userId, AddressModel address) async {
  await _db.collection('users').doc(userId).collection('addresses').add(address.toMap());
}

// Stream to listen to addresses in real-time
Stream<List<AddressModel>> getAddresses(String userId) {
  return _db
      .collection('users')
      .doc(userId)
      .collection('addresses')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AddressModel.fromFirestore(doc.id, doc.data()))
          .toList());
}

Future<void> deleteAddress(String userId, String addressId) async {
  await _db.collection('users').doc(userId).collection('addresses').doc(addressId).delete();
}
Future<void> updateAddress(String userId, AddressModel address) async {
  await _db
      .collection('users')
      .doc(userId)
      .collection('addresses')
      .doc(address.id) // Use the existing document ID
      .update(address.toMap());
}

// Add or Remove Favorite
Future<void> toggleFavorite(String userId, FavoriteModel favorite, bool isAdding) async {
  final ref = _db.collection('users').doc(userId).collection('favorites').doc(favorite.id);
  
  if (isAdding) {
    await ref.set(favorite.toMap());
  } else {
    await ref.delete();
  }
}

// Stream the list of favorites
Stream<List<FavoriteModel>> getFavorites(String userId) {
  return _db
      .collection('users')
      .doc(userId)
      .collection('favorites')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => FavoriteModel.fromFirestore(doc.data()))
          .toList());
}





  // 1. Get all restaurants
  Stream<List<Restaurant>> getRestaurants() {
    return _db.collection('restaurants').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Restaurant.fromFirestore(doc)).toList());
  }

  // 2. Get menu for a specific restaurant
  Future<List<MenuItemModel>> getMenu(String restaurantId) async {
    var snapshot = await _db
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menu')
        .get();

    return snapshot.docs.map((doc) {
      var data = doc.data();
      return MenuItemModel(
        name: data['name'],
        description: data['description'],
        price: (data['price'] as num).toDouble(),
        category: data['category'],
        image: data['image'],
        availableAddOns: Map<String, double>.from(data['availableAddOns'] ?? {}),
      );
    }).toList();
  }

Future<void> seedRestaurantData() async {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  for (var res in RestaurantData.restaurants) {
    // This creates the main restaurant document
    DocumentReference resRef = await db.collection('restaurants').add({
      'name': res.name,
      'rating': res.rating,
      'distance': res.distance,
      'image': res.image,
      'description': res.description,
      // Note: We don't save the menu list directly here 
      // because we want it as a sub-collection below
    });

    // Now we add each menu item to the 'menu' sub-collection
    // If 'menu' is red here, check your Restaurant class definition!
    for (var item in res.menu) { 
      await resRef.collection('menu').add({
        'name': item.name,
        'description': item.description,
        'price': item.price,
        'category': item.category,
        'image': item.image,
        'availableAddOns': item.availableAddOns,
      });
    }
  }
}

  // --- RESTAURANT METHODS ---

  /// 1. Get a Real-time Stream of all restaurants
  /// This is used in your RestaurantsScreen to show the cards.
  Stream<List<Restaurant>> getRestaurantsStream() {
    return _db.collection('restaurants').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Restaurant.fromFirestore(doc)).toList();
    });
  }

  /// 2. Fetch the Menu sub-collection for a specific restaurant
  /// This is used in your Menu screen when a user clicks a restaurant.
  Future<List<MenuItemModel>> getRestaurantMenu(String restaurantId) async {
    try {
      var snapshot = await _db
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menu')
          .get();

      return snapshot.docs.map((doc) {
        // We use the factory we created in MenuItemModel
        return MenuItemModel.fromFirestore(doc.data());
      }).toList();
    } catch (e) {
      print("Error fetching menu for $restaurantId: $e");
      return []; // Return empty list so the app doesn't crash
    }
  }

  // --- SEEDER METHOD (Optional) ---

  /// 3. Run this ONCE to move your hardcoded data to Firebase
Future<void> uploadMockData(List<Restaurant> mockList) async {
  // 1. Check if we already have restaurants
  var existing = await _db.collection('restaurants').limit(1).get();

  // 2. Only upload if the collection is empty
  if (existing.docs.isEmpty) {
    for (var res in mockList) {
      DocumentReference resRef = await _db.collection('restaurants').add({
        'name': res.name,
        'rating': res.rating,
        'distance': res.distance,
        'image': res.image,
        'description': res.description,
      });

      for (var item in res.menu) {
        await resRef.collection('menu').add({
          'name': item.name,
          'description': item.description,
          'price': item.price,
          'category': item.category,
          'image': item.image,
          'availableAddOns': item.availableAddOns,
        });
      }
    }
    print("First-time seeding complete!");
  } else {
    print("Database already has data, skipping upload.");
  }
}
// Inside your DatabaseService.dart

/// Fetch saved payment methods for a specific user
Future<Map<String, dynamic>?> getUserPaymentMethods(String userId) async {
  try {
    DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
    if (doc.exists) {
      // Return the payment_methods map from the user's document
      return doc.get('payment_methods');
    }
  } catch (e) {
    print("Error fetching payment methods: $e");
  }
  return null;
}

/// Add a new payment method (like a card nickname or type)
Future<void> savePaymentMethod(String userId, Map<String, dynamic> methodData) async {
  try {
    await _db.collection('users').doc(userId).set({
      'payment_methods': FieldValue.arrayUnion([methodData])
    }, SetOptions(merge: true));
  } catch (e) {
    print("Error saving payment method: $e");
  }
}



// --- PART A: SAVED PAYMENT METHODS ---

  /// Fetch the user's saved payment methods (from a sub-collection or user doc)
  Future<Map<String, dynamic>?> getSavedPaymentMethods(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        // We assume you store a 'payment_methods' field in the user document
        return (doc.data() as Map<String, dynamic>)['payment_methods'];
      }
    } catch (e) {
      print("Error fetching payment methods: $e");
    }
    return null;
  }

  /// Update the user's preferred payment method
  Future<void> updateDefaultPaymentMethod(String userId, String methodId) async {
    await _db.collection('users').doc(userId).update({
      'preferred_payment_id': methodId,
    });
  }

 /// Places a new order, links it to the user, and returns the Order ID
  Future<String> placeOrder({
    required String userId,
    required List<CartItem> items, // Using your specific model
    required double total,
    required String restaurantName,
    required String restaurantImage,
    String paymentMethod = 'card',
  }) async {
    try {
      // 1. Create a reference to a new document to get the ID first
      DocumentReference orderRef = _db.collection('orders').doc();

      // 2. Prepare the data
      Map<String, dynamic> orderData = {
        'orderId': orderRef.id,
        'userId': userId,
        'items': items.map((item) => {
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
         
          'details': item.details ?? '', // Handle extra info if available
        }).toList(),
        'totalPrice': total,
        'paymentMethod': paymentMethod,
        'status': "Pending",
        'restaurantName': restaurantName.isEmpty ? "RecOrder Partner" : restaurantName,
        'restaurantImage': restaurantImage,
        'orderNumber': 'ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 3. Save the order to the 'orders' collection
      await orderRef.set(orderData);

      // 4. Update the User's document to link this as the "Active" order
      // This is crucial for your Track Order screen logic!
      await _db.collection('users').doc(userId).set({
        'activeOrderId': orderRef.id,
      }, SetOptions(merge: true)); // Use merge: true so we don't overwrite user profile data

      return orderRef.id;
    } catch (e) {
      print("Database Error: $e");
      throw Exception("Failed to place order: $e");
    }
  }









Stream<List<Map<String, dynamic>>> getUserOrders(String userId) {
  return _db
      .collection('orders')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true) // Shows newest first
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            var data = doc.data();
            data['id'] = doc.id; // Include the document ID for navigation
            return data;
          }).toList());
}



Stream<List<Map<String, dynamic>>> getUserOrdersStream(String userId) {
  return _db
      .collection('orders')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            var data = doc.data();
            data['orderId'] = doc.id; // Map the doc ID so we can click it to track
            return data;
          }).toList());
}


// Add this inside your DatabaseService class
Stream<DocumentSnapshot> getOrderStream(String orderId) {
  return _db.collection('orders').doc(orderId).snapshots();
}


// Add this to your DatabaseService class
Stream<DocumentSnapshot> getUserDataStream() {
  final user = FirebaseAuth.instance.currentUser;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user?.uid)
      .snapshots();
}

// Fetch orders that are still being processed
Stream<QuerySnapshot> getActiveOrders() {
  final user = FirebaseAuth.instance.currentUser;
  return FirebaseFirestore.instance
      .collection('orders')
      .where('userId', isEqualTo: user?.uid)
      .where('status', whereIn: ['Pending', 'Preparing', 'On the way'])
      .orderBy('timestamp', descending: true)
      .snapshots();
}

// Fetch orders that are finished
Stream<QuerySnapshot> getPastOrders() {
  final user = FirebaseAuth.instance.currentUser;
  return FirebaseFirestore.instance
      .collection('orders')
      .where('userId', isEqualTo: user?.uid)
      .where('status', whereIn: ['Delivered', 'Cancelled'])
      .orderBy('timestamp', descending: true)
      .snapshots();
}

// Add this to your DatabaseService class
Stream<DocumentSnapshot> getOrderById(String orderId) {
  return FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots();
}





  // 2. Fetch order history for a specific user (Used in OrderHistoryPage)
  Stream<QuerySnapshot> getOrdersByUser(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }


// 1. Get real-time stream of the user's data (including cards)
  Stream<DocumentSnapshot> getUserStream(String userId) {
    return _db.collection('users').doc(userId).snapshots();
  }

  // 2. Add a new payment method to the array
  Future<void> addPaymentMethod(String userId, Map<String, dynamic> cardData) async {
    try {
      await _db.collection('users').doc(userId).update({
        'payment_methods': FieldValue.arrayUnion([cardData])
      });
    } catch (e) {
      print("Error adding payment method: $e");
    }
  }




}