class CartItem {
  final String id;
  final String name;
  final String restaurant;
  final String details;
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.restaurant,
    required this.details,
    required this.price,
    this.quantity = 1,
  });
// Convert Dart Object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'restaurant': restaurant,
      'details': details,
      'price': price,
      'quantity': quantity,
    };
  }

  // Create Dart Object from Firestore Map
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      name: map['name'],
      restaurant: map['restaurant'],
      details: map['details'],
      price: map['price'],
      quantity: map['quantity'],
    );
  }
}