import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Added
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

class ProfilePage extends StatefulWidget { // Changed to StatefulWidget for Audio init
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceProfile();
    });
  }

  void _announceProfile() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();
    String msg = lp.isRTL
        ? "مرحباً بك في ملفك الشخصي. يمكنك استعراض طلباتك الأخيرة أو تعديل إعدادات الصوت."
        : "Welcome to your profile. You can view recent orders or manage voice settings.";
    audio.speak(msg, lp.currentLanguage);
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return "??";
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
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryRed));
          }

          var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          String displayName = userData['name'] ?? "User Name";
          String displayPhone = userData['phone'] ?? "No phone added";

          return CustomScrollView(
            slivers: [
              // Stylish Modern Header
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: primaryRed,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [primaryRed, primaryRed.withOpacity(0.8)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.white,
                          child: Text(_getInitials(displayName),
                              style: TextStyle(fontSize: 28, color: primaryRed, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(displayPhone, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 15),
                        // Voice Pulse Indicator
                        GestureDetector(
                          onTap: () => audio.toggleListening(lp.currentLanguage, (words) {}),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: audio.isListening ? Colors.green : Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVoiceHint(lp, audio),
                      const SizedBox(height: 25),

                      _buildSectionTitle(lp.getText('recent_orders'), lp, onAction: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryPage()));
                      }),
                      const SizedBox(height: 12),

                      _buildRecentOrdersStream(user, lp),

                      const SizedBox(height: 30),
                      _buildSectionLabel(lp.getText('section_account')),
                      _buildSettingsGroup([
                        _buildSettingsTile(Icons.person_outline, lp.getText('personal_info_tile'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonalInformationPage()));
                        }),
                        _buildSettingsTile(Icons.map_outlined, lp.getText('delivery_addresses_tile'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const DeliveryAddressesPage()));
                        }),
                        _buildSettingsTile(Icons.credit_card_outlined, lp.getText('payment_methods_tile'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentMethodsPage()));
                        }),
                      ]),

                      const SizedBox(height: 25),
                      _buildSectionLabel(lp.getText('section_preferences')),
                      _buildSettingsGroup([
                        _buildSettingsTile(Icons.notifications_none_rounded, lp.getText('notifications_tile'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage()));
                        }),
                        _buildSettingsTile(Icons.translate_rounded, lp.getText('language_tile'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageSelectionScreen()));
                        }),
                        _buildSettingsTile(Icons.record_voice_over_outlined, lp.getText('voice_settings_tile'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceSettingsPage()));
                        }),
                      ]),

                      const SizedBox(height: 40),
                      _buildLogoutButton(context, lp),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoiceHint(LanguageProvider lp, AppAudioProvider audio) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: audio.isListening ? Colors.green : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_outlined, color: primaryRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lp.isRTL ? "جرب قول: 'افتح العناوين' أو 'سجل الخروج'" : "Try: 'Open addresses' or 'Logout'",
              style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildRecentOrdersStream(User? user, LanguageProvider lp) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .limit(1) // Showing only the most recent for a cleaner look
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Text(lp.getText('no_recent_orders'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          );
        }
        var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        return _buildOrderCard(
          data['restaurantName'] ?? "Restaurant",
          "${data['items']?.length ?? 0} items",
          "${(data['total'] ?? 0.0).toStringAsFixed(2)} EGP",
          lp,
        );
      },
    );
  }

  Widget _buildOrderCard(String name, String details, String price, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(price, style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(details, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(lp.getText('status_delivered'), style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(children: tiles),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black12, size: 14),
      onTap: onTap,
    );
  }

  Widget _buildSectionTitle(String title, LanguageProvider lp, {VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (onAction != null)
          TextButton(onPressed: onAction, child: Text(lp.getText('view_all'), style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, LanguageProvider lp) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SignInScreen()), (route) => false);
          }
        },
        icon: const Icon(Icons.logout_rounded),
        label: Text(lp.getText('logout_button'), style: const TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryRed,
          side: BorderSide(color: primaryRed, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}