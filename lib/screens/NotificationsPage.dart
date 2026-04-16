import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // State management for all toggles
  final Map<String, bool> _settings = {
    'all': true,
    'order_conf': true,
    'order_prep': true,
    'out_delivery': true,
    'delivered': true,
    'new_rest': false,
    'special_offers': true,
    'discounts': true,
    'rate_order': true,
    'driver_ratings': false,
    'voice': true,
    'sound': true,
    'vibration': true,
    'push': true,
    'sms': true,
    'email': false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePage();
    });
  }

  void _announcePage() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Ensure previous audio is stopped before announcing new page
    await audio.stop();

    String msg = lp.isRTL
        ? "إعدادات التنبيهات. يمكنك قول 'تفعيل الكل' أو 'إيقاف الرسائل القصيرة'."
        : "Notification settings. You can say 'Enable all' or 'Turn off SMS'.";
    audio.speak(msg, lp.currentLanguage);
  }

  void _handleVoiceCommand(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) {
      String command = words.toLowerCase();

      // Detection for Enable/Disable (Supports English and Egyptian Arabic)
      bool isEnable = !command.contains("off") &&
          !command.contains("stop") &&
          !command.contains("إيقاف") &&
          !command.contains("تعطيل") &&
          !command.contains("قفل");

      setState(() {
        if (command.contains("all") || command.contains("الكل")) {
          _settings['all'] = isEnable;
          audio.speak(lp.isRTL ? "تم تحديث جميع التنبيهات" : "Updated all settings", lp.currentLanguage);
        } else if (command.contains("email") || command.contains("بريد") || command.contains("إيميل")) {
          _settings['email'] = isEnable;
          audio.speak(lp.isRTL ? "تم تحديث تنبيهات البريد" : "Email settings updated", lp.currentLanguage);
        } else if (command.contains("sms") || command.contains("رسائل")) {
          _settings['sms'] = isEnable;
          audio.speak(lp.isRTL ? "تم تحديث الرسائل النصية" : "SMS settings updated", lp.currentLanguage);
        } else if (command.contains("offer") || command.contains("عرض") || command.contains("عروض")) {
          _settings['special_offers'] = isEnable;
          audio.speak(lp.isRTL ? "تم تحديث عروضنا" : "Offers updated", lp.currentLanguage);
        }
      });
    });
  }

  final Color primaryRed = const Color(0xFFEB1B33); // Matched your theme color

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with Microphone
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
                    _buildToggleTile('order_conf', lp.getText('order_conf_title'), lp.getText('order_conf_sub'), Icons.check_circle_outline),
                    _buildToggleTile('order_prep', lp.getText('order_prep_title'), lp.getText('order_prep_sub'), Icons.restaurant),
                    _buildToggleTile('out_delivery', lp.getText('out_delivery_title'), lp.getText('out_delivery_sub'), Icons.delivery_dining),
                    _buildToggleTile('delivered', lp.getText('delivered_title'), lp.getText('delivered_sub'), Icons.home_outlined),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.card_giftcard_outlined, lp.getText('promotions_sec')),
                  _buildSettingsGroup([
                    _buildToggleTile('new_rest', lp.getText('new_rest_title'), lp.getText('new_rest_sub'), Icons.storefront),
                    _buildToggleTile('special_offers', lp.getText('special_offers_title'), lp.getText('special_offers_sub'), Icons.local_offer_outlined),
                    _buildToggleTile('discounts', lp.getText('discounts_title'), lp.getText('discounts_sub'), Icons.percent),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.notifications_active_outlined, lp.getText('methods_sec')),
                  _buildSettingsGroup([
                    _buildToggleTile('voice', lp.getText('voice_ann_title'), lp.getText('voice_ann_sub'), Icons.record_voice_over),
                    _buildToggleTile('sms', lp.getText('sms_title'), lp.getText('sms_sub'), Icons.textsms_outlined),
                    _buildToggleTile('email', lp.getText('email_title'), lp.getText('email_sub'), Icons.alternate_email),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lp, AppAudioProvider audio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      decoration: BoxDecoration(
        color: primaryRed, // Kept solid for brand consistency
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  await audio.stop();
                  if (mounted) Navigator.pop(context);
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    lp.getText('notifications_title'),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _handleVoiceCommand(audio, lp),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: audio.isListening ? Colors.green : Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: audio.isListening ? [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 15, spreadRadius: 5)] : []
              ),
              child: Icon(
                  audio.isListening ? Icons.graphic_eq : Icons.mic,
                  color: Colors.white,
                  size: 40
              ),
            ),
          ),
          if (audio.isListening)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(lp.isRTL ? "أنا أسمعك..." : "I'm listening...", style: const TextStyle(color: Colors.white70)),
            )
        ],
      ),
    );
  }

  Widget _buildVoiceHint(LanguageProvider lp, AppAudioProvider audio) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: primaryRed, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              audio.isListening && audio.lastWords.isNotEmpty
                  ? audio.lastWords
                  : (lp.isRTL ? "جرب قول: 'إيقاف الرسائل'" : "Try: 'Turn off SMS'"),
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainToggleCard(LanguageProvider lp) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.black.withOpacity(0.05))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: primaryRed.withOpacity(0.1),
              child: Icon(Icons.notifications_active, color: primaryRed, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lp.getText('all_notifications'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const Text("Master Switch", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            Switch.adaptive(
              value: _settings['all']!,
              onChanged: (val) => setState(() => _settings['all'] = val),
              activeColor: primaryRed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryRed),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(String key, String title, String subtitle, IconData icon) {
    bool isMasterOn = _settings['all']!;
    bool currentVal = _settings[key]!;

    return SwitchListTile.adaptive(
      secondary: Icon(icon, color: isMasterOn ? (currentVal ? primaryRed : Colors.grey) : Colors.grey[300]),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isMasterOn ? Colors.black : Colors.grey[400])),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isMasterOn ? Colors.grey[600] : Colors.grey[300])),
      value: currentVal,
      activeColor: primaryRed,
      onChanged: isMasterOn ? (val) => setState(() => _settings[key] = val) : null,
    );
  }
}