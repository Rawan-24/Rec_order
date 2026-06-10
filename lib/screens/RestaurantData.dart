import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/Models/MenuItemModel.dart';

class RestaurantData {

  static List<Restaurant> restaurants = [

    Restaurant(
      name: "Pizza Paradise",
      rating: "4.7",
      distance: "2.1 km",
      image: "https://images.unsplash.com/photo-1513104890138-7c749659a591",
      description: "Authentic Italian pizza with fresh ingredients",
      menu: [

        // ── Pizza ──────────────────────────────────────────────
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
          image: "https://images.unsplash.com/photo-1604068549290-dea0e4a305ca",
          availableAddOns: {
            "Extra Mozzarella": 2.0,
            "Olives": 1.5,
            "Tomato": 1.5,
          },
        ),

        // ── Salads ─────────────────────────────────────────────
        MenuItemModel(
          name: "Caesar Salad",
          description: "Romaine lettuce with Caesar dressing and croutons",
          price: 8.99,
          category: "Salads",
          image: "https://images.unsplash.com/photo-1550304943-4f24f54ddde9",
          availableAddOns: {
            "Grilled Chicken": 3.0,
            "Extra Dressing": 1.0,
            "Croutons": 1.0,
          },
        ),

        MenuItemModel(
          name: "Greek Salad",
          description: "Cucumbers, tomatoes, olives and feta cheese",
          price: 7.99,
          category: "Salads",
          image: "https://images.pexels.com/photos/1211887/pexels-photo-1211887.jpeg",
          availableAddOns: {
            "Extra Feta": 2.0,
            "Olives": 1.5,
            "Tomatoes": 1.0,
          },
        ),

        // ── Drinks ─────────────────────────────────────────────
        MenuItemModel(
          name: "Coca Cola",
          description: "Classic chilled Coca Cola can",
          price: 3.99,
          category: "Drinks",
          image: "https://images.unsplash.com/photo-1554866585-cd94860890b7",
          availableAddOns: {
            "Extra Ice": 0.5,
          },
        ),

        MenuItemModel(
          name: "Fresh Orange Juice",
          description: "Freshly squeezed orange juice",
          price: 5.99,
          category: "Drinks",
          image: "https://images.unsplash.com/photo-1600271886742-f049cd451bba",
          availableAddOns: {
            "Extra Sugar": 0.5,
            "Ice": 0.5,
          },
        ),

        MenuItemModel(
          name: "Mineral Water",
          description: "Still or sparkling mineral water",
          price: 2.49,
          category: "Drinks",
          image: "https://images.unsplash.com/photo-1548839140-29a749e1cf4d",
          availableAddOns: {
            "Sparkling": 0.5,
          },
        ),
      ],
    ),

