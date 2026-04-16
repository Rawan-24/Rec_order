import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
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

  String _getInitials(String name) {
    if (name.isEmpty) return "??";
    List<String> names = name.trim().split(" ");
    if (names.length > 1) {
      return "${names[0][0]}${names[1][0]}".toUpperCase();
    }
    return names[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    const primaryRed = Color(0xFFD32F2F);
    const backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryRed));
          }

          var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          String displayName = userData['name'] ?? lp.getText('user_name_placeholder');
          String displayPhone = userData['phone'] ?? lp.getText('no_phone_placeholder');

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
                  decoration: const BoxDecoration(gradient: backgroundGradient),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const HomePage()),
                              (route) => false,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                lp.getText('profile_title'),
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        child: Text(
                          _getInitials(displayName),
                          style: const TextStyle(fontSize: 28, color: primaryRed, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(displayPhone, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 25),
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
                      _buildVoiceBar(primaryRed, lp),
                      const SizedBox(height: 30),
                      _buildSectionTitle(lp.getText('recent_orders'), lp, onAction: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryPage()));
                      }),
                      const SizedBox(height: 10),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('orders')
                            .where('userId', isEqualTo: user?.uid)
                            .orderBy('timestamp', descending: true)
                            .limit(2)
                            .snapshots(),
                        builder: (context, orderSnapshot) {
                          if (!orderSnapshot.hasData || orderSnapshot.data!.docs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(lp.getText('no_recent_orders'), style: const TextStyle(color: Colors.grey)),
                            );
                          }
                          return Column(
                            children: orderSnapshot.data!.docs.map((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              int itemCount = data['items']?.length ?? 0;
                              return _buildOrderCard(
                                data['restaurantName'] ?? lp.getText('restaurant_placeholder'),
                                "$itemCount ${lp.getText('items_label')}",
                                "SAR ${(data['totalPrice'] ?? 0.0).toStringAsFixed(2)}",
                                primaryRed,
                                lp,
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 30),
                      _buildSectionTitle(lp.getText('section_account'), lp),
                      _buildSettingsGroup([
                        _buildSettingsTile(Icons.person_outline, lp.getText('personal_info_tile'), onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonalInformationPage()));
                        }),
                        _buildSettingsTile(Icons.location_on_outlined, lp.getText('delivery_addresses_tile'), onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const DeliveryAddressesPage()));
                        }),
                        _buildSettingsTile(Icons.payment_outlined, lp.getText('payment_methods_tile'), onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentMethodsPage()));
                        }),
                      ]),

                      const SizedBox(height: 25),
                      _buildSectionTitle(lp.getText('section_preferences'), lp),
                      _buildSettingsGroup([
                        _buildSettingsTile(Icons.notifications_none, lp.getText('notifications_tile'), onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage()));
                        }),
                        _buildSettingsTile(Icons.language_rounded, lp.getText('language_tile'), onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageSelectionScreen()));
                        }),
                        _buildSettingsTile(Icons.settings_voice_outlined, lp.getText('voice_settings_tile'), onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceSettingsPage()));
                        }),
                      ]),

                      const SizedBox(height: 25),
                      _buildSectionTitle(lp.getText('section_activity'), lp),
                      _buildSettingsGroup([
                        _buildSettingsTile(Icons.history, lp.getText('order_history_tile'), onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryPage()));
                        }),
                        _buildSettingsTile(Icons.favorite_border, lp.getText('favorites_tile'), onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesPage()));
                        }),
                      ]),

                      const SizedBox(height: 40),
                      _buildLogoutButton(context, primaryRed, lp),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoiceBar(Color primaryRed, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryRed.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_none, color: primaryRed, size: 20),
          const SizedBox(width: 10),
          Text(lp.getText('profile_voice_hint'), style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, LanguageProvider lp, {VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (onAction != null)
          TextButton(onPressed: onAction, child: Text(lp.getText('view_all'), style: const TextStyle(color: Color(0xFFD32F2F)))),
      ],
    );
  }

  Widget _buildOrderCard(String name, String details, String price, Color accent, LanguageProvider lp) {
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
                  child: Text(lp.getText('status_delivered'), style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const Divider(height: 24),
            InkWell(
              onTap: () {}, 
              child: Row(
                children: [
                  Text(lp.getText('reorder_button'), style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right, color: accent, size: 18),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

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

  Widget _buildSettingsTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context, Color primaryRed, LanguageProvider lp) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SignInScreen()),
            (route) => false,
          );
        },
        icon: const Icon(Icons.logout),
        label: Text(lp.getText('logout_button'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}