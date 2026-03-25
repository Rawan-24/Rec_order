class MenuItemModel {
  final String name;
  final String description;
  final double price;
  final String category;
  final String image;
  final Map<String, double> availableAddOns;

  MenuItemModel({
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.image,
    required this.availableAddOns,
  });

  // Add this to handle the data coming from the 'menu' sub-collection
  factory MenuItemModel.fromFirestore(Map<String, dynamic> data) {
    return MenuItemModel(
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      image: data['image'] ?? '',
      availableAddOns: Map<String, double>.from(data['availableAddOns'] ?? {}),
    );
  }
}