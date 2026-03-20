import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/firebase_options.dart';
import 'package:grad_project/screens/Home.dart';
import 'package:grad_project/screens/Language_Selection.dart';
import 'package:grad_project/screens/Sign_in.dart';
import 'package:grad_project/screens/Sign_up.dart';
import 'package:grad_project/screens/splash.dart';
import 'package:grad_project/screens/tutorial1.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/CartScreen.dart';
import 'package:grad_project/screens/PaymentScreen.dart';
import 'package:grad_project/screens/RestaurantsScreen.dart';
import 'package:grad_project/screens/TrackOrderScreen.dart';

Future<void> main() async {
  runApp(ChangeNotifierProvider(
    create: (context) => CartProvider(),
    child: const MyApp(),
  ),
  );

  await Firebase.initializeApp(    
    options: DefaultFirebaseOptions.currentPlatform,
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