    Restaurant(
      name: "Pasta House",
      rating: "4.5",
      distance: "1.8 km",
      description: "Authentic Italian pasta",
      image: "https://images.unsplash.com/photo-1473093226795-af9932fe5856",
      menu: [

        // ── Pasta ──────────────────────────────────────────────
        MenuItemModel(
          name: "Pasta Carbonara",
          description: "Creamy pasta with bacon",
          price: 13.99,
          category: "Pasta",
          image: "https://images.unsplash.com/photo-1612874742237-6526221588e3",
          availableAddOns: {
            "Extra Sauce": 2.0,
            "Bacon": 1.5,
            "Mushrooms": 1.5,
          },
        ),

        MenuItemModel(
          name: "Pasta Alfredo",
          description: "Creamy parmesan sauce",
          price: 12.50,
          category: "Pasta",
          image: "https://images.pexels.com/photos/1437267/pexels-photo-1437267.jpeg",
          availableAddOns: {
            "Extra Sauce": 2.0,
            "Extra Cream": 1.5,
            "Olives": 1.5,
          },
        ),

        // ── Salads ─────────────────────────────────────────────
        MenuItemModel(
          name: "Caesar Salad",
          description: "Romaine lettuce with Caesar dressing and croutons",
          price: 8.99,
          category: "Salads",
          image: "https://images.unsplash.com/photo-1550304943-4f24f54ddde9",
          availableAddOns: {
            "Grilled Chicken": 3.0,
            "Extra Dressing": 1.0,
            "Croutons": 1.0,
          },
        ),

        MenuItemModel(
          name: "Caprese Salad",
          description: "Fresh mozzarella, tomatoes and basil",
          price: 9.49,
          category: "Salads",
          image: "https://images.unsplash.com/photo-1608897013039-887f21d8c804",
          availableAddOns: {
            "Extra Mozzarella": 2.0,
            "Basil": 1.0,
            "Balsamic Glaze": 1.5,
          },
        ),

        // ── Drinks ─────────────────────────────────────────────
        MenuItemModel(
          name: "Coca Cola",
          description: "Classic chilled Coca Cola can",
          price: 3.99,
          category: "Drinks",
          image: "https://images.unsplash.com/photo-1554866585-cd94860890b7",
          availableAddOns: {
            "Extra Ice": 0.5,
          },
        ),

        MenuItemModel(
          name: "Lemonade",
          description: "Homemade chilled lemonade with mint",
          price: 4.99,
          category: "Drinks",
          image: "https://images.unsplash.com/photo-1621263764928-df1444c5e859",
          availableAddOns: {
            "Extra Mint": 0.5,
            "Extra Sugar": 0.5,
          },
        ),

        MenuItemModel(
          name: "Mineral Water",
          description: "Still or sparkling mineral water",
          price: 2.49,
          category: "Drinks",
          image: "https://images.unsplash.com/photo-1548839140-29a749e1cf4d",
          availableAddOns: {
            "Sparkling": 0.5,
          },
        ),
      ],
    ),

    Restaurant(
      name: "Fresh Salad Bar",
      rating: "4.6",
      distance: "1.2 km",
      description: "Authentic salads with fresh ingredients",
      image: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd",
      menu: [

        // ── Salads ─────────────────────────────────────────────
        MenuItemModel(
          name: "Greek Salad",
          description: "Cucumbers, tomatoes, olives and feta cheese",
          price: 9.99,
          category: "Salads",
          image: "https://images.pexels.com/photos/1211887/pexels-photo-1211887.jpeg",
          availableAddOns: {
            "Cucumbers": 2.0,
            "Tomatoes": 1.5,
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
            "Lettuce": 2.0,
            "Chicken": 1.5,
            "Sauce": 1.5,
          },
        ),

        MenuItemModel(
          name: "Quinoa Salad",
          description: "Quinoa with roasted vegetables and lemon dressing",
          price: 11.99,
          category: "Salads",
          image: "https://images.unsplash.com/photo-1505253716362-afaea1d3d1af",
          availableAddOns: {
            "Avocado": 3.0,
            "Feta Cheese": 2.0,
            "Extra Dressing": 1.0,
          },
        ),

        // ── Drinks ─────────────────────────────────────────────
        MenuItemModel(
          name: "Fresh Orange Juice",
          description: "Freshly squeezed orange juice",
          price: 5.99,
          category: "Drinks",
          image: "https://images.unsplash.com/photo-1600271886742-f049cd451bba",
          availableAddOns: {
            "Extra Sugar": 0.5,
            "Ice": 0.5,
          },
        ),

        MenuItemModel(
          name: "Green Detox Juice",
          description: "Spinach, cucumber, apple and ginger blend",
          price: 6.99,
          category: "Drinks",
          image: "https://images.unsplash.com/photo-1610970881699-44a5587cabec",
          availableAddOns: {
            "Extra Ginger": 0.5,
            "Honey": 1.0,
          },
        ),

        MenuItemModel(
          name: "Mineral Water",
          description: "Still or sparkling mineral water",
          price: 2.49,
          category: "Drinks",
          image: "https://images.unsplash.com/photo-1548839140-29a749e1cf4d",
          availableAddOns: {
            "Sparkling": 0.5,
          },
        ),
      ],
    ),

  ];
}