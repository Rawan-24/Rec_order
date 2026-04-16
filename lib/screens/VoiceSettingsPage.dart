import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';

class VoiceSettingsPage extends StatefulWidget {
  static const String routeName = "VoiceSettings";
  const VoiceSettingsPage({super.key});

  @override
  State<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  // --- Local State ---
  bool _voiceCommands = true;
  bool _voiceFeedback = true;
  double _volume = 80;
  String _selectedSpeed = "1.0x Normal";
  String _selectedLanguage = "English (US)";

  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    _loadSettingsFromServer();
  }

  /// Fetches saved preferences from Firestore and updates Providers
  Future<void> _loadSettingsFromServer() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Map<String, dynamic>? settings = await DatabaseService().getUserVoiceSettings(user.uid);

      if (settings != null && mounted) {
        setState(() {
          _selectedSpeed = settings['speed'] ?? "1.0x Normal";
          _volume = (settings['volume'] ?? 80.0).toDouble();
          _selectedLanguage = settings['language'] ?? "English (US)";
          _voiceFeedback = settings['voiceFeedback'] ?? true;
          _voiceCommands = settings['voiceCommands'] ?? true;
        });
        _syncGlobalProviders();
      }
    }
  }

  /// Applies local settings to the global Audio and Language Providers
  void _syncGlobalProviders() {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Sync Language
    String code = _selectedLanguage.contains("Arabic") ? 'ar' : 'en';
    if (lp.currentLanguage != code) lp.changeLanguage(code);

    // Sync Audio properties
    double rate = double.tryParse(_selectedSpeed.split('x')[0]) ?? 1.0;
    audio.setSpeechRate(rate);
    audio.setVolume(_volume / 100);
  }

  /// Handles language switching with immediate voice confirmation
  Future<void> _handleLanguageChange(String selectedDisplayName) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    setState(() => _selectedLanguage = selectedDisplayName);

    String code = selectedDisplayName.contains("Arabic") ? 'ar' : 'en';
    await lp.changeLanguage(code);

    // Audio confirmation in the newly selected language
    await audio.speak(
        code == 'ar' ? "تم تغيير لغة الصوت إلى العربية" : "Voice language set to English",
        lp.currentLanguage
    );

    _saveToCloud();
  }

  /// Persists settings to Firebase Firestore
  Future<void> _saveToCloud() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService().updateVoiceSettings(user.uid, {
          'speed': _selectedSpeed,
          'volume': _volume,
          'language': _selectedLanguage,
          'voiceFeedback': _voiceFeedback,
          'voiceCommands': _voiceCommands,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Firebase Sync Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(lp.getText('voice_settings_title'),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusHeader(lp),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  _buildMainToggleCard(lp),
                  const SizedBox(height: 25),

                  _buildSectionLabel(lp.getText('speech_speed_header'), Icons.speed_rounded),
                  _buildSpeedChips(),
                  const SizedBox(height: 25),

                  _buildSectionLabel(lp.getText('voice_volume_header'), Icons.volume_up_rounded),
                  _buildVolumeCard(lp),
                  const SizedBox(height: 25),

                  _buildSectionLabel(lp.getText('voice_lang_header'), Icons.translate_rounded),
                  _buildLanguageCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(LanguageProvider lp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: primaryRed.withOpacity(0.1),
            child: Icon(Icons.mic_rounded, color: primaryRed, size: 40),
          ),
          const SizedBox(height: 15),
          Text(_voiceCommands ? lp.getText('voice_status_active') : "Voice Inactive",
              style: TextStyle(
                color: _voiceCommands ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              )),
        ],
      ),
    );
  }

  Widget _buildMainToggleCard(LanguageProvider lp) {
    return _buildContainer([
      SwitchListTile(
        title: Text(lp.getText('voice_commands_main'), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(lp.getText('voice_hint_text'), style: const TextStyle(fontSize: 12)),
        value: _voiceCommands,
        activeColor: primaryRed,
        onChanged: (v) {
          setState(() => _voiceCommands = v);
          _saveToCloud();
        },
      ),
    ]);
  }

  Widget _buildSpeedChips() {
    List<String> speeds = ["0.75x", "1.0x Normal", "1.25x", "1.5x"];
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    return _buildContainer([
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: speeds.map((s) => ChoiceChip(
            label: Text(s),
            selected: _selectedSpeed == s,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedSpeed = s);
                audio.setSpeechRate(double.parse(s.split('x')[0]));
                _saveToCloud();
              }
            },
            selectedColor: primaryRed,
            labelStyle: TextStyle(
              color: _selectedSpeed == s ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          )).toList(),
        ),
      )
    ]);
  }

  Widget _buildVolumeCard(LanguageProvider lp) {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    return _buildContainer([
      Slider(
        value: _volume, min: 0, max: 100,
        activeColor: primaryRed,
        onChanged: (v) => setState(() => _volume = v),
        onChangeEnd: (v) {
          audio.setVolume(v / 100);
          _saveToCloud();
        },
      ),
      // FIXED: Used EdgeInsets.only to avoid the 'bottom' parameter error in symmetric
      Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lp.getText('vol_silent'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text("${_volume.toInt()}%", style: TextStyle(fontWeight: FontWeight.bold, color: primaryRed)),
            Text(lp.getText('vol_loud'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      )
    ]);
  }

  Widget _buildLanguageCard() {
    return _buildContainer([
      _langTile("English (US)", "en"),
      const Divider(indent: 20, endIndent: 20, height: 1),
      _langTile("Arabic (EG)", "ar"),
    ]);
  }

  Widget _langTile(String name, String code) {
    return RadioListTile(
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      value: name,
      groupValue: _selectedLanguage,
      activeColor: primaryRed,
      onChanged: (v) => _handleLanguageChange(v.toString()),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 5, right: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildContainer(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(children: children),
    );
  }
}