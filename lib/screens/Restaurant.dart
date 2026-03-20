

import'package:grad_project/screens/MenuItemModel.dart';


class Restaurant {
  final String name;
  final String rating;
  final String description;
  final String distance;
  final String image;
  final List<MenuItemModel> menu;

  Restaurant({
    required this.name,
    required this.rating,
    required this.distance,
    required this.image,
    required this.menu,
    required this.description,
  });
}