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
}