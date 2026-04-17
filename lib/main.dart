import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/firebase_options.dart';
import 'package:grad_project/providers/GlobalVoiceWrapper.dart';
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
import 'package:grad_project/providers/AudioProvider.dart'; // Audio Provider Import
import 'package:provider/provider.dart';
import 'connectivity_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  // Required for Firebase and Plugin initialization
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        // 1. Manages the Shopping Cart
        ChangeNotifierProvider(create: (_) => CartProvider()),

        // 2. Manages UI Language (English / Arabic)
        ChangeNotifierProvider(create: (_) => LanguageProvider()),

        // 3. Manages Global Voice (TTS/STT) in Egyptian/English
        ChangeNotifierProvider(create: (_) => AppAudioProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lp, child) {
        return MaterialApp(
          locale: Locale(lp.currentLanguage),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: const Color(0xFF4169E1),
            fontFamily: 'Poppins',
          ),
          // FIX: Nested builders to include both Connectivity and Voice
          builder: (context, child) {
            return ConnectivityWrapper(
              child: GlobalVoiceWrapper(child: child!),
            );
          },
          initialRoute: '/',
          routes: {
            '/': (context) => const RecOrderSplashScreen(),
            '/language': (context) => const LanguageSelectionScreen(),
            "/signin": (context) => const SignInScreen(),
            "/SignUp": (context) => const SignUpPage(),
            '/VerificationScreen': (context) => const VerificationScreen(),
            '/profile': (context) => const ProfilePage(),
            '/home': (context) => const HomePage(),
            '/TrackOrderScreen': (context) => const TrackOrderScreen(orderId: ''), // Consider passing ID via arguments
            '/PaymentScreen': (context) => const PaymentScreen(),
            '/tutorial1': (context) => const VoiceOnboardingScreen(),
          },
        );
      },
    );
  }
}