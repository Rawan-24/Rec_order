import 'package:flutter/material.dart';
import 'package:grad_project/screens/Language_Selection.dart';
import 'package:grad_project/screens/Sign_in.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rec-Order',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4169E1),
      ),
      home: const RecOrderSplashScreen(),
    );
  }
}

class RecOrderSplashScreen extends StatefulWidget {
  const RecOrderSplashScreen({Key? key}) : super(key: key);

  @override
  State<RecOrderSplashScreen> createState() => _RecOrderSplashScreenState();
}

class _RecOrderSplashScreenState extends State<RecOrderSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LanguageSelectionScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Microphone icon with red background
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFEB1B33), // Red color
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEB1B33).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 60,
              ),
            ),

            const SizedBox(height: 30),

            // Image logo instead of text "Rec-Order"
            Image.asset(
              'assets/images/logo.png', // Path to your logo image
              width: 200,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback in case image doesn't load
                return const Text(
                  'Rec-Order',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4169E1),
                    letterSpacing: 1,
                  ),
                );
              },
            ),

            const SizedBox(height: 15),

            // Tagline
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  Text(
                    'Record Your Voice',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blueGrey,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    ' Order Your Choice',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blueGrey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Moving dots animation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAnimatedDot(0),
                _buildAnimatedDot(1),
                _buildAnimatedDot(2),
              ],
            ),
          ],

        ),
      ),


      bottomNavigationBar: const BottomAppBar(
        color: Colors.white,
        elevation: 0,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Accessibility-First Voice Ordering',
              style: TextStyle(
                color: Color(0xFFEB1B33),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDot(int index) {
    late final Animation<double> animation;

    switch (index) {
      case 0:
        animation = Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
          ),
        );
        break;
      case 1:
        animation = Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.7, curve: Curves.easeInOut),
          ),
        );
        break;
      case 2:
        animation = Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.4, 0.9, curve: Curves.easeInOut),
          ),
        );
        break;
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 12 * animation.value,
          height: 12 * animation.value,
          decoration: BoxDecoration(
            color: const Color(0xFFEB1B33),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}