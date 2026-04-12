import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';

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

  final Color primaryRed = const Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF3F2B96).withRed(180), const Color(0xFF2C3E50).withRed(150)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.mic, color: Colors.white, size: 35),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVoiceHint(lp),
                  const SizedBox(height: 20),
                  _buildMainToggleCard(lp),
                  const SizedBox(height: 25),

                  _buildSectionHeader(Icons.assignment_outlined, lp.getText('order_updates_sec')),
                  _buildSettingsGroup([
                    _buildToggleTile('order_conf', lp.getText('order_conf_title'), lp.getText('order_conf_sub'), Icons.error_outline),
                    _buildToggleTile('order_prep', lp.getText('order_prep_title'), lp.getText('order_prep_sub'), Icons.local_mall_outlined),
                    _buildToggleTile('out_delivery', lp.getText('out_delivery_title'), lp.getText('out_delivery_sub'), Icons.delivery_dining_outlined),
                    _buildToggleTile('delivered', lp.getText('delivered_title'), lp.getText('delivered_sub'), Icons.notifications_none_outlined),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.card_giftcard_outlined, lp.getText('promotions_sec')),
                  _buildSettingsGroup([
                    _buildToggleTile('new_rest', lp.getText('new_rest_title'), lp.getText('new_rest_sub'), Icons.storefront_outlined),
                    _buildToggleTile('special_offers', lp.getText('special_offers_title'), lp.getText('special_offers_sub'), Icons.card_giftcard),
                    _buildToggleTile('discounts', lp.getText('discounts_title'), lp.getText('discounts_sub'), Icons.redeem_outlined),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.star_outline, lp.getText('ratings_sec')),
                  _buildSettingsGroup([
                    _buildToggleTile('rate_order', lp.getText('rate_order_title'), lp.getText('rate_order_sub'), Icons.star_border),
                    _buildToggleTile('driver_ratings', lp.getText('driver_ratings_title'), lp.getText('driver_ratings_sub'), Icons.directions_car_outlined),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.notifications_active_outlined, lp.getText('methods_sec')),
                  _buildSettingsGroup([
                    _buildToggleTile('voice', lp.getText('voice_ann_title'), lp.getText('voice_ann_sub'), Icons.volume_up_outlined),
                    _buildToggleTile('sound', lp.getText('sound_title'), lp.getText('sound_sub'), Icons.volume_down_outlined),
                    _buildToggleTile('vibration', lp.getText('vibration_title'), lp.getText('vibration_sub'), Icons.vibration_outlined),
                    _buildToggleTile('push', lp.getText('push_title'), lp.getText('push_sub'), Icons.chat_bubble_outline),
                    _buildToggleTile('sms', lp.getText('sms_title'), lp.getText('sms_sub'), Icons.chat_outlined),
                    _buildToggleTile('email', lp.getText('email_title'), lp.getText('email_sub'), Icons.mail_outline),
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

  Widget _buildVoiceHint(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1F2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mic_none, color: Color(0xFF00796B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lp.getText('voice_cmd_header'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  lp.getText('voice_cmd_examples'),
                  style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFE0F2F1),
            child: Icon(Icons.notifications_none, color: primaryRed, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lp.getText('all_notifications'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(lp.getText('receiving_updates'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          Switch(
            value: _settings['all']!,
            onChanged: (val) => setState(() => _settings['all'] = val),
            activeThumbColor: primaryRed,
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(String key, String title, String subtitle, IconData icon) {
    bool isMasterOn = _settings['all']!;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icon, color: isMasterOn ? Colors.black45 : Colors.grey[300]),
          title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isMasterOn ? Colors.black : Colors.grey)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isMasterOn ? Colors.grey : Colors.grey[300])),
          trailing: Switch(
            value: _settings[key]!,
            onChanged: isMasterOn
                ? (val) => setState(() => _settings[key] = val)
                : null,
            activeThumbColor: primaryRed,
          ),
        ),
        if (key != 'delivered' && key != 'discounts' && key != 'driver_ratings' && key != 'email')
          const Divider(height: 1, indent: 55),
      ],
    );
  }
}