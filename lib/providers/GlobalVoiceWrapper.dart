import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';

class GlobalVoiceWrapper extends StatelessWidget {
  final Widget child;
  const GlobalVoiceWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AppAudioProvider>(context);
    final lp = Provider.of<LanguageProvider>(context);

    // Get current route to hide mic on specific screens
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    final bool isHiddenScreen = currentRoute == '/' ||
        currentRoute == '/language' ||
        currentRoute == '/tutorial1';

    return Scaffold(
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isHiddenScreen
          ? null
          : FloatingActionButton(
        // Toggle Always-On mode instead of manual listening
        onPressed: () => audioProvider.toggleAlwaysOn(lp.currentLanguage, context),

        // Visual feedback: Green for Always-On, Red for Off
        backgroundColor: audioProvider.isAlwaysOn
            ? Colors.green
            : const Color(0xFFEB1B33),

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              if (audioProvider.isListening)
                BoxShadow(
                  color: audioProvider.isAlwaysOn
                      ? Colors.green.withOpacity(0.5)
                      : Colors.red.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 8,
                )
            ],
          ),
          child: Icon(
            // Show specific icons for the state
            audioProvider.isAlwaysOn ? Icons.record_voice_over : Icons.mic_none,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}