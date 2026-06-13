import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final Map<String, bool> _settings = {
    'all':            true,
    'order_conf':     true,
    'order_prep':     true,
    'out_delivery':   true,
    'delivered':      true,
    'special_offers': true,
    'voice':          true,
    'sound':          true,
    'vibration':      true,
    'push':           true,
  };

  static const Map<String, String> _fcmTopics = {
    'order_conf':     'order_confirmation',
    'order_prep':     'order_preparation',
    'out_delivery':   'out_for_delivery',
    'delivered':      'order_delivered',
    'special_offers': 'promotions',
  };

  bool _isLoading    = true;
  bool _shouldListen = true;
  bool _isProcessing = false;

  final Color primaryRed = const Color(0xFFD32F2F);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSettings();
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

  // ── Load / Save ────────────────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _isLoading = false); return; }

    try {
      final data = await DatabaseService().getNotificationSettings(user.uid);
      if (data != null && mounted) {
        setState(() {
          for (final key in _settings.keys) {
            if (data.containsKey(key)) _settings[key] = data[key] as bool;
          }
          _isLoading = false;
        });
        _syncProviders();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await DatabaseService().updateNotificationSettings(user.uid, {
        ..._settings,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Sync failed")));
      }
    }
  }

  // ── Sync side-effects ──────────────────────────────────────────────────────
  void _syncProviders() {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    audio.setFeedbackEnabled(_settings['voice']! && _settings['all']!);
  }

  Future<void> _applyToggle(String key, bool value) async {
    setState(() => _settings[key] = value);

    final audio   = Provider.of<AppAudioProvider>(context, listen: false);
    final lp      = Provider.of<LanguageProvider>(context, listen: false);
    final masterOn = key == 'all' ? value : (_settings['all'] ?? true);

    switch (key) {

    // ── Master toggle ──────────────────────────────────────────────────────
      case 'all':
        for (final topic in _fcmTopics.values) {
          value
              ? await FirebaseMessaging.instance.subscribeToTopic(topic)
              : await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        }
        audio.setFeedbackEnabled(value && (_settings['voice'] ?? true));
        break;

    // ── Order / promo → FCM topic ──────────────────────────────────────────
      case 'order_conf':
      case 'order_prep':
      case 'out_delivery':
      case 'delivered':
      case 'special_offers':
        if (!masterOn) break;
        final topic = _fcmTopics[key]!;
        value
            ? await FirebaseMessaging.instance.subscribeToTopic(topic)
            : await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        break;

    // ── Push: subscribe/unsubscribe all topics ─────────────────────────────
      case 'push':
        for (final entry in _fcmTopics.entries) {
          final individualOn = _settings[entry.key] ?? true;
          if (value && masterOn && individualOn) {
            await FirebaseMessaging.instance.subscribeToTopic(entry.value);
          } else {
            await FirebaseMessaging.instance.unsubscribeFromTopic(entry.value);
          }
        }
        break;

    // ── Voice announcements ────────────────────────────────────────────────
      case 'voice':
        audio.setFeedbackEnabled(value && masterOn);
        if (value && masterOn) {
          await audio.speak(
            lp.isEnglish
                ? "Voice announcements enabled."
                : "تم تفعيل الإعلانات الصوتية.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;

    // ── Sound: plays a click to confirm ───────────────────────────────────
      case 'sound':
        if (value && masterOn) {
          await SystemSound.play(SystemSoundType.click);
        }
        break;

    // ── Vibration: triggers haptic to confirm ──────────────────────────────
      case 'vibration':
        if (value && masterOn) {
          HapticFeedback.mediumImpact();
        }
        break;
    }

    await _saveSettings();
  }

  // ── Voice intro ────────────────────────────────────────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();
    final allOn = _settings['all'] == true;
    await audio.speak(
      lp.isEnglish
          ? "Notification settings. "
          "All notifications are currently ${allOn ? 'enabled' : 'disabled'}. "
          "Say enable all or disable all. "
          "Say order confirmation, order preparation, out for delivery, or delivered on or off. "
          "Say offers on or off, push on or off, sound on or off, "
          "vibration on or off, or voice on or off. "
          "Say go back to return."
          : "إعدادات التنبيهات. "
          "جميع التنبيهات حالياً ${allOn ? 'مفعلة' : 'معطلة'}. "
          "قل فعّل الكل أو عطّل الكل. "
          "قل تأكيد الطلب، تحضير الطلب، في الطريق، أو تم التوصيل تشغيل أو إيقاف. "
          "قل عروض، إشعارات، صوت، اهتزاز، أو صوت الإعلانات. "
          "قل ارجع للعودة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  // ── Listen loop ────────────────────────────────────────────────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (Notifications): $text");

        final local = _tryParseLocally(text);
        final Map<String, dynamic> response;
        if (local != null) {
          response = local;
        } else {
          response = await AIService.sendMessage(text, screen: "notifications");
        }

        final command = (response['command'] ?? "unknown").toString();
        debugPrint("AI COMMAND (Notifications): $command");

        await _handleCommand(command, text, lp);

        _isProcessing = false;

      },
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  // ── Local pre-parser ───────────────────────────────────────────────────────
  Map<String, dynamic>? _tryParseLocally(String text) {
    final lower = text.toLowerCase().trim();

    if (lower.contains('go back') || lower.contains('ارجع') || lower.contains('رجوع'))
      return {'command': 'go_back'};

    if (lower.contains('enable all') || lower.contains('فعّل الكل') || lower.contains('فعل الكل'))
      return {'command': 'enable_all'};
    if (lower.contains('disable all') || lower.contains('عطّل الكل') || lower.contains('عطل الكل'))
      return {'command': 'disable_all'};

    final isEnable = !lower.contains('off') &&
        !lower.contains('disable') &&
        !lower.contains('إيقاف') &&
        !lower.contains('تعطيل');

    // ── Order toggles ──────────────────────────────────────────────────────
    if (lower.contains('order confirm') || lower.contains('تأكيد الطلب'))
      return {'command': isEnable ? 'order_conf_on' : 'order_conf_off'};
    if (lower.contains('order prep') || lower.contains('تحضير الطلب'))
      return {'command': isEnable ? 'order_prep_on' : 'order_prep_off'};
    if (lower.contains('out for delivery') || lower.contains('في الطريق') || lower.contains('خروج'))
      return {'command': isEnable ? 'out_delivery_on' : 'out_delivery_off'};
    if (lower.contains('delivered') || lower.contains('وصل') || lower.contains('تم التوصيل'))
      return {'command': isEnable ? 'delivered_on' : 'delivered_off'};

    // ── Other toggles ──────────────────────────────────────────────────────
    if (lower.contains('offer') || lower.contains('promo') || lower.contains('عروض'))
      return {'command': isEnable ? 'offers_on' : 'offers_off'};
    if (lower.contains('push') || lower.contains('إشعار'))
      return {'command': isEnable ? 'push_on' : 'push_off'};
    if (lower.contains('sound') || lower.contains('صوت التنبيه'))
      return {'command': isEnable ? 'sound_on' : 'sound_off'};
    if (lower.contains('vibrat') || lower.contains('اهتزاز'))
      return {'command': isEnable ? 'vibration_on' : 'vibration_off'};
    if (lower.contains('voice') || lower.contains('الصوت') || lower.contains('صوت الإعلان'))
      return {'command': isEnable ? 'voice_on' : 'voice_off'};

    return null;
  }

  // ── Command handler ────────────────────────────────────────────────────────
  Future<void> _handleCommand(
      String command, String rawText, LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    Future<void> say(String en, String ar) => audio.speak(
      lp.isEnglish ? en : ar,
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    switch (command) {
      case 'go_back':
        _shouldListen = false;
        await audio.stop();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.pop(context);
        return;

      case 'enable_all':
      case 'enable_all_notifications':    // ← add this

        await _applyToggle('all', true);
        await say("All notifications enabled.", "تم تفعيل جميع التنبيهات.");
        return;

      case 'disable_all':
      case 'disable_all_notifications':
        await _applyToggle('all', false);
        await say("All notifications disabled.", "تم تعطيل جميع التنبيهات.");
        return;

    // ── Order cases ────────────────────────────────────────────────────────
      case 'order_conf_on':
        await _applyToggle('order_conf', true);
        await say("Order confirmation notifications enabled.", "تم تفعيل تنبيهات تأكيد الطلب.");
        return;
      case 'order_conf_off':
        await _applyToggle('order_conf', false);
        await say("Order confirmation notifications disabled.", "تم تعطيل تنبيهات تأكيد الطلب.");
        return;

      case 'order_prep_on':
        await _applyToggle('order_prep', true);
        await say("Order preparation notifications enabled.", "تم تفعيل تنبيهات تحضير الطلب.");
        return;
      case 'order_prep_off':
        await _applyToggle('order_prep', false);
        await say("Order preparation notifications disabled.", "تم تعطيل تنبيهات تحضير الطلب.");
        return;

      case 'out_delivery_on':
        await _applyToggle('out_delivery', true);
        await say("Out for delivery notifications enabled.", "تم تفعيل تنبيهات خروج الطلب للتوصيل.");
        return;
      case 'out_delivery_off':
        await _applyToggle('out_delivery', false);
        await say("Out for delivery notifications disabled.", "تم تعطيل تنبيهات خروج الطلب للتوصيل.");
        return;

      case 'delivered_on':
        await _applyToggle('delivered', true);
        await say("Delivery confirmation notifications enabled.", "تم تفعيل تنبيهات استلام الطلب.");
        return;
      case 'delivered_off':
        await _applyToggle('delivered', false);
        await say("Delivery confirmation notifications disabled.", "تم تعطيل تنبيهات استلام الطلب.");
        return;

    // ── Other cases ────────────────────────────────────────────────────────
      case 'offers_on':
        await _applyToggle('special_offers', true);
        await say("Offer notifications enabled.", "تم تفعيل تنبيهات العروض.");
        return;
      case 'offers_off':
        await _applyToggle('special_offers', false);
        await say("Offer notifications disabled.", "تم تعطيل تنبيهات العروض.");
        return;

      case 'push_on':
        await _applyToggle('push', true);
        await say("Push notifications enabled.", "تم تفعيل الإشعارات الفورية.");
        return;
      case 'push_off':
        await _applyToggle('push', false);
        await say("Push notifications disabled.", "تم تعطيل الإشعارات الفورية.");
        return;

      case 'sound_on':
        await _applyToggle('sound', true);
        await say("Sound enabled.", "تم تفعيل الصوت.");
        return;
      case 'sound_off':
        await _applyToggle('sound', false);
        await say("Sound disabled.", "تم تعطيل الصوت.");
        return;

      case 'vibration_on':
        await _applyToggle('vibration', true);
        await say("Vibration enabled.", "تم تفعيل الاهتزاز.");
        return;
      case 'vibration_off':
        await _applyToggle('vibration', false);
        await say("Vibration disabled.", "تم تعطيل الاهتزاز.");
        return;

      case 'voice_on':
        await _applyToggle('voice', true);
        return; // _applyToggle speaks confirmation itself
      case 'voice_off':
        await _applyToggle('voice', false);
        return;

      default:
        await say(
          "Say order confirmation, order preparation, out for delivery, delivered, "
              "offers, push, sound, vibration, voice, enable all, disable all, or go back.",
          "قل تأكيد الطلب، تحضير الطلب، في الطريق، تم التوصيل، "
              "عروض، إشعارات، صوت، اهتزاز، صوت الإعلانات، فعّل الكل، عطّل الكل، أو ارجع.",
        );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp    = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(lp, audio),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVoiceHint(lp, audio),
                  const SizedBox(height: 20),
                  _buildMainToggleCard(lp),
                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.assignment_outlined, lp.getText('order_updates_sec')),
                  _buildSettingsGroup([
                    _buildToggleTile('order_conf',   lp.getText('order_conf_title'),   lp.getText('order_conf_sub'),   Icons.receipt_long_outlined),
                    _buildToggleTile('order_prep',   lp.getText('order_prep_title'),   lp.getText('order_prep_sub'),   Icons.local_mall_outlined),
                    _buildToggleTile('out_delivery', lp.getText('out_delivery_title'), lp.getText('out_delivery_sub'), Icons.delivery_dining_outlined),
                    _buildToggleTile('delivered',    lp.getText('delivered_title'),    lp.getText('delivered_sub'),    Icons.check_circle_outline),
                  ]),
                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.local_offer_outlined, lp.getText('promotions_sec')),
                  _buildSettingsGroup([
                    _buildToggleTile('special_offers', lp.getText('special_offers_title'), lp.getText('special_offers_sub'), Icons.card_giftcard),
                  ]),
                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.notifications_active_outlined, lp.getText('methods_sec')),
                  _buildSettingsGroup([
                    _buildToggleTile('push',      lp.getText('push_title'),      lp.getText('push_sub'),      Icons.notifications_outlined),
                    _buildToggleTile('voice',     lp.getText('voice_ann_title'), lp.getText('voice_ann_sub'), Icons.volume_up_outlined),
                    _buildToggleTile('sound',     lp.getText('sound_title'),     lp.getText('sound_sub'),     Icons.volume_down_outlined),
                    _buildToggleTile('vibration', lp.getText('vibration_title'), lp.getText('vibration_sub'), Icons.vibration_outlined),
                  ]),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(LanguageProvider lp, AppAudioProvider audio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryRed, const Color(0xFF7B1FA2)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  _shouldListen = false;
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    lp.getText('notifications_title'),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              if (!audio.speech.isListening && !_isProcessing) {
                _shouldListen = true;
                _startListening(lp);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: audio.isListening ? Colors.green : Colors.white24,
                  shape: BoxShape.circle),
              child: Icon(
                audio.isListening ? Icons.graphic_eq : Icons.mic,
                color: Colors.white,
                size: 35,
              ),
            ),
          ),
          if (audio.isListening)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                audio.lastWords.isEmpty
                    ? (lp.isEnglish ? "Listening..." : "أنا أسمعك...")
                    : audio.lastWords,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceHint(LanguageProvider lp, AppAudioProvider audio) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1F2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mic_none,
              color: audio.isListening ? Colors.green : const Color(0xFF00796B),
              size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audio.isListening
                      ? (lp.isEnglish ? "Listening..." : "أنا أسمعك...")
                      : lp.getText('voice_cmd_header'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  audio.isListening && audio.lastWords.isNotEmpty
                      ? audio.lastWords
                      : lp.getText('voice_cmd_examples'),
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainToggleCard(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: primaryRed.withOpacity(0.1),
            child: Icon(Icons.notifications_none, color: primaryRed, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lp.getText('all_notifications'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                Text(lp.getText('receiving_updates'),
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          Switch(
            value: _settings['all']!,
            activeColor: primaryRed,
            onChanged: (val) => _applyToggle('all', val),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87)),
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
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(
      String key, String title, String subtitle, IconData icon) {
    final bool masterOn = _settings['all']!;
    final bool isLast   = key == 'vibration' ||
        key == 'delivered' ||
        key == 'special_offers';

    return Column(
      children: [
        ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icon,
              color: masterOn ? Colors.black45 : Colors.grey[300]),
          title: Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: masterOn ? Colors.black : Colors.grey)),
          subtitle: Text(subtitle,
              style: TextStyle(
                  fontSize: 12,
                  color: masterOn ? Colors.grey : Colors.grey[300])),
          trailing: Switch(
            value: _settings[key]!,
            activeColor: primaryRed,
            onChanged: masterOn ? (val) => _applyToggle(key, val) : null,
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 55),
      ],
    );
  }
}