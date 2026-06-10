import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/AddressModel.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/services/ai_service.dart';
import 'package:provider/provider.dart';

// Voice collection steps
enum _VoiceStep { idle, awaitingLabel, awaitingAddress, awaitingConfirm }

class DeliveryAddressesPage extends StatefulWidget {
  const DeliveryAddressesPage({super.key});

  @override
  State<DeliveryAddressesPage> createState() => _DeliveryAddressesPageState();
}

class _DeliveryAddressesPageState extends State<DeliveryAddressesPage> {
  late LanguageProvider lp;

  bool _shouldListen = true;
  bool _isProcessing = false;

  // Voice add-address state machine
  _VoiceStep _voiceStep = _VoiceStep.idle;
  String _pendingLabel   = '';
  String _pendingAddress = '';
  String _pendingIconType = 'home';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    lp = Provider.of<LanguageProvider>(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceScreen());
  }

  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }

  // ─────────────────────────────────────────
  // ANNOUNCE SCREEN
  // ─────────────────────────────────────────
  Future<void> _announceScreen() async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();

    await audio.speak(
      lp.isEnglish
          ? "Delivery addresses. Say add address to add a new one, or go back to return."
          : "عناوين التوصيل. قل أضف عنوان لإضافة عنوان جديد، أو ارجع للعودة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    _shouldListen = true;
    _startListening();
  }

  // ─────────────────────────────────────────
  // LISTEN LOOP
  // ─────────────────────────────────────────
  void _startListening() async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.currentLanguage,
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;
        debugPrint("USER SAID (Addresses): $text | step: $_voiceStep");

        await _handleVoiceInput(text);

        _isProcessing = false;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) _startListening();
        });
      },
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  // ─────────────────────────────────────────
  // VOICE INPUT ROUTER
  // ─────────────────────────────────────────
  Future<void> _handleVoiceInput(String text) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // ── Steps that don't need Rasa (raw speech capture) ──────
    if (_voiceStep == _VoiceStep.awaitingAddress) {
      await _handleAwaitingAddress(text, audio);
      return;
    }

    if (_voiceStep == _VoiceStep.awaitingConfirm) {
      await _handleAwaitingConfirm(text, audio);
      return;
    }

    // ── Route through Rasa for everything else ────────────────
    final aiResponse = await AIService.sendMessage(text);
    final command   = (aiResponse["command"] ?? "unknown").toString();
    final value     = (aiResponse["value"]   ?? "").toString().trim();
    final iconType  = (aiResponse["icon_type"] ?? "other").toString();
    debugPrint("RASA COMMAND (Addresses): $command | $value");

    switch (command) {

    // ── Main screen: add address ─────────────────────────────
      case "add_new_address":
        await _startVoiceAddFlow(audio);
        break;

    // ── Label collected ──────────────────────────────────────
      case "address_label":
        _pendingLabel    = value;
        _pendingIconType = iconType;
        setState(() => _voiceStep = _VoiceStep.awaitingAddress);
        await audio.speak(
          lp.isEnglish
              ? "Label set to $value. Now say your full address."
              : "تم تعيين التسمية إلى $value. الآن قل عنوانك الكامل.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

    // ── Go back ──────────────────────────────────────────────
      case "go_back":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Going back." : "جاري الرجوع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await audio.stop();
        if (mounted) Navigator.pop(context);
        break;

    // ── Awaiting label step ──────────────────────────────────
      default:
        if (_voiceStep == _VoiceStep.awaitingLabel) {
          // Treat whatever was said as the label
          await _handleRawLabel(text, audio);
        } else {
          await audio.speak(
            lp.isEnglish
                ? "Say add address to add a new one, or go back."
                : "قل أضف عنوان لإضافة عنوان جديد، أو ارجع للعودة.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
    }
  }

  // ─────────────────────────────────────────
  // STEP HELPERS
  // ─────────────────────────────────────────
  Future<void> _startVoiceAddFlow(AppAudioProvider audio) async {
    setState(() {
      _voiceStep      = _VoiceStep.awaitingLabel;
      _pendingLabel   = '';
      _pendingAddress = '';
      _pendingIconType = 'home';
    });
    await audio.speak(
      lp.isEnglish
          ? "Say a label for this address: home, work, or other."
          : "قل تسمية لهذا العنوان: منزل، عمل، أو أخرى.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  Future<void> _handleRawLabel(String text, AppAudioProvider audio) async {
    final lower = text.toLowerCase();
    if (lower.contains("home") || lower.contains("بيت") || lower.contains("منزل")) {
      _pendingIconType = "home";
      _pendingLabel    = lp.isEnglish ? "Home" : "المنزل";
    } else if (lower.contains("work") || lower.contains("office") ||
        lower.contains("عمل") || lower.contains("مكتب")) {
      _pendingIconType = "work";
      _pendingLabel    = lp.isEnglish ? "Work" : "العمل";
    } else {
      _pendingIconType = "other";
      _pendingLabel    = text.trim();
    }

    setState(() => _voiceStep = _VoiceStep.awaitingAddress);
    await audio.speak(
      lp.isEnglish
          ? "Label set to $_pendingLabel. Now say your full address."
          : "تم تعيين التسمية إلى $_pendingLabel. الآن قل عنوانك الكامل.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  Future<void> _handleAwaitingAddress(String text, AppAudioProvider audio) async {
    final lower = text.toLowerCase();

    // Allow cancel mid-flow
    if (lower.contains("cancel") || lower.contains("إلغاء") || lower.contains("الغاء")) {
      setState(() => _voiceStep = _VoiceStep.idle);
      await audio.speak(
        lp.isEnglish ? "Cancelled." : "تم الإلغاء.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      return;
    }

    // Strip common address prefixes
    String address = text.trim();
    for (final prefix in [
      RegExp(r'^my address is\s+', caseSensitive: false),
      RegExp(r'^address is\s+',    caseSensitive: false),
      RegExp(r'^عنواني\s+'),
      RegExp(r'^العنوان\s+'),
    ]) {
      address = address.replaceFirst(prefix, '').trim();
    }

    _pendingAddress = address;
    setState(() => _voiceStep = _VoiceStep.awaitingConfirm);

    await audio.speak(
      lp.isEnglish
          ? "Address: $_pendingAddress. Label: $_pendingLabel. Say save to confirm or cancel."
          : "العنوان: $_pendingAddress. التسمية: $_pendingLabel. قل احفظ للتأكيد أو إلغاء.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  Future<void> _handleAwaitingConfirm(String text, AppAudioProvider audio) async {
    final lower = text.toLowerCase();

    final isSave = lower.contains("save")    || lower.contains("confirm") ||
        lower.contains("yes")     || lower.contains("احفظ")    ||
        lower.contains("تأكيد")   || lower.contains("نعم")     ||
        lower.contains("ok")      || lower.contains("تمام");

    final isCancel = lower.contains("cancel") || lower.contains("no") ||
        lower.contains("إلغاء")  || lower.contains("لا");

    if (isSave) {
      await _saveVoiceAddress(audio);
    } else if (isCancel) {
      setState(() => _voiceStep = _VoiceStep.idle);
      await audio.speak(
        lp.isEnglish ? "Cancelled." : "تم الإلغاء.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    } else {
      await audio.speak(
        lp.isEnglish
            ? "Say save to confirm or cancel."
            : "قل احفظ للتأكيد أو إلغاء.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    }
  }

  Future<void> _saveVoiceAddress(AppAudioProvider audio) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final addressData = AddressModel(
      id: '',
      label: _pendingLabel,
      address: _pendingAddress,
      iconType: _pendingIconType,
    );

    await DatabaseService().addAddress(userId, addressData);
    setState(() => _voiceStep = _VoiceStep.idle);

    await audio.speak(
      lp.isEnglish
          ? "Address saved successfully."
          : "تم حفظ العنوان بنجاح.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final audio   = Provider.of<AppAudioProvider>(context);
    final userId  = FirebaseAuth.instance.currentUser?.uid;
    const primaryRed = Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(lp.getText('address'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // ── Voice hint banner ──────────────────────────────────────
      bottomNavigationBar: _buildVoiceHint(audio),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAddressDialog(context),
        backgroundColor: primaryRed,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<AddressModel>>(
        stream: DatabaseService().getAddresses(userId!),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text(lp.getText('error_something_wrong')));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty)
            return Center(child: Text(lp.getText('no_addresses')));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            itemBuilder: (context, index) =>
                _buildAddressCard(addresses[index], primaryRed, userId),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  // VOICE HINT WIDGET
  // ─────────────────────────────────────────
  Widget _buildVoiceHint(AppAudioProvider audio) {
    // Show context-sensitive hint based on current voice step
    String hint;
    if (_voiceStep == _VoiceStep.awaitingLabel) {
      hint = lp.isEnglish
          ? "🎤 Say: home, work, or other"
          : "🎤 قل: منزل، عمل، أو أخرى";
    } else if (_voiceStep == _VoiceStep.awaitingAddress) {
      hint = lp.isEnglish
          ? "🎤 Say your full address now"
          : "🎤 قل عنوانك الكامل الآن";
    } else if (_voiceStep == _VoiceStep.awaitingConfirm) {
      hint = lp.isEnglish
          ? "🎤 Say: save  or  cancel"
          : "🎤 قل: احفظ  أو  إلغاء";
    } else {
      hint = audio.isListening && audio.lastWords.isNotEmpty
          ? audio.lastWords
          : (lp.isEnglish
          ? "🎤 Say: add address  or  go back"
          : "🎤 قل: أضف عنوان  أو  ارجع");
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: audio.isListening
            ? const Color(0xFFD6EED6)
            : const Color(0xFFD6E0E0),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(Icons.mic,
              color: audio.isListening ? Colors.green : Colors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(hint,
                style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // EXISTING UI METHODS (unchanged)
  // ─────────────────────────────────────────
  Widget _buildAddressCard(AddressModel item, Color accent, String userId) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
            color: item.isDefault ? accent : Colors.grey[200]!,
            width: item.isDefault ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: accent.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(item.icon, color: accent, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(item.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          if (item.isDefault)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(lp.getText('default_tag'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(item.address,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      _showAddAddressDialog(context, existingAddress: item),
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.blueGrey),
                  label: Text(lp.getText('edit'),
                      style: const TextStyle(color: Colors.blueGrey)),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () =>
                      DatabaseService().deleteAddress(userId, item.id),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: Text(lp.getText('delete'),
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showAddAddressDialog(BuildContext context,
      {AddressModel? existingAddress}) {
    final labelController   = TextEditingController(
        text: existingAddress?.label ?? '');
    final addressController = TextEditingController(
        text: existingAddress?.address ?? '');
    String selectedIconType =
        existingAddress?.iconType ?? 'home';
    final userId    = FirebaseAuth.instance.currentUser?.uid;
    bool isEditing  = existingAddress != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing
              ? lp.getText('edit_address')
              : lp.getText('add_new_address')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(lp.getText('label'),
                    lp.getText('label_hint'), labelController),
                const SizedBox(height: 15),
                _buildDialogField(lp.getText('address_field'),
                    lp.getText('address_hint'), addressController,
                    maxLines: 2),
                const SizedBox(height: 20),
                Text(lp.getText('select_icon'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIconChoice(Icons.home_outlined, 'home',
                        selectedIconType, lp.getText('home_label'),
                            (t) => setDialogState(() => selectedIconType = t)),
                    _buildIconChoice(Icons.work_outline, 'work',
                        selectedIconType, lp.getText('work_label'),
                            (t) => setDialogState(() => selectedIconType = t)),
                    _buildIconChoice(Icons.location_on_outlined, 'other',
                        selectedIconType, lp.getText('other_label'),
                            (t) => setDialogState(() => selectedIconType = t)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(lp.getText('cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F)),
              onPressed: () async {
                if (labelController.text.isNotEmpty &&
                    addressController.text.isNotEmpty) {
                  final data = AddressModel(
                    id: isEditing ? existingAddress.id : '',
                    label: labelController.text,
                    address: addressController.text,
                    iconType: selectedIconType,
                  );
                  if (isEditing) {
                    await DatabaseService().updateAddress(userId!, data);
                  } else {
                    await DatabaseService().addAddress(userId!, data);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isEditing
                          ? lp.getText('update_address')
                          : lp.getText('save_address'))));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(lp.getText('error_fill_fields'))));
                }
              },
              child: Text(
                isEditing
                    ? lp.getText('update_address')
                    : lp.getText('save_address'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, String hint,
      TextEditingController controller,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildIconChoice(IconData icon, String type, String current,
      String label, Function(String) onSelect) {
    bool isSelected = type == current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onSelect(type),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD32F2F).withOpacity(0.1)
                  : Colors.transparent,
              border: Border.all(
                  color: isSelected
                      ? const Color(0xFFD32F2F)
                      : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: isSelected ? const Color(0xFFD32F2F) : Colors.grey),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFFD32F2F) : Colors.grey)),
      ],
    );
  }
}