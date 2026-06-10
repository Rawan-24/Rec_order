import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:grad_project/Models/AddressModel.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:grad_project/Models/FavoriteModel.dart';
import 'package:grad_project/Models/MenuItemModel.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/screens/RestaurantData.dart';
import 'package:grad_project/notification_service.dart'; // ← added

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── USER ──────────────────────────────────────────────────────────────────

  Future<void> createUserProfile(String uid, String username, String phone,
      {String language = 'en'}) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'username': username,
        'phone': phone,
        'language': language,
        'createdAt': FieldValue.serverTimestamp(),
        'favorites': [],
      });
    } catch (e) {
      debugPrint("Error creating user: $e");
    }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      return null;
    }
  }

  Stream<DocumentSnapshot> getUserDataStream() {
    final user = FirebaseAuth.instance.currentUser;
    return _db.collection('users').doc(user?.uid).snapshots();
  }

  Stream<DocumentSnapshot> getUserStream(String userId) {
    return _db.collection('users').doc(userId).snapshots();
  }

  Future<void> updateUserLanguage(String langCode) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _db
            .collection('users')
            .doc(user.uid)
            .set({'language': langCode}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error updating language: $e");
      rethrow;
    }
  }

  // ── VOICE SETTINGS ────────────────────────────────────────────────────────

  Future<void> updateVoiceSettings(
      String uid, Map<String, dynamic> voiceData) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set({'voiceSettings': voiceData}, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Could not update voice settings: $e");
    }
  }

  Future<Map<String, dynamic>?> getUserVoiceSettings(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['voiceSettings'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("Error fetching voice settings: $e");
    }
    return null;
  }

  // ── ADDRESS ───────────────────────────────────────────────────────────────

  Future<bool> hasSavedAddress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      DocumentSnapshot doc =
      await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data.containsKey('address') &&
            data['address'].toString().trim().isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint("Error checking address: $e");
      return false;
    }
  }

  Future<void> addAddress(String userId, AddressModel address) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('addresses')
        .add(address.toMap());
  }

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
    await _db
        .collection('users')
        .doc(userId)
        .collection('addresses')
        .doc(addressId)
        .delete();
  }

  Future<void> updateAddress(String userId, AddressModel address) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('addresses')
        .doc(address.id)
        .update(address.toMap());
  }

  // ── FAVOURITES ────────────────────────────────────────────────────────────

  Future<void> toggleFavorite(
      String userId, FavoriteModel item, bool isAlreadyFavorite) async {
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(item.id);
    if (isAlreadyFavorite) {
      await docRef.delete();
    } else {
      await docRef.set(item.toMap());
    }
  }

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

  // ── RESTAURANTS ───────────────────────────────────────────────────────────

  Stream<List<Restaurant>> getRestaurantsStream() {
    return _db.collection('restaurants').snapshots().handleError((e) {
      debugPrint("Firestore restaurants stream error: $e");
    }).map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => Restaurant.fromFirestore(doc))
            .toList();
      } catch (e) {
        debugPrint("Error parsing restaurants: $e");
        return <Restaurant>[];
      }
    });
  }

  Stream<List<Restaurant>> getRestaurants() => getRestaurantsStream();

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
        availableAddOns:
        Map<String, double>.from(data['availableAddOns'] ?? {}),
      );
    }).toList();
  }

  Future<List<MenuItemModel>> getRestaurantMenu(String restaurantId) async {
    try {
      var snapshot = await _db
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menu')
          .get();
      return snapshot.docs
          .map((doc) => MenuItemModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint("Error fetching menu for $restaurantId: $e");
      return [];
    }
  }

  Future<void> seedRestaurantData() async {
    final existing = await _db.collection('restaurants').limit(1).get();
    if (existing.docs.isNotEmpty) return;
    for (var res in RestaurantData.restaurants) {
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
  }

  Future<void> uploadMockData(List<Restaurant> mockList) async {
    var existing = await _db.collection('restaurants').limit(1).get();
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
    }
  }

  // ── ORDERS ────────────────────────────────────────────────────────────────

  Future<void> processPayment(List<CartItem> items, double total) async {
    final user = FirebaseAuth.instance.currentUser;
    await _db.collection('orders').add({
      'userId': user!.uid,
      'items': items.map((i) => i.toMap()).toList(),
      'total': total,
      'status': 'Pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<String> placeOrder({
    required List<CartItem> cartItems,
    required String userId,
    required List<CartItem> items,
    required double total,
    required String restaurantName,
    required String restaurantImage,
    String paymentMethod = 'card',
  }) async {
    try {
      DocumentReference orderRef = _db.collection('orders').doc();

      String finalName = restaurantName;
      if (finalName.isEmpty && items.isNotEmpty) {
        finalName = items.first.restaurant;
      }
      if (finalName.isEmpty) finalName = "RecOrder Partner";

      Map<String, dynamic> orderData = {
        'orderId': orderRef.id,
        'userId': userId,
        'items': items.map((item) => item.toMap()).toList(),
        'totalPrice': total,
        'paymentMethod': paymentMethod,
        'status': "Pending",
        'restaurantName': finalName,
        'restaurantImage': restaurantImage,
        'orderNumber':
        'ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await orderRef.set(orderData);

      await _db.collection('users').doc(userId).set(
          {'activeOrderId': orderRef.id}, SetOptions(merge: true));

      // ── Show confirmation notification immediately ──────────────────────
      await showLocalNotification(
        "Order Confirmed! 🎉",
        "Your order has been received and is being processed.",
      );

      // ── Listen for status changes and notify accordingly ───────────────
      _listenToOrderStatus(orderRef);

      return orderRef.id;
    } catch (e) {
      debugPrint("Database Error: $e");
      throw Exception("Failed to place order: $e");
    }
  }

  /// Listens to a single order document and fires a notification
  /// whenever the status field changes.
  void _listenToOrderStatus(DocumentReference orderRef) {
    String lastStatus = 'Pending';

    orderRef.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final status = (snap.data() as Map<String, dynamic>?)?['status'] as String?;
      if (status == null || status == lastStatus) return;
      lastStatus = status;

      switch (status) {
        case 'Preparing':
          await showLocalNotification(
            "Order Being Prepared 👨‍🍳",
            "The restaurant is now preparing your food!",
          );
          break;
        case 'On the Way':
          await showLocalNotification(
            "On The Way! 🚗",
            "Your order is out for delivery.",
          );
          break;
        case 'Delivered':
          await showLocalNotification(
            "Delivered! ✅",
            "Your order has arrived. Enjoy your meal!",
          );
          break;
      }
    });
  }

  // ── FIX: getActiveOrders — NO composite index required ───────────────────
  Stream<QuerySnapshot> getActiveOrders(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status',
        whereIn: ['Pending', 'Preparing', 'On the Way', 'Ready'])
        .snapshots();
  }

  Stream<QuerySnapshot> getPastOrders(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'Delivered')
        .snapshots();
  }

  Future<String?> getActiveOrderId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      DocumentSnapshot doc =
      await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['activeOrderId'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching active order: $e");
    }
    return null;
  }

  Stream<DocumentSnapshot> getOrderStream(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots();
  }

  Stream<DocumentSnapshot> getOrderById(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots();
  }

  // ── Legacy order streams ──────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getUserOrders(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      var data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList());
  }

  Stream<List<Map<String, dynamic>>> getUserOrdersStream(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      var data = doc.data();
      data['orderId'] = doc.id;
      return data;
    }).toList());
  }

  Stream<QuerySnapshot> getOrdersByUser(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  // ── PAYMENT METHODS ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserPaymentMethods(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) return doc.get('payment_methods');
    } catch (e) {
      debugPrint("Error fetching payment methods: $e");
    }
    return null;
  }

  Future<void> savePaymentMethod(
      String userId, Map<String, dynamic> methodData) async {
    try {
      await _db.collection('users').doc(userId).set({
        'payment_methods': FieldValue.arrayUnion([methodData])
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error saving payment method: $e");
    }
  }

  Future<Map<String, dynamic>?> getSavedPaymentMethods(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data() as Map<String, dynamic>)['payment_methods'];
      }
    } catch (e) {
      debugPrint("Error fetching payment methods: $e");
    }
    return null;
  }

  Future<void> updateDefaultPaymentMethod(
      String userId, String methodId) async {
    await _db.collection('users').doc(userId).update({
      'preferred_payment_id': methodId,
    });
  }

  Future<void> addPaymentMethod(
      String userId, Map<String, dynamic> cardData) async {
    try {
      await _db.collection('users').doc(userId).update({
        'payment_methods': FieldValue.arrayUnion([cardData])
      });
    } catch (e) {
      debugPrint("Error adding payment method: $e");
    }
  }
  Future<void> seedMenuItems() async {
    final restaurants = RestaurantData.restaurants;
    debugPrint("🌱 seedMenuItems called — ${restaurants.length} restaurants");

    for (final restaurant in restaurants) {
      debugPrint("🔍 Searching for: '${restaurant.name}'");

      final query = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('name', isEqualTo: restaurant.name)
          .get();

      debugPrint("📦 Found ${query.docs.length} docs for '${restaurant.name}'");

      if (query.docs.isEmpty) {
        debugPrint("❌ Restaurant not found: '${restaurant.name}' — skipping");
        continue;
      }

      final restaurantId = query.docs.first.id;
      debugPrint("✅ Restaurant ID: $restaurantId");

      final menuRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menu');

      final existingMenu = await menuRef.limit(1).get();
      debugPrint("🍽️ Existing menu items: ${existingMenu.docs.length}");

      if (existingMenu.docs.isNotEmpty) {
        debugPrint("⏭️ Menu already seeded for ${restaurant.name} — skipping");
        continue;
      }

      debugPrint("➕ Inserting ${restaurant.menu.length} items for ${restaurant.name}");

      for (final item in restaurant.menu) {
        debugPrint("   → Adding: ${item.name}");
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .collection('menu')
            .add({
          'name': item.name,
          'description': item.description,
          'price': item.price,
          'category': item.category,
          'image': item.image,
          'availableAddOns': item.availableAddOns,
        });
      }
      debugPrint("✅ Seeded menu for ${restaurant.name}");
    }
  }
  // ── NOTIFICATION SETTINGS ─────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getNotificationSettings(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('notifications')
          .get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint("getNotificationSettings error: $e");
      return null;
    }
  }

  Future<void> updateNotificationSettings(
      String uid, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('notifications')
        .set(data, SetOptions(merge: true));
  }
}
