import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, DocumentSnapshot, FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
//Done
class VoiceSettingsPage extends StatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  // Make sure this name matches the class below!
  State<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

// Ensure "Page" is included in the name here too
class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  // ... rest of your variables and build method

  // State variables
  bool _voiceCommands = true;
  bool _voiceFeedback = true;
  bool _wakeWord = true;
  bool _autoListen = false;
  bool _voiceConfirmation = true;
  double _volume = 80;
  String _selectedSpeed = "1.0x Normal";
  String _selectedLanguage = "English (US)";

  final Color primaryRed = const Color(0xFFD32F2F);
// When a user changes a setting
Future<void> _saveToCloud() async {
  try {
    // Get the current user
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String uid = user.uid;

      // Call the database service
  await DatabaseService().updateVoiceSettings(uid, {
  'speed': _selectedSpeed,
  'volume': _volume,
  'language': _selectedLanguage,
  'wakeWord': _wakeWord,
  'voiceFeedback': _voiceFeedback,
  'voiceCommands': _voiceCommands, // Added
  'autoListen': _autoListen,       // Added
  'voiceConfirmation': _voiceConfirmation, // Added
  'lastUpdated': FieldValue.serverTimestamp(),
});
      print("Settings synced to cloud successfully.");
    }
  } catch (e) {
    print("Error saving settings: $e");
    // Optional: Show a small snackbar if the save fails
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to sync settings to cloud"))
      );
    }
  }
}








@override
void dispose() {
  _saveToCloud(); // Saves the final state when user leaves the page
  super.dispose();
}
@override
void initState() {
  super.initState();
  _loadSettingsFromServer();
}

Future<void> _loadSettingsFromServer() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists && userDoc.data() != null) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      
      // Look for our nested voiceSettings map
      if (data.containsKey('voiceSettings')) {
        Map<String, dynamic> settings = data['voiceSettings'];
        
        setState(() {
          _selectedSpeed = settings['speed'] ?? "1.0x Normal";
          _volume = (settings['volume'] ?? 80.0).toDouble();
          _selectedLanguage = settings['language'] ?? "English (US)";
          _wakeWord = settings['wakeWord'] ?? true;
          _voiceFeedback = settings['voiceFeedback'] ?? true;
          // Add any other variables you're tracking here
        });
      }
    }
  }
}
// --- THE BUILD METHOD (Usage) ---
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    body: SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVoiceHint(),
                const SizedBox(height: 20),
                _buildMainVoiceToggle(),
                const SizedBox(height: 25),

                // THIS IS WHERE YOU CALL THE HELPERS
                _buildSectionHeader(Icons.settings_voice, 'Voice Features'),
                _buildSettingsGroup([
                  _buildToggleTile(
                    "Voice Feedback", 
                    "Hear confirmations for actions", 
                    _voiceFeedback, 
                    (v) {
                      setState(() => _voiceFeedback = v);
                      _saveToCloud();
                    }, 
                    Icons.volume_up_outlined
                  ),
                  _buildToggleTile(
                    "Wake Word Detection", 
                    "Say \"Hey Say-Serve\" to activate", 
                    _wakeWord, 
                    (v) {
                      setState(() => _wakeWord = v);
                      _saveToCloud();
                    }, 
                    Icons.bolt
                  ),
                  _buildToggleTile(
                    "Auto-Listen", 
                    "Always ready for commands", 
                    _autoListen, 
                    (v) {
                      setState(() => _autoListen = v);
                      _saveToCloud();
                    }, 
                    Icons.mic_none
                  ),
                  _buildToggleTile(
                    "Voice Confirmations", 
                    "Confirm orders before placing", 
                    _voiceConfirmation, 
                    (v) {
                      setState(() => _voiceConfirmation = v);
                      _saveToCloud();
                    }, 
                    Icons.info_outline
                  ),
                ]),

                const SizedBox(height: 25),
                _buildSectionHeader(Icons.speed, 'Speech Speed'),
                _buildSpeedSelector(),

                const SizedBox(height: 25),
                _buildSectionHeader(Icons.volume_up, 'Voice Volume'),
                _buildVolumeSlider(),

                const SizedBox(height: 25),
                _buildSectionHeader(Icons.translate, 'Voice Language'),
                _buildLanguageSelector(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// --- THE HELPER METHOD (Definition) ---
// Keep this simple!
Widget _buildSettingsGroup(List<Widget> children) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white, 
      borderRadius: BorderRadius.circular(15)
    ),
    child: Column(children: children),
  );
}
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFB71C1C), primaryRed],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const Text('Voice Settings', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () {}),
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
    );
  }

  Widget _buildVoiceHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(15)),
      child: const Row(
        children: [
          Icon(Icons.mic_none, color: Color(0xFFD32F2F), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Try: "Enable voice feedback", "Set speed to fast", "Turn off wake word"',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVoiceToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.red[50], child: Icon(Icons.mic, color: primaryRed)),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Voice Commands', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              Text('Active and listening', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ]),
          ),
          Switch(value: _voiceCommands,
          onChanged: (v) {
            setState(() => _voiceCommands = v);
            _saveToCloud(); // <--- Add this
          }
          , activeThumbColor: primaryRed),
        ],
      ),
    );
  }

  Widget _buildSpeedSelector() {
    List<String> speeds = ["0.5x Slow", "0.75x", "1.0x Normal", "1.25x", "1.5x Fast", "2.0x"];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Wrap(
            spacing: 10, runSpacing: 10,
            children: speeds.map((s) => ChoiceChip(
              label: Text(s),
              selected: _selectedSpeed == s,
              onSelected: (selected) {
  if (selected) {
    setState(() => _selectedSpeed = s);
    _saveToCloud(); // <--- Add this
  }
},
              selectedColor: primaryRed,
              labelStyle: TextStyle(color: _selectedSpeed == s ? Colors.white : Colors.black),
            )).toList(),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: Text("Current: $_selectedSpeed", textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          )
        ],
      ),
    );
  }

  Widget _buildVolumeSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Slider(
            value: _volume, min: 0, max: 100,
            activeColor: primaryRed, inactiveColor: Colors.red[100],
            onChanged: (v) => setState(() => _volume = v),
            onChangeEnd: (v) => _saveToCloud(),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Silent", style: TextStyle(color: Colors.grey)),
            Text("${_volume.round()}%", style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
            const Text("Loud", style: TextStyle(color: Colors.grey)),
          ])
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    List<String> langs = ["English (US)",  "Arabic (EG)"];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: langs.map((l) => RadioListTile(
          title: Text(l),
          value: l,
          groupValue: _selectedLanguage,
          activeColor: primaryRed,
          onChanged: (v) {
  setState(() => _selectedLanguage = v.toString());
  _saveToCloud(); // <--- Add this
},
        )).toList(),
      ),
    );
  }

  // Reuse helper widgets from previous screens...
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


// This is just a "template" for a single row
Widget _buildToggleTile(String title, String sub, bool val, Function(bool) onChanged, IconData icon) {
  return ListTile(
    leading: Icon(icon, color: Colors.black45),
    title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    trailing: Switch(
      value: val, 
      onChanged: _voiceCommands ? onChanged : null, // Disables if main voice is off
      activeThumbColor: primaryRed
    ),
  );
}

}