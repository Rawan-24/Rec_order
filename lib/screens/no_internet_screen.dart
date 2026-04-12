import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:provider/provider.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 80, color: Colors.red),
            const SizedBox(height: 20),
             Text(
              lp.getText('no_internet_title'),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
             Text(lp.getText('no_internet_msg')),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // You could trigger a manual re-check here
              },
              child: Text(lp.getText('try_again')),
            )
          ],
        ),
      ),
    );
  }
}