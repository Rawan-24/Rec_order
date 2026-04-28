import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grad_project/firebase_options.dart';
import 'package:grad_project/screens/Home.dart';
import 'package:grad_project/screens/Language_Selection.dart';
import 'package:grad_project/screens/Menu.dart';
import 'package:grad_project/screens/RestaurantData.dart';
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
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';
import 'DatabaseService.dart';
import 'connectivity_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:grad_project/notification_service.dart';
// ── Local notifications plugin (global so any file can use it) ────────────────
final FlutterLocalNotificationsPlugin localNotifications =
FlutterLocalNotificationsPlugin();

// ── Call this from anywhere to show a notification ────────────────────────────
Future<void> showLocalNotification(String title, String body) async {
  await localNotifications.show(
    0,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'order_channel',
        'Order Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

// ── Background FCM handler (must be top-level) ────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Background message received: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initLocalNotifications();

  // ── FCM background handler ─────────────────────────────────────────────────
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── FCM foreground handler ─────────────────────────────────────────────────
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final settings = await DatabaseService().getNotificationSettings(user.uid);
    final allOn = settings?['all'] == true;

    // Show the notification visually
    if (message.notification != null) {
      await showLocalNotification(
        message.notification!.title ?? '',
        message.notification!.body ?? '',
      );
    }

    // Sound
    if (allOn && settings?['sound'] == true) {
      await SystemSound.play(SystemSoundType.alert);
    }

    // Vibration
    if (allOn && settings?['vibration'] == true) {
      HapticFeedback.mediumImpact();
    }

    debugPrint("Foreground message: ${message.notification?.title}");
  });

  // ── Request notification permission ───────────────────────────────────────
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  try {
    final db = DatabaseService();
    await db.uploadMockData(RestaurantData.restaurants);
  } catch (e) {
    debugPrint("Seeding skipped (user not auth yet): $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
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
          builder: (context, child) {
            return ConnectivityWrapper(
              child: ConnectivityWrapper(child: child!),
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
            '/TrackOrderScreen': (context) => const TrackOrderScreen(orderId: ''),
            '/PaymentScreen': (context) => const PaymentScreen(),
            '/tutorial1': (context) => const VoiceOnboardingScreen(),
          },
        );
      },
    );
  }
}