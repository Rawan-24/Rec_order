import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grad_project/Models/MenuItemModel.dart';

class Restaurant {
  final String? id;
  final String name;
  final String rating;
  final String description;
  final String distance;
  final String image;
  final List<MenuItemModel> menu; // <--- MAKE SURE THIS LINE EXISTS

  Restaurant({
    this.id,
    required this.name,
    required this.rating,
    required this.description,
    required this.distance,
    required this.image,
    required this.menu, // <--- AND THIS ONE
  });

  // Convert Firebase Document to Restaurant Object
 // Convert Firebase Document to Restaurant Object
  factory Restaurant.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Restaurant(
      id: doc.id,
      name: data['name'] ?? '',
      rating: data['rating'] ?? '0.0',
      distance: data['distance'] ?? '',
      image: data['image'] ?? '',
      description: data['description'] ?? '',
      menu: [], 
    );
  }
}