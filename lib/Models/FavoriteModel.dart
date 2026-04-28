class FavoriteModel {
  final String id; // The Restaurant ID
  final String name;
  final String cuisine;
  final String rating;
  final String time;
  final String image;
  factory FavoriteModel.empty() => FavoriteModel(
    id: '',
    name: '',
    image: '',
    rating: '0',
    cuisine: '',
    time: '',
  );
  FavoriteModel({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.time,
    required this.image,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cuisine': cuisine,
      'rating': rating,
      'time': time,
      'image': image,
    };
  }

  factory FavoriteModel.fromFirestore(Map<String, dynamic> data) {
    return FavoriteModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      cuisine: data['cuisine'] ?? '',
      rating: data['rating'] ?? '0.0',
      time: data['time'] ?? '',
      image: data['image'] ?? '',
    );
  }
}