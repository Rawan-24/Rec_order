import 'package:grad_project/screens/Restaurant.dart';
import 'package:grad_project/screens/MenuItemModel.dart';

class RestaurantData {

  static List<Restaurant> restaurants = [

    Restaurant(
      name: "Pizza Paradise",
      rating: "4.7",
      distance: "2.1 km",
      image: "https://images.unsplash.com/photo-1513104890138-7c749659a591",
      description: "Authentic Italian pizza with fresh ingredients",
      menu: [

        MenuItemModel(
          name: "Pepperoni Pizza",
          description: "Pepperoni with mozzarella cheese",
          price: 14.99,
          category: "Pizza",
          image: "https://images.unsplash.com/photo-1628840042765-356cda07504e",
          availableAddOns: {
            "Extra Pepperoni": 2.0,
            "Olives": 1.5,
            "Mushrooms": 1.5,
          },
        ),

        MenuItemModel(
          name: "Margherita Pizza",
          description: "Classic tomato & mozzarella",
          price: 12.99,
          category: "Pizza",
          image: "https://images.unsplash.com/photo-1604068549290-dea0e4a305ca?q=80&w=1000&auto=format&fit=crop",
          availableAddOns: {
            "Extra mozzarella": 2.0,
            "Olives": 1.5,
            "tomato": 1.5,
          },
        ),
      ],
    ),

    Restaurant(
      name: "Pasta House",
      rating: "4.5",
      distance: "1.8 km",
      description: "Authentic Italian pasta ",
      image: "https://images.unsplash.com/photo-1473093226795-af9932fe5856",
      menu: [

        MenuItemModel(
          name: "Pasta Carbonara",
          description: "Creamy pasta with bacon",
          price: 13.99,
          category: "Pasta",
          image: "https://images.unsplash.com/photo-1612874742237-6526221588e3?q=80&w=1000&auto=format&fit=crop",
          availableAddOns: {
            "Extra sauce": 2.0,
            "bacon": 1.5,
            "Mushrooms": 1.5,
          },
        ),

        MenuItemModel(
          name: "Pasta Alfredo",
          description: "Creamy parmesan sauce",
          price: 12.50,
          category: "Pasta",
          image: "https://images.pexels.com/photos/1437267/pexels-photo-1437267.jpeg?auto=compress&cs=tinysrgb&w=800",
          availableAddOns: {
            "Extra sauce": 2.0,
            "extra Cream": 1.5,
            "Olives": 1.5,
          },
        ),
      ],
    ),

    Restaurant(
      name: "Fresh Salad Bar",
      rating: "4.6",
      distance: "1.2 km",
      description: "Authentic Salads with fresh ingredients",
      image: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd",
      menu: [

        MenuItemModel(
          name: "Greek Salad",
          description: "Cucumbers, tomatoes, olives",
          price: 9.99,
          category: "Salads",
          image: "https://images.pexels.com/photos/1211887/pexels-photo-1211887.jpeg?auto=compress&cs=tinysrgb&w=800",

          availableAddOns: {
            "Cucumbers": 2.0,
            "tomatoes": 1.5,
            "Olives": 1.5,
          },
        ),

        MenuItemModel(
          name: "Caesar Salad",
          description: "Romaine lettuce with dressing",
          price: 10.99,
          category: "Salads",
          image: "https://images.unsplash.com/photo-1550304943-4f24f54ddde9",
          availableAddOns: {
            "lettuce": 2.0,
            "chicken": 1.5,
            "suace": 1.5,
          },
        ),
      ],
    ),

  ];
}