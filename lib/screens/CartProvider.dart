import 'package:flutter/material.dart';
import 'package:grad_project/Models/CartItem.dart';



class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  String currentRestaurant = "";

  List<CartItem> get items => _items;

  double get subtotal => _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  double get deliveryFee => _items.isEmpty ? 0.0 : 3.99;
  double get tax => subtotal * 0.08;
  double get total => subtotal + deliveryFee + tax;

  void addItem(CartItem item) {
    // Check if the same item (name + specific add-ons) is already in cart
    int index = _items.indexWhere((i) => i.name == item.name && i.details == item.details);

    if (index >= 0) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void updateQuantity(String id, int newQty) {
    int index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _items[index].quantity = newQty;
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear(); // Empties the list
    currentRestaurant = ""; // Resets the restaurant lock if you have one
    notifyListeners(); // Refreshes the UI across the whole app
  }
  // Inside your CartProvider class
  void addMultipleItems(List<CartItem> newItems) {
    for (var item in newItems) {
      addItem(item); // Reuses your existing logic for duplicate checking
    }
    notifyListeners();
  }
}