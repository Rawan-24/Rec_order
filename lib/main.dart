import 'package:flutter/material.dart';
import 'package:grad_project/screens/Home.dart';
import 'package:grad_project/screens/Language_Selection.dart';
import 'package:grad_project/screens/Sign_in.dart';
import 'package:grad_project/screens/Sign_up.dart';
import 'package:grad_project/screens/splash.dart';
import 'package:grad_project/screens/tutorial1.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/screens/CartItem.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/CartScreen.dart';
import 'package:grad_project/screens/Menu.dart';
import 'package:grad_project/screens/MenuItem.dart';
import 'package:grad_project/screens/MenuItemModel.dart';
import 'package:grad_project/screens/PaymentScreen.dart';
import 'package:grad_project/screens/Restaurant.dart';
import 'package:grad_project/screens/RestaurantCard.dart';
import 'package:grad_project/screens/RestaurantData.dart';
import 'package:grad_project/screens/RestaurantsScreen.dart';
import 'package:grad_project/screens/TrackOrderScreen.dart';

void main() {
  runApp(ChangeNotifierProvider(
    create: (context) => CartProvider(),
    child: const MyApp(),
  ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4169E1),
        fontFamily: 'Poppins',
      ),

      initialRoute: '/',

      routes: {
        '/': (context) => const RecOrderSplashScreen(),
        '/language': (context) => const LanguageSelectionScreen(),
        "/signin": (context) => const SignInScreen(),
        "/SignUp": (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        '/CartScreen': (context) => const CartScreen(),
        '/RestaurantsScreen': (context) => const RestaurantsScreen(),
        '/TrackOrderScreen': (context) => const TrackOrderScreen(),
        '/PaymentScreen': (context) => PaymentScreen(),
        '/tutorial1': (context) => const VoiceOnboardingScreen(),

      },

      // You will add localization here later
      // locale: Locale('en'),
      // supportedLocales: [Locale('en'), Locale('ar')],
    );
  }
}