import 'package:flutter/material.dart';
import 'package:grad_project/screens/personal_information.dart';

import 'Delivery_Address.dart';
import 'Home.dart';
import 'Language_Selection.dart';
import 'NotificationsPage.dart';
import 'PaymentMethodsPage.dart';
import 'Sign_in.dart';
import 'VoiceSettingsPage.dart';
import 'favorites.dart';
import 'history.dart';


class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFD32F2F); // Crimson Red
    const backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
              decoration: const BoxDecoration(
                gradient: backgroundGradient,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const HomePage()),
                                (route) => false, // removes all previous routes
                          );
                        },
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Profile',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer for centering
                    ],
                  ),
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    child: Text('SK', style: TextStyle(fontSize: 28, color: primaryRed, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 15),
                  const Text('Sarah Kim', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('+1 223-334-4455', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 25),
                  // Voice Button
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.mic, color: Colors.white, size: 35),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Voice Suggestion Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryRed.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.mic_none, color: primaryRed, size: 20),
                        SizedBox(width: 10),
                        Text('Say "Show order history"', style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildSectionTitle('Recent Orders', onAction: () {}),
                  const SizedBox(height: 10),
                  _buildOrderCard('Pizza Paradise', '2 items • Feb 27, 2026', '\$55.80', primaryRed),
                  _buildOrderCard('Burger Bros', '3 items • Feb 25, 2026', '\$42.50', primaryRed),

                  const SizedBox(height: 30),
                  _buildSectionTitle('Account'),
                  _buildSettingsGroup([
                    _buildSettingsTile(
                      Icons.person_outline,
                      'Personal Information',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PersonalInformationPage(),
                          ),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      Icons.location_on_outlined,
                      'Delivery Addresses',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DeliveryAddressesPage()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      Icons.payment_outlined,
                      'Payment Methods',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PaymentMethodsPage()),
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 25),
                  _buildSectionTitle('Preferences'),
                  _buildSettingsGroup([
                    _buildSettingsTile(
                      Icons.notifications_none,
                      'Notifications',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationsPage()),
                        );
                      },
                    ),

                    _buildSettingsTile(
                      Icons.language_rounded,
                      'Language',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LanguageSelectionScreen()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                        Icons.settings_voice_outlined,
                        'Voice Settings',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (
                                context) => const VoiceSettingsPage()),
                          );
                        },
                          ),
                    const SizedBox(height: 25),
                    _buildSectionTitle('My Activity'),
                    _buildSettingsGroup([
                      _buildSettingsTile(
                        Icons.history,
                        'Order History',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const OrderHistoryPage()),
                          );
                        },
                      ),
                      _buildSettingsTile(
                        Icons.favorite_border,
                        'Favorite Restaurants',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FavoritesPage()),
                          );
                        },
                      ),
                    ]),


                  ]),

                  const SizedBox(height: 40),
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const SignInScreen()),
                              (route) => false, // removes all previous pages from the stack
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Logout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for section titles
  Widget _buildSectionTitle(String title, {VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (onAction != null)
          TextButton(onPressed: onAction, child: const Text('View All', style: TextStyle(color: Color(0xFFD32F2F)))),
      ],
    );
  }

  // Helper widget for order cards
  Widget _buildOrderCard(String name, String details, String price, Color accent) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(price, style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(details, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                  child: const Text('Delivered', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const Divider(height: 24),
            InkWell(
              onTap: () {},
              child: Row(
                children: [
                  Text('Reorder', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right, color: accent, size: 18),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Helper for grouping settings tiles
  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(children: tiles),
    );
  }

  // Helper for individual setting rows
  Widget _buildSettingsTile(
      IconData icon,
      String title, {
        VoidCallback? onTap,
      }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}