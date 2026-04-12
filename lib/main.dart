import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/firebase_options.dart';
import 'package:grad_project/screens/Home.dart';
import 'package:grad_project/screens/Language_Selection.dart';
import 'package:grad_project/screens/Sign_in.dart';
import 'package:grad_project/screens/Sign_up.dart';
import 'package:grad_project/screens/Verfiy.dart';
import 'package:grad_project/screens/profile.dart';
import 'package:grad_project/screens/splash.dart';
import 'package:grad_project/screens/tutorial1.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/CartScreen.dart';
import 'package:grad_project/screens/PaymentScreen.dart';
import 'package:grad_project/screens/RestaurantsScreen.dart';
import 'package:grad_project/screens/TrackOrderScreen.dart';
import 'package:grad_project/providers/LanguageProvider.dart'; 
import 'package:provider/provider.dart';
import 'connectivity_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We use Consumer here so the app rebuilds and flips direction 
    // immediately when the language changes.
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: const Color(0xFF4169E1),
            fontFamily: 'Poppins',
          ),
          
          // Combining ConnectivityWrapper and RTL Directionality
          builder: (context, child) {
            return Directionality(
              textDirection: langProvider.isRTL 
                  ? TextDirection.rtl 
                  : TextDirection.ltr,
              child: ConnectivityWrapper(child: child!),
            );
          },

          initialRoute: '/',
          routes: {
            '/': (context) => const RecOrderSplashScreen(),
            '/language': (context) => const LanguageSelectionScreen(),
            "/signin": (context) => const SignInScreen(),
            "/SignUp": (context) => const SignUpPage(),
            '/home': (context) => const HomePage(),
            '/CartScreen': (context) => const CartScreen(),
            '/RestaurantsScreen': (context) => const RestaurantsScreen(),
            '/TrackOrderScreen': (context) => const TrackOrderScreen(orderId: ''),
            '/PaymentScreen': (context) => const PaymentScreen(),
            '/tutorial1': (context) => const VoiceOnboardingScreen(),
            '/verfiy': (context) => const VerificationScreen(),
            'profile': (context) => const ProfilePage(),
          },
        );
      },
    );
  }
}