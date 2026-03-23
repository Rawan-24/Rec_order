import 'package:flutter/material.dart';

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
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Notifications',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                  // Voice Commands Hint
                  _buildVoiceHint(),
                  const SizedBox(height: 20),

                  // All Notifications Card
                  _buildMainToggleCard(),
                  const SizedBox(height: 25),

                  // Grouped Settings
                  _buildSectionHeader(Icons.assignment_outlined, 'Order Updates'),
                  _buildSettingsGroup([
                    _buildToggleTile('order_conf', 'Order Confirmation', 'When order is placed', Icons.error_outline),
                    _buildToggleTile('order_prep', 'Order Preparing', 'Restaurant is preparing', Icons.local_mall_outlined),
                    _buildToggleTile('out_delivery', 'Out for Delivery', 'Driver is on the way', Icons.delivery_dining_outlined),
                    _buildToggleTile('delivered', 'Order Delivered', 'Order has arrived', Icons.notifications_none_outlined),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.card_giftcard_outlined, 'Promotions & Offers'),
                  _buildSettingsGroup([
                    _buildToggleTile('new_rest', 'New Restaurants', 'New places near you', Icons.storefront_outlined),
                    _buildToggleTile('special_offers', 'Special Offers', 'Exclusive deals for you', Icons.card_giftcard),
                    _buildToggleTile('discounts', 'Discounts & Coupons', 'Save money on orders', Icons.redeem_outlined),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.star_outline, 'Ratings & Reviews'),
                  _buildSettingsGroup([
                    _buildToggleTile('rate_order', 'Rate Your Order', 'Reminder to rate food', Icons.star_border),
                    _buildToggleTile('driver_ratings', 'Driver Ratings', 'Reminder to rate driver', Icons.directions_car_outlined),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.notifications_active_outlined, 'Notification Methods'),
                  _buildSettingsGroup([
                    _buildToggleTile('voice', 'Voice Announcements', 'Hear updates spoken aloud', Icons.volume_up_outlined),
                    _buildToggleTile('sound', 'Sound', 'Play notification sounds', Icons.volume_down_outlined),
                    _buildToggleTile('vibration', 'Vibration', 'Phone vibrates on alerts', Icons.vibration_outlined),
                    _buildToggleTile('push', 'Push Notifications', 'App notifications', Icons.chat_bubble_outline),
                    _buildToggleTile('sms', 'SMS Notifications', 'Text message updates', Icons.chat_outlined),
                    _buildToggleTile('email', 'Email Notifications', 'Updates via email', Icons.mail_outline),
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

  Widget _buildVoiceHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1F2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mic_none, color: Color(0xFF00796B), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Voice Commands:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                SizedBox(height: 4),
                Text(
                  '"Turn on order updates", "Disable promotions", "Mute all notifications"',
                  style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainToggleCard() {
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Receiving updates', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          Switch(
            value: _settings['all']!,
            onChanged: (val) => setState(() => _settings['all'] = val),
            activeColor: primaryRed,
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
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icon, color: Colors.black45),
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: Switch(
            value: _settings[key]!,
            onChanged: _settings['all']!
                ? (val) => setState(() => _settings[key] = val)
                : null, // Disable individual switches if "All" is off
            activeColor: primaryRed,
          ),
        ),
        if (key != 'delivered' && key != 'discounts' && key != 'driver_ratings' && key != 'email')
          const Divider(height: 1, indent: 55),
      ],
    );
  }
}