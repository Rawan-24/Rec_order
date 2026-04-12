class CartItem {
  final String id;
  final String name;
  
  final String restaurant;
  final String details;
  final double price;
  int quantity;

  final String image;

  CartItem({
    required this.id,
    required this.name,
     required this.image,
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
      'image': image,
      'details': details,
      'price': price,
      'quantity': quantity,
    };
  }

  // Create Dart Object from Firestore Map
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      restaurant: map['restaurant'] ?? '', // This pulls the name back from Firestore
      details: map['details'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1, // FIX: Use quantity key
      image: map['image'] ?? '',      // FIX: Use image key
    );
  }
}