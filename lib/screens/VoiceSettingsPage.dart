import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Standardized Provider
import 'package:provider/provider.dart';

class VoiceSettingsPage extends StatefulWidget {
  static const String routeName = "VoiceSettings";
  const VoiceSettingsPage({super.key});

  @override
  State<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  bool _voiceCommands = true;
  bool _voiceFeedback = true;
  bool _wakeWord = true;
  bool _autoListen = false;
  bool _voiceConfirmation = true;
  double _volume = 80;
  String _selectedSpeed = "1.0x Normal";
  String _selectedLanguage = "English (US)";

  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    _loadSettingsFromServer();
  }

  Future<void> _loadSettingsFromServer() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Map<String, dynamic>? settings = await DatabaseService().getUserVoiceSettings(user.uid);

      if (settings != null && mounted) {
        setState(() {
          _selectedSpeed = settings['speed'] ?? "1.0x Normal";
          _volume = (settings['volume'] ?? 80.0).toDouble();
          _selectedLanguage = settings['language'] ?? "English (US)";
          _wakeWord = settings['wakeWord'] ?? true;
          _voiceFeedback = settings['voiceFeedback'] ?? true;
          _voiceCommands = settings['voiceCommands'] ?? true;
          _autoListen = settings['autoListen'] ?? false;
          _voiceConfirmation = settings['voiceConfirmation'] ?? true;
        });

        // Update local providers to match server data
        _syncProviders();
      }
    }
  }

  void _syncProviders() {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    String code = _selectedLanguage.contains("Arabic") ? 'ar' : 'en';
    if (lp.currentLanguage != code) lp.changeLanguage(code);

    // Apply speech rate and volume to the global audio provider
    double rate = double.parse(_selectedSpeed.split('x')[0]);
    audio.setSpeechRate(rate);
    audio.setVolume(_volume / 100);
  }

  Future<void> _handleLanguageChange(String selectedDisplayName) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    setState(() => _selectedLanguage = selectedDisplayName);

    String code = selectedDisplayName.contains("Arabic") ? 'ar' : 'en';
    await lp.changeLanguage(code);

    // Give a voice confirmation of the language change
    await audio.speak(
        code == 'ar' ? "تم تغيير اللغة إلى العربية" : "Language changed to English",
        lp.currentLanguage
    );

    _saveToCloud();
  }

  Future<void> _saveToCloud() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService().updateVoiceSettings(user.uid, {
          'speed': _selectedSpeed,
          'volume': _volume,
          'language': _selectedLanguage,
          'wakeWord': _wakeWord,
          'voiceFeedback': _voiceFeedback,
          'voiceCommands': _voiceCommands,
          'autoListen': _autoListen,
          'voiceConfirmation': _voiceConfirmation,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sync failed")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4), // Standard app cream background
      appBar: AppBar(
        backgroundColor: primaryRed,
        elevation: 0,
        title: Text(lp.getText('voice_settings_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSettingsFromServer),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildVisualHeader(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVoiceHint(lp),
                  const SizedBox(height: 25),
                  _buildMainVoiceToggle(lp),
                  const SizedBox(height: 25),

                  _buildSectionHeader(Icons.settings_voice, lp.getText('voice_features_header')),
                  _buildSettingsGroup([
                    _buildToggleTile(lp.getText('voice_feedback_title'), lp.getText('voice_feedback_sub'), _voiceFeedback, (v) {
                      setState(() => _voiceFeedback = v);
                      _saveToCloud();
                    }, Icons.volume_up_outlined),
                    _buildToggleTile(lp.getText('wake_word_title'), lp.getText('wake_word_sub'), _wakeWord, (v) {
                      setState(() => _wakeWord = v);
                      _saveToCloud();
                    }, Icons.record_voice_over),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.speed, lp.getText('speech_speed_header')),
                  _buildSpeedSelector(),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.volume_up, lp.getText('voice_volume_header')),
                  _buildVolumeSlider(lp),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.translate, lp.getText('voice_lang_header')),
                  _buildLanguageSelector(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualHeader() {
    return Container(
      height: 120, width: double.infinity,
      decoration: BoxDecoration(
        color: primaryRed,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: const Center(
        child: Icon(Icons.mic, color: Colors.white, size: 60),
      ),
    );
  }

  Widget _buildVoiceHint(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: primaryRed.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: primaryRed, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(lp.getText('voice_hint_text'), style: const TextStyle(color: Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildMainVoiceToggle(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: primaryRed.withOpacity(0.1), child: Icon(Icons.mic, color: primaryRed)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lp.getText('voice_commands_main'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              Text(_voiceCommands ? lp.getText('voice_status_active') : "Disabled", style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ]),
          ),
          Switch(value: _voiceCommands, activeColor: primaryRed, onChanged: (v) {
            setState(() => _voiceCommands = v);
            _saveToCloud();
          }),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(String title, String sub, bool val, Function(bool) onChanged, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Switch(
        value: val,
        onChanged: _voiceCommands ? onChanged : null,
        activeColor: primaryRed,
      ),
    );
  }

  Widget _buildSpeedSelector() {
    List<String> speeds = ["0.5x", "0.75x", "1.0x Normal", "1.25x", "1.5x", "2.0x"];
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: speeds.map((s) => ChoiceChip(
          label: Text(s),
          selected: _selectedSpeed == s,
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedSpeed = s);
              double rate = double.parse(s.split('x')[0]);
              audio.setSpeechRate(rate);
              _saveToCloud();
            }
          },
          selectedColor: primaryRed,
          labelStyle: TextStyle(color: _selectedSpeed == s ? Colors.white : Colors.black87),
        )).toList(),
      ),
    );
  }

  Widget _buildVolumeSlider(LanguageProvider lp) {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Slider(
            value: _volume, min: 0, max: 100,
            activeColor: primaryRed, inactiveColor: primaryRed.withOpacity(0.2),
            onChanged: (v) => setState(() => _volume = v),
            onChangeEnd: (v) {
              audio.setVolume(v / 100);
              _saveToCloud();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(lp.getText('vol_silent'), style: const TextStyle(color: Colors.grey)),
              Text("${_volume.round()}%", style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
              Text(lp.getText('vol_loud'), style: const TextStyle(color: Colors.grey)),
            ]),
          )
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    List<String> langs = ["English (US)", "Arabic (EG)"];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: langs.map((l) => RadioListTile(
          title: Text(l),
          value: l,
          groupValue: _selectedLanguage,
          activeColor: primaryRed,
          onChanged: (v) {
            if (v != null) _handleLanguageChange(v.toString());
          },
        )).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }
}