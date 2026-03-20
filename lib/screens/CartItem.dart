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
}