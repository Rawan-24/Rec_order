import 'package:flutter/material.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              "Whoops!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text("Check your internet connection."),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // You could trigger a manual re-check here
              },
              child: const Text("Try Again"),
            )
          ],
        ),
      ),
    );
  }
}