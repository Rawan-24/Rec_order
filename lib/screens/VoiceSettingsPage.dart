import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';

class VoiceSettingsPage extends StatefulWidget {
  static const String routeName = "VoiceSettings";
  const VoiceSettingsPage({super.key});

  @override
  State<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  // ── Settings state ────────────────────────────────────────────────────────
  bool   _voiceCommands     = true;   // master mic on/off
  bool   _voiceFeedback     = true;   // TTS spoken responses on/off
  bool   _wakeWord          = true;   // continuous always-on listening on/off
  bool   _autoListen        = false;
  bool   _voiceConfirmation = true;
  double _volume            = 80;
  String _selectedSpeed     = "1.0x Normal";
  String _selectedLanguage  = "English (US)";

  bool _shouldListen = true;
  bool _isProcessing = false;

  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    _loadSettingsFromServer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp    = Provider.of<LanguageProvider>(context, listen: false);
      await Future.delayed(const Duration(milliseconds: 500));
      await audio.initSpeech();
      await _speakIntro(lp);
    });
  }

  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }

  // ── Intro ─────────────────────────────────────────────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();
    await audio.speak(
      lp.isEnglish
          ? "Voice settings. "
          "Say turn on voice commands or turn off voice commands. "
          "Say turn on voice feedback or turn off voice feedback. "
          "Say turn on wake word or turn off wake word. "
          "Say English or Arabic to change the language. "
          "Say speed and a value like 1.5, or volume up or down. "
          "Say go back."
          : "إعدادات الصوت. "
          "قل شغّل أوامر الصوت أو أوقف أوامر الصوت. "
          "قل شغّل الردود الصوتية أو أوقفها. "
          "قل شغّل كلمة التنبيه أو أوقفها. "
          "قل إنجليزي أو عربي لتغيير اللغة. "
          "قل سرعة ثم رقم، أو صوت أعلى أو أخفض. "
          "قل ارجع.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  // ── Listen loop ───────────────────────────────────────────────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    // Respect the voice-commands master toggle — don't start mic if disabled
    if (!_voiceCommands) return;

    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (VoiceSettings): $text");

        final local = _tryParseLocally(text);
        final Map<String, dynamic> response;
        if (local != null) {
          debugPrint("LOCAL MATCH (VoiceSettings): $local");
          response = local;
        } else {
          response = await AIService.sendMessage(text);
        }

        final command = (response['command'] ?? "unknown").toString();
        debugPrint("AI COMMAND (VoiceSettings): $command");

        await _handleCommand(command, text, lp);

        _isProcessing = false;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted && _voiceCommands) _startListening(lp);
        });
      },
      onError: (errorMsg) {
        if (!_shouldListen || !mounted || _isProcessing) return;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_shouldListen && mounted && !_isProcessing && _voiceCommands)
            _startListening(lp);
        });
      },
    );
  }

  // ── Local pre-parser ──────────────────────────────────────────────────────
  Map<String, dynamic>? _tryParseLocally(String text) {
    final lower = text.toLowerCase().trim();

    // Voice commands toggle
    if (lower.contains('turn on voice command') ||
        lower.contains('enable voice command') ||
        lower.contains('شغّل أوامر الصوت') ||
        lower.contains('تشغيل أوامر')) {
      return {'command': 'voice_commands_on'};
    }
    if (lower.contains('turn off voice command') ||
        lower.contains('disable voice command') ||
        lower.contains('أوقف أوامر الصوت') ||
        lower.contains('إيقاف أوامر')) {
      return {'command': 'voice_commands_off'};
    }

    // Voice feedback toggle
    if (lower.contains('turn on voice feedback') ||
        lower.contains('enable voice feedback') ||
        lower.contains('turn on feedback') ||
        lower.contains('شغّل الردود الصوتية') ||
        lower.contains('تشغيل الردود')) {
      return {'command': 'voice_feedback_on'};
    }
    if (lower.contains('turn off voice feedback') ||
        lower.contains('disable voice feedback') ||
        lower.contains('turn off feedback') ||
        lower.contains('أوقف الردود الصوتية') ||
        lower.contains('إيقاف الردود')) {
      return {'command': 'voice_feedback_off'};
    }

    // Wake word toggle
    if (lower.contains('turn on wake word') ||
        lower.contains('enable wake word') ||
        lower.contains('شغّل كلمة التنبيه')) {
      return {'command': 'wake_word_on'};
    }
    if (lower.contains('turn off wake word') ||
        lower.contains('disable wake word') ||
        lower.contains('أوقف كلمة التنبيه')) {
      return {'command': 'wake_word_off'};
    }

    // Speed
    final speedMap = {
      '0.5': '0.5x', '0.75': '0.75x', '1.0': '1.0x Normal',
      '1.25': '1.25x', '1.5': '1.5x', '2.0': '2.0x', '2': '2.0x',
    };
    for (final entry in speedMap.entries) {
      if (lower.contains(entry.key)) {
        return {'command': 'set_speed', 'value': entry.value};
      }
    }
    if (lower.contains('normal speed') || lower.contains('سرعة عادية'))
      return {'command': 'set_speed', 'value': '1.0x Normal'};
    if ((lower.contains('slow') && !lower.contains('very')) ||
        lower.contains('بطيء'))
      return {'command': 'set_speed', 'value': '0.75x'};
    if (lower.contains('very slow') || lower.contains('بطيء جداً'))
      return {'command': 'set_speed', 'value': '0.5x'};
    if ((lower.contains('fast') && !lower.contains('very')) ||
        lower.contains('سريع'))
      return {'command': 'set_speed', 'value': '1.25x'};
    if (lower.contains('very fast') || lower.contains('سريع جداً'))
      return {'command': 'set_speed', 'value': '2.0x'};

    // Volume
    if (lower.contains('volume up') ||
        lower.contains('louder') ||
        lower.contains('أعلى') ||
        lower.contains('ارفع الصوت'))
      return {'command': 'volume_up'};
    if (lower.contains('volume down') ||
        lower.contains('quieter') ||
        lower.contains('softer') ||
        lower.contains('أخفض') ||
        lower.contains('خفض الصوت'))
      return {'command': 'volume_down'};

    // Language
    if (lower.contains('english') || lower.contains('إنجليزي'))
      return {'command': 'language_en'};
    if (lower.contains('arabic') ||
        lower.contains('عربي') ||
        lower.contains('عربية'))
      return {'command': 'language_ar'};

    // Go back
    if (lower.contains('go back') ||
        lower.contains('ارجع') ||
        lower.contains('رجوع'))
      return {'command': 'go_back'};

    return null;
  }

  // ── Command handler ───────────────────────────────────────────────────────
  Future<void> _handleCommand(
      String command, String rawText, LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    switch (command) {

    // ── Voice Commands master toggle ───────────────────────────────────────
      case 'voice_commands_on':
        setState(() => _voiceCommands = true);
        // Wire: actually re-enable the mic
        _saveToCloud();
        await _speakIfEnabled(
          audio, lp,
          en: "Voice commands turned on.",
          ar: "تم تشغيل أوامر الصوت.",
        );
        // Restart mic now that it's re-enabled
        _shouldListen = true;
        _startListening(lp);
        break;

      case 'voice_commands_off':
        setState(() => _voiceCommands = false);
        _shouldListen = false;
        // Wire: actually stop the mic
        await audio.stop();
        _saveToCloud();
        // Speak the confirmation before mic goes quiet
        await audio.speak(
          lp.isEnglish
              ? "Voice commands turned off. Tap the mic button to re-enable."
              : "تم إيقاف أوامر الصوت. اضغط زر الميكروفون لإعادة التشغيل.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

    // ── Voice Feedback toggle ──────────────────────────────────────────────
      case 'voice_feedback_on':
        setState(() => _voiceFeedback = true);
        // Wire: tell AudioProvider to allow TTS
        audio.setFeedbackEnabled(true);
        _saveToCloud();
        await _speakIfEnabled(
          audio, lp,
          en: "Voice feedback turned on. I will now speak responses.",
          ar: "تم تشغيل الردود الصوتية. سأقرأ الردود الآن.",
        );
        break;

      case 'voice_feedback_off':
        setState(() => _voiceFeedback = false);
        // Speak the last confirmation BEFORE disabling
        await audio.speak(
          lp.isEnglish
              ? "Voice feedback turned off. I will no longer speak."
              : "تم إيقاف الردود الصوتية.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        // Wire: tell AudioProvider to suppress TTS
        audio.setFeedbackEnabled(false);
        _saveToCloud();
        break;

    // ── Wake Word toggle ───────────────────────────────────────────────────
      case 'wake_word_on':
        setState(() => _wakeWord = true);
        _saveToCloud();
        await _speakIfEnabled(
          audio, lp,
          en: "Wake word enabled. The mic will listen continuously.",
          ar: "تم تشغيل كلمة التنبيه. الميكروفون يستمع باستمرار.",
        );
        // Wire: restart the always-on loop
        if (_voiceCommands) {
          _shouldListen = true;
          _startListening(lp);
        }
        break;

      case 'wake_word_off':
        setState(() => _wakeWord = false);
        // Wire: stop the continuous loop
        _shouldListen = false;
        await audio.stop();
        _saveToCloud();
        await _speakIfEnabled(
          audio, lp,
          en: "Wake word disabled. Tap the mic to speak.",
          ar: "تم إيقاف كلمة التنبيه. اضغط الميكروفون للتحدث.",
        );
        break;

    // ── Speed ──────────────────────────────────────────────────────────────
      case 'set_speed':
        final label = (rawText.isNotEmpty
            ? rawText
            : _selectedSpeed); // local parser already sets value
        // Use response['value'] if coming from local parser
        break; // handled by _applySpeed via local parser value below

    // ── Volume ─────────────────────────────────────────────────────────────
      case 'volume_up':
        await _applyVolumeDelta(10, lp, audio);
        break;

      case 'volume_down':
        await _applyVolumeDelta(-10, lp, audio);
        break;

    // ── Language ───────────────────────────────────────────────────────────
      case 'language_en':
        await _handleLanguageChange("English (US)");
        break;

      case 'language_ar':
        await _handleLanguageChange("Arabic (EG)");
        break;

      case 'go_back':
        _shouldListen = false;
        if (mounted) Navigator.pop(context);
        break;

      case 'open_voice_settings':
        await _speakIntro(lp);
        break;

      default:
        await _speakIfEnabled(
          audio, lp,
          en: "Say turn on or off voice commands, voice feedback, or wake word. "
              "Say speed, volume up or down, language, or go back.",
          ar: "قل شغّل أو أوقف أوامر الصوت، الردود الصوتية، أو كلمة التنبيه. "
              "قل سرعة أو صوت أو لغة أو ارجع.",
        );
    }

    // Handle 'set_speed' value from local parser
    if (command == 'set_speed') {
      // _tryParseLocally returns {'command':'set_speed','value':'1.5x'}
      // but _handleCommand only receives command + rawText.
      // Re-parse to get the value:
      final local = _tryParseLocally(rawText);
      final speedLabel = (local?['value'] ?? '1.0x Normal').toString();
      await _applySpeed(speedLabel, lp, audio);
    }
  }

  // ── Helper: only speak if feedback is enabled ─────────────────────────────
  Future<void> _speakIfEnabled(
      AppAudioProvider audio,
      LanguageProvider lp, {
        required String en,
        required String ar,
      }) async {
    if (!_voiceFeedback) return;
    await audio.speak(
      lp.isEnglish ? en : ar,
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  Future<void> _applySpeed(
      String label, LanguageProvider lp, AppAudioProvider audio) async {
    // Normalise: "1.5x" -> 1.5, "1.0x Normal" -> 1.0
    final numStr = label.split('x')[0];
    final rate   = double.tryParse(numStr) ?? 1.0;
    setState(() => _selectedSpeed = label);
    audio.setSpeechRate(rate);
    _saveToCloud();
    await _speakIfEnabled(
      audio, lp,
      en: "Speed set to $label.",
      ar: "تم ضبط السرعة على $label.",
    );
  }

  Future<void> _applyVolumeDelta(
      int delta, LanguageProvider lp, AppAudioProvider audio) async {
    final newVol = (_volume + delta).clamp(0.0, 100.0);
    setState(() => _volume = newVol);
    audio.setVolume(newVol / 100);
    _saveToCloud();
    await _speakIfEnabled(
      audio, lp,
      en: "Volume set to ${newVol.round()} percent.",
      ar: "تم ضبط الصوت على ${newVol.round()} بالمئة.",
    );
  }

  // ── Load / save ───────────────────────────────────────────────────────────
  Future<void> _loadSettingsFromServer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final settings = await DatabaseService().getUserVoiceSettings(user.uid);
    if (settings != null && mounted) {
      setState(() {
        _selectedSpeed     = settings['speed']             ?? "1.0x Normal";
        _volume            = (settings['volume']           ?? 80.0).toDouble();
        _selectedLanguage  = settings['language']          ?? "English (US)";
        _wakeWord          = settings['wakeWord']          ?? true;
        _voiceFeedback     = settings['voiceFeedback']     ?? true;
        _voiceCommands     = settings['voiceCommands']     ?? true;
        _autoListen        = settings['autoListen']        ?? false;
        _voiceConfirmation = settings['voiceConfirmation'] ?? true;
      });
      _syncProviders();
    }
  }

  void _syncProviders() {
    final lp    = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    final code = _selectedLanguage.contains("Arabic") ? 'ar' : 'en';
    if (lp.currentLanguage != code) lp.changeLanguage(code);

    final rate = double.tryParse(_selectedSpeed.split('x')[0]) ?? 1.0;
    audio.setSpeechRate(rate);
    audio.setVolume(_volume / 100);
    audio.setFeedbackEnabled(_voiceFeedback);   // ← sync feedback on load
  }

  Future<void> _handleLanguageChange(String displayName) async {
    final lp    = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    setState(() => _selectedLanguage = displayName);
    final code = displayName.contains("Arabic") ? 'ar' : 'en';
    await lp.changeLanguage(code);
    await _speakIfEnabled(
      audio, lp,
      en: "Language changed to English.",
      ar: "تم تغيير اللغة إلى العربية.",
    );
    _saveToCloud();
  }

  Future<void> _saveToCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService().updateVoiceSettings(user.uid, {
          'speed':             _selectedSpeed,
          'volume':            _volume,
          'language':          _selectedLanguage,
          'wakeWord':          _wakeWord,
          'voiceFeedback':     _voiceFeedback,
          'voiceCommands':     _voiceCommands,
          'autoListen':        _autoListen,
          'voiceConfirmation': _voiceConfirmation,
          'lastUpdated':       FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Sync failed")));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp    = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: primaryRed,
        elevation: 0,
        title: Text(lp.getText('voice_settings_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSettingsFromServer),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildVisualHeader(audio, lp),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVoiceHint(lp, audio),
                  const SizedBox(height: 25),
                  _buildMainVoiceToggle(lp),
                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.settings_voice,
                      lp.getText('voice_features_header')),
                  _buildSettingsGroup([
                    _buildToggleTile(
                      lp.getText('voice_feedback_title'),
                      lp.getText('voice_feedback_sub'),
                      _voiceFeedback,
                          (v) {
                        setState(() => _voiceFeedback = v);
                        // Wire: enable/disable TTS immediately
                        audio.setFeedbackEnabled(v);
                        if (v) {
                          audio.speak(
                            lp.isEnglish
                                ? "Voice feedback turned on."
                                : "تم تشغيل الردود الصوتية.",
                            lp.isEnglish ? "en-US" : "ar-SA",
                          );
                        }
                        _saveToCloud();
                      },
                      Icons.volume_up_outlined,
                    ),
                    _buildToggleTile(
                      lp.getText('wake_word_title'),
                      lp.getText('wake_word_sub'),
                      _wakeWord,
                          (v) {
                        setState(() => _wakeWord = v);
                        if (v) {
                          // Wire: restart always-on listen loop
                          _shouldListen = true;
                          _startListening(lp);
                          if (_voiceFeedback) {
                            audio.speak(
                              lp.isEnglish
                                  ? "Wake word enabled."
                                  : "تم تشغيل كلمة التنبيه.",
                              lp.isEnglish ? "en-US" : "ar-SA",
                            );
                          }
                        } else {
                          // Wire: stop the always-on loop
                          _shouldListen = false;
                          audio.stop();
                          if (_voiceFeedback) {
                            audio.speak(
                              lp.isEnglish
                                  ? "Wake word disabled. Tap mic to speak."
                                  : "تم إيقاف كلمة التنبيه.",
                              lp.isEnglish ? "en-US" : "ar-SA",
                            );
                          }
                        }
                        _saveToCloud();
                      },
                      Icons.record_voice_over,
                    ),
                  ]),
                  const SizedBox(height: 25),
                  _buildSectionHeader(
                      Icons.speed, lp.getText('speech_speed_header')),
                  _buildSpeedSelector(audio, lp),
                  const SizedBox(height: 25),
                  _buildSectionHeader(
                      Icons.volume_up, lp.getText('voice_volume_header')),
                  _buildVolumeSlider(lp, audio),
                  const SizedBox(height: 25),
                  _buildSectionHeader(
                      Icons.translate, lp.getText('voice_lang_header')),
                  _buildLanguageSelector(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: audio.isListening ? Colors.green : primaryRed,
        onPressed: () {
          if (!audio.speech.isListening && !_isProcessing) {
            _shouldListen  = true;
            _voiceCommands = true; // re-enable if they tapped manually
            _startListening(
                Provider.of<LanguageProvider>(context, listen: false));
          }
        },
        child: Icon(
          audio.isListening ? Icons.graphic_eq : Icons.mic,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildVisualHeader(AppAudioProvider audio, LanguageProvider lp) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryRed,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            audio.isListening ? Icons.graphic_eq : Icons.mic,
            color: Colors.white,
            size: 50,
          ),
          if (audio.isListening)
            Text(
              audio.lastWords.isEmpty
                  ? (lp.isEnglish ? "Listening..." : "أنا أسمعك...")
                  : audio.lastWords,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceHint(LanguageProvider lp, AppAudioProvider audio) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: primaryRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: primaryRed, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              audio.isListening
                  ? (audio.lastWords.isEmpty
                  ? (lp.isEnglish ? "Listening..." : "أنا أسمعك...")
                  : audio.lastWords)
                  : lp.getText('voice_hint_text'),
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVoiceToggle(LanguageProvider lp) {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: primaryRed.withOpacity(0.1),
              child: Icon(Icons.mic, color: primaryRed)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lp.getText('voice_commands_main'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                  Text(
                    _voiceCommands
                        ? lp.getText('voice_status_active')
                        : (lp.isEnglish ? "Disabled" : "معطّل"),
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ]),
          ),
          Switch(
            value: _voiceCommands,
            activeColor: primaryRed,
            onChanged: (v) {
              setState(() => _voiceCommands = v);
              if (v) {
                // Re-enable mic
                _shouldListen = true;
                _startListening(
                    Provider.of<LanguageProvider>(context, listen: false));
                if (_voiceFeedback) {
                  audio.speak(
                    lp.isEnglish
                        ? "Voice commands enabled."
                        : "تم تشغيل أوامر الصوت.",
                    lp.isEnglish ? "en-US" : "ar-SA",
                  );
                }
              } else {
                // Disable mic
                _shouldListen = false;
                audio.stop();
                audio.speak(
                  lp.isEnglish
                      ? "Voice commands disabled."
                      : "تم إيقاف أوامر الصوت.",
                  lp.isEnglish ? "en-US" : "ar-SA",
                );
              }
              _saveToCloud();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02), blurRadius: 5)
          ]),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(String title, String sub, bool val,
      Function(bool) onChanged, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(sub,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Switch(
        value: val,
        onChanged: _voiceCommands ? onChanged : null,
        activeColor: primaryRed,
      ),
    );
  }

  Widget _buildSpeedSelector(AppAudioProvider audio, LanguageProvider lp) {
    final speeds = [
      "0.5x", "0.75x", "1.0x Normal", "1.25x", "1.5x", "2.0x"
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15)),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: speeds
            .map((s) => ChoiceChip(
          label: Text(s),
          selected: _selectedSpeed == s,
          onSelected: (selected) {
            if (selected) _applySpeed(s, lp, audio);
          },
          selectedColor: primaryRed,
          labelStyle: TextStyle(
              color: _selectedSpeed == s
                  ? Colors.white
                  : Colors.black87),
        ))
            .toList(),
      ),
    );
  }

  Widget _buildVolumeSlider(LanguageProvider lp, AppAudioProvider audio) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Slider(
            value: _volume,
            min: 0,
            max: 100,
            activeColor: primaryRed,
            inactiveColor: primaryRed.withOpacity(0.2),
            onChanged: (v) => setState(() => _volume = v),
            onChangeEnd: (v) {
              audio.setVolume(v / 100);
              _saveToCloud();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(lp.getText('vol_silent'),
                      style: const TextStyle(color: Colors.grey)),
                  Text("${_volume.round()}%",
                      style: TextStyle(
                          color: primaryRed,
                          fontWeight: FontWeight.bold)),
                  Text(lp.getText('vol_loud'),
                      style: const TextStyle(color: Colors.grey)),
                ]),
          )
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final langs = ["English (US)", "Arabic (EG)"];
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: langs
            .map((l) => RadioListTile(
          title: Text(l),
          value: l,
          groupValue: _selectedLanguage,
          activeColor: primaryRed,
          onChanged: (v) {
            if (v != null) _handleLanguageChange(v.toString());
          },
        ))
            .toList(),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }
}