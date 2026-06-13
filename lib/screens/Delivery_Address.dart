import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/AddressModel.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/services/ai_service.dart';
import 'package:provider/provider.dart';

enum _VoiceStep {
  idle,
  awaitingLabel,
  awaitingAddress,
  awaitingConfirm,
  // ✅ New edit steps
  editAwaitingField,    // asking which field: label or address
  editAwaitingLabel,    // waiting for new label value
  editAwaitingAddress,  // waiting for new address value
  editAwaitingConfirm,  // confirm save edit
}

class DeliveryAddressesPage extends StatefulWidget {
  const DeliveryAddressesPage({super.key});

  @override
  State<DeliveryAddressesPage> createState() => _DeliveryAddressesPageState();
}

class _DeliveryAddressesPageState extends State<DeliveryAddressesPage> {
  late LanguageProvider lp;

  bool _shouldListen  = true;
  bool _isProcessing  = false;

  // ── Voice state machine ────────────────────────────────────────────────────
  _VoiceStep _voiceStep    = _VoiceStep.idle;
  String _pendingLabel     = '';
  String _pendingAddress   = '';
  String _pendingIconType  = 'home';
  AddressModel? _editingAddress; // the address being edited
  String _editNewLabel   = '';
  String _editNewAddress = '';
  String _editNewIconType = '';
  // ── Local copy of addresses so voice commands can find by label ───────────
  List<AddressModel> _addresses = [];

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

  // ── Announce ───────────────────────────────────────────────────────────────
  Future<void> _announceScreen() async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();

    await audio.speak(
      lp.isEnglish
          ? "Delivery addresses. Say add address, edit home or work, delete home or work, or go back."
          : "عناوين التوصيل. قل أضف عنوان، عدل المنزل أو العمل، احذف المنزل أو العمل، أو ارجع.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    _shouldListen = true;
    _startListening();
  }

  // ── Listen loop ────────────────────────────────────────────────────────────
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
      },
      onError: (e) => debugPrint("STT error: $e"),
    );
  }
  Future<void> _handleEditAwaitingField(String text, AppAudioProvider audio) async {
    final lower = text.toLowerCase();

    if (lower.contains("label") || lower.contains("تسمية") || lower.contains("اسم")) {
      setState(() => _voiceStep = _VoiceStep.editAwaitingLabel);
      await audio.speak(
        lp.isEnglish
            ? "Say the new label: home, work, or other."
            : "قل التسمية الجديدة: منزل، عمل، أو أخرى.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );

    } else if (lower.contains("address") || lower.contains("عنوان")) {
      setState(() => _voiceStep = _VoiceStep.editAwaitingAddress);
      await audio.speak(
        lp.isEnglish
            ? "Say the new address."
            : "قل العنوان الجديد.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );

    } else if (lower.contains("save") || lower.contains("احفظ") ||
        lower.contains("تمام") || lower.contains("confirm")) {
      await _saveEditedAddress(audio);

    } else if (lower.contains("cancel") || lower.contains("إلغاء") || lower.contains("بطل")) {
      setState(() => _voiceStep = _VoiceStep.idle);
      _editingAddress = null;
      await audio.speak(
        lp.isEnglish ? "Edit cancelled." : "تم إلغاء التعديل.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );

    } else {
      await audio.speak(
        lp.isEnglish
            ? "Say label, address, save, or cancel."
            : "قل تسمية أو عنوان أو احفظ أو إلغاء.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    }
  }

  Future<void> _handleEditAwaitingLabel(String text, AppAudioProvider audio) async {
    final lower = text.toLowerCase();
    if (lower.contains("home") || lower.contains("بيت") || lower.contains("منزل")) {
      _editNewLabel    = lp.isEnglish ? "Home" : "المنزل";
      _editNewIconType = "home";
    } else if (lower.contains("work") || lower.contains("عمل") || lower.contains("مكتب")) {
      _editNewLabel    = lp.isEnglish ? "Work" : "العمل";
      _editNewIconType = "work";
    } else {
      _editNewLabel    = text.trim();
      _editNewIconType = "other";
    }
    setState(() => _voiceStep = _VoiceStep.editAwaitingField);
    await audio.speak(
      lp.isEnglish
          ? "Label updated to $_editNewLabel. Say address to change the address, or save to confirm."
          : "تم تحديث التسمية إلى $_editNewLabel. قل عنوان لتغيير العنوان أو احفظ للتأكيد.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  Future<void> _handleEditAwaitingAddress(String text, AppAudioProvider audio) async {
    _editNewAddress = text.trim();
    setState(() => _voiceStep = _VoiceStep.editAwaitingField);
    await audio.speak(
      lp.isEnglish
          ? "Address updated to $_editNewAddress. Say label to change the label, or save to confirm."
          : "تم تحديث العنوان إلى $_editNewAddress. قل تسمية لتغيير التسمية أو احفظ للتأكيد.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  Future<void> _handleEditAwaitingConfirm(String text, AppAudioProvider audio) async {
    final lower = text.toLowerCase();
    if (lower.contains("save") || lower.contains("احفظ") ||
        lower.contains("confirm") || lower.contains("تأكيد") ||
        lower.contains("نعم") || lower.contains("تمام")) {
      await _saveEditedAddress(audio);
    } else if (lower.contains("cancel") || lower.contains("إلغاء") || lower.contains("بطل")) {
      setState(() => _voiceStep = _VoiceStep.idle);
      _editingAddress = null;
      await audio.speak(
        lp.isEnglish ? "Edit cancelled." : "تم إلغاء التعديل.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
    }
  }

  Future<void> _saveEditedAddress(AppAudioProvider audio) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _editingAddress == null) return;

    await DatabaseService().updateAddress(userId, AddressModel(
      id:       _editingAddress!.id,
      label:    _editNewLabel,
      address:  _editNewAddress,
      iconType: _editNewIconType,
    ));

    setState(() {
      _voiceStep      = _VoiceStep.idle;
      _editingAddress = null;
    });

    await audio.speak(
      lp.isEnglish ? "Address updated successfully." : "تم تحديث العنوان بنجاح.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }
  // ── Voice router ───────────────────────────────────────────────────────────
  Future<void> _handleVoiceInput(String text) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Raw capture steps — no AI needed
    if (_voiceStep == _VoiceStep.awaitingAddress) {
      await _handleAwaitingAddress(text, audio);
      return;
    }
    if (_voiceStep == _VoiceStep.awaitingConfirm) {
      await _handleAwaitingConfirm(text, audio);
      return;
    }
// ✅ Handle edit steps without AI — raw speech capture
    if (_voiceStep == _VoiceStep.editAwaitingField) {
      await _handleEditAwaitingField(text, audio);
      return;
    }
    if (_voiceStep == _VoiceStep.editAwaitingLabel) {
      await _handleEditAwaitingLabel(text, audio);
      return;
    }
    if (_voiceStep == _VoiceStep.editAwaitingAddress) {
      await _handleEditAwaitingAddress(text, audio);
      return;
    }
    if (_voiceStep == _VoiceStep.editAwaitingConfirm) {
      await _handleEditAwaitingConfirm(text, audio);
      return;
    }
    // Route through AI
    final aiResponse = await AIService.sendMessage(text, screen: "address");
    final command   = (aiResponse["command"] ?? "unknown").toString();
    final value     = (aiResponse["value"]   ?? "").toString().trim();
    final iconType  = (aiResponse["icon_type"] ?? "other").toString();
    debugPrint("AI COMMAND (Addresses): $command | $value");

    switch (command) {
      case "save_address":
        if (_voiceStep == _VoiceStep.awaitingConfirm) {
          await _saveVoiceAddress(audio);
        }
        break;

      case "cancel_address":
        setState(() => _voiceStep = _VoiceStep.idle);
        await audio.speak(
          lp.isEnglish ? "Cancelled." : "تم الإلغاء.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;
      case "add_new_address":
        await _startVoiceAddFlow(audio);
        break;

    // ── Edit address by label ────────────────────────────────────────────
      case "edit_address":
        final cleanValue = value
            .replaceAll(RegExp(r'[{}<>"]'), '')
            .replaceAll('label:', '')
            .trim();
        final addr = _findAddressByLabel(cleanValue.isNotEmpty ? cleanValue : text);
        if (addr != null) {
          // ✅ Start voice edit flow instead of opening dialog
          _editingAddress  = addr;
          _editNewLabel    = addr.label;
          _editNewAddress  = addr.address;
          _editNewIconType = addr.iconType;
          setState(() => _voiceStep = _VoiceStep.editAwaitingField);
          await audio.speak(
            lp.isEnglish
                ? "Editing ${addr.label}. Current address is ${addr.address}. "
                "Say label to change the label, address to change the address, "
                "or save to keep as is."
                : "تعديل ${addr.label}. العنوان الحالي هو ${addr.address}. "
                "قل تسمية لتغيير التسمية، أو عنوان لتغيير العنوان، أو احفظ للإبقاء كما هو.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        } else {
          await audio.speak(
            lp.isEnglish
                ? "Couldn't find that address. Say home or work."
                : "لم أجد هذا العنوان. قل منزل أو عمل.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;

    // ── Delete address by label ──────────────────────────────────────────
      case "delete_address":
        final cleanValue = value
            .replaceAll(RegExp(r'[{}<>"]'), '')
            .replaceAll('label:', '')
            .trim();
        final addr = _findAddressByLabel(cleanValue.isNotEmpty ? cleanValue : text);
        if (addr != null) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            await DatabaseService().deleteAddress(userId, addr.id);
            await audio.speak(
              lp.isEnglish
                  ? "${addr.label} address deleted."
                  : "تم حذف عنوان ${addr.label}.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
          }
        } else {
          await audio.speak(
            lp.isEnglish
                ? "Couldn't find that address. Say home, work, or other."
                : "لم أجد هذا العنوان. قل منزل أو عمل أو أخرى.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;

    // ── Label collected ──────────────────────────────────────────────────
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



    // ── Go back ──────────────────────────────────────────────────────────
      case "go_back":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Going back." : "جاري الرجوع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await audio.stop();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.pop(context);
        break;

      default:
        if (_voiceStep == _VoiceStep.awaitingLabel) {
          await _handleRawLabel(text, audio);
        } else {
          await audio.speak(
            lp.isEnglish
                ? "Say add address, edit home or work, delete home or work, or go back."
                : "قل أضف عنوان، عدل المنزل أو العمل، احذف المنزل أو العمل، أو ارجع.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
    }
  }

  // ── Find address by label (fuzzy) ─────────────────────────────────────────
  AddressModel? _findAddressByLabel(String query) {
    final q = query.toLowerCase();
    // Exact match first
    for (final a in _addresses) {
      if (a.label.toLowerCase() == q) return a;
    }
    // Arabic keywords
    if (q.contains("بيت") || q.contains("منزل") || q.contains("home")) {
      return _addresses.firstWhere(
            (a) => a.iconType == "home",
        orElse: () => _addresses.firstWhere(
              (a) => a.label.toLowerCase().contains("home") ||
              a.label.contains("منزل") || a.label.contains("بيت"),
          orElse: () => _addresses.isEmpty ? AddressModel(id:'',label:'',address:'',iconType:'') : _addresses.first,
        ),
      );
    }
    if (q.contains("عمل") || q.contains("مكتب") || q.contains("work") || q.contains("office")) {
      return _addresses.firstWhere(
            (a) => a.iconType == "work",
        orElse: () => _addresses.firstWhere(
              (a) => a.label.toLowerCase().contains("work") ||
              a.label.contains("عمل") || a.label.contains("مكتب"),
          orElse: () => AddressModel(id:'',label:'',address:'',iconType:''),
        ),
      );
    }
    // Partial match
    for (final a in _addresses) {
      if (a.label.toLowerCase().contains(q) || q.contains(a.label.toLowerCase())) {
        return a;
      }
    }
    return null;
  }

  // ── Flow helpers ──────────────────────────────────────────────────────────
  Future<void> _startVoiceAddFlow(AppAudioProvider audio) async {
    setState(() {
      _voiceStep       = _VoiceStep.awaitingLabel;
      _pendingLabel    = '';
      _pendingAddress  = '';
      _pendingIconType = 'home';
    });
    await audio.speak(
      lp.isEnglish
          ? "Say a label: home, work, or other."
          : "قل تسمية: منزل، عمل، أو أخرى.",
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
          ? "Label: $_pendingLabel. Now say your full address."
          : "التسمية: $_pendingLabel. الآن قل عنوانك الكامل.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  Future<void> _handleAwaitingAddress(String text, AppAudioProvider audio) async {
    final lower = text.toLowerCase();
    if (lower.contains("cancel") || lower.contains("إلغاء") || lower.contains("بطل")) {
      setState(() => _voiceStep = _VoiceStep.idle);
      await audio.speak(
        lp.isEnglish ? "Cancelled." : "تم الإلغاء.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      return;
    }
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
    final isSave = lower.contains("save")   || lower.contains("confirm") ||
        lower.contains("yes")    || lower.contains("احفظ")    ||
        lower.contains("تأكيد") || lower.contains("نعم")     ||
        lower.contains("ok")     || lower.contains("تمام");
    final isCancel = lower.contains("cancel") || lower.contains("no") ||
        lower.contains("إلغاء")  || lower.contains("لا") ||
        lower.contains("بطل");
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
    await DatabaseService().addAddress(userId, AddressModel(
      id: '',
      label: _pendingLabel,
      address: _pendingAddress,
      iconType: _pendingIconType,
    ));
    setState(() => _voiceStep = _VoiceStep.idle);
    await audio.speak(
      lp.isEnglish ? "Address saved." : "تم حفظ العنوان.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ✅ FIX: audio provider read moved to Consumer — stops full-screen rebuilds
  //         on every mic status change (notifyListeners).
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userId     = FirebaseAuth.instance.currentUser?.uid;
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

      // ✅ Only this widget rebuilds when audio state changes
      bottomNavigationBar: Consumer<AppAudioProvider>(
        builder: (_, audio, __) => _buildVoiceHint(audio),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAddressDialog(context),
        backgroundColor: primaryRed,
        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: StreamBuilder<List<AddressModel>>(
        stream: DatabaseService().getAddresses(userId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(lp.getText('error_something_wrong')));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ Keep local copy for voice commands
          _addresses = snapshot.data ?? [];

          if (_addresses.isEmpty) {
            return Center(child: Text(lp.getText('no_addresses')));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _addresses.length,
            itemBuilder: (context, index) =>
                _buildAddressCard(_addresses[index], primaryRed, userId),
          );
        },
      ),
    );
  }

  // ── Voice hint ─────────────────────────────────────────────────────────────
  Widget _buildVoiceHint(AppAudioProvider audio) {
    String hint;
    if (_voiceStep == _VoiceStep.awaitingLabel) {
      hint = lp.isEnglish ? "🎤 Say: home, work, or other" : "🎤 قل: منزل، عمل، أو أخرى";
    } else if (_voiceStep == _VoiceStep.awaitingAddress) {
      hint = lp.isEnglish ? "🎤 Say your full address" : "🎤 قل عنوانك الكامل";
    } else if (_voiceStep == _VoiceStep.awaitingConfirm) {
      hint = lp.isEnglish ? "🎤 Say: save  or  cancel" : "🎤 قل: احفظ  أو  إلغاء";
    } else if (_voiceStep == _VoiceStep.editAwaitingField) {
      hint = lp.isEnglish
          ? "🎤 Say: label · address · save · cancel"
          : "🎤 قل: تسمية · عنوان · احفظ · إلغاء";
    } else if (_voiceStep == _VoiceStep.editAwaitingLabel) {
      hint = lp.isEnglish ? "🎤 Say new label: home, work, or other" : "🎤 قل: منزل، عمل، أو أخرى";
    } else if (_voiceStep == _VoiceStep.editAwaitingAddress) {
      hint = lp.isEnglish ? "🎤 Say the new address" : "🎤 قل العنوان الجديد";}
    else {
      hint = audio.isListening && audio.lastWords.isNotEmpty
          ? audio.lastWords
          : (lp.isEnglish
          ? "🎤 Say: add address · edit home · delete work · go back"
          : "🎤 قل: أضف عنوان · عدل المنزل · احذف العمل · ارجع");
    }
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: audio.isListening ? const Color(0xFFD6EED6) : const Color(0xFFD6E0E0),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, color: audio.isListening ? Colors.green : Colors.teal),
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

  // ── Address card ──────────────────────────────────────────────────────────
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
                          style: TextStyle(color: Colors.grey[600], fontSize: 14)),
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
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                  label: Text(lp.getText('edit'),
                      style: const TextStyle(color: Colors.blueGrey)),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () async {
                    await DatabaseService().deleteAddress(userId, item.id);
                    final audio = Provider.of<AppAudioProvider>(context, listen: false);
                    await audio.speak(
                      lp.isEnglish
                          ? "${item.label} address deleted."
                          : "تم حذف عنوان ${item.label}.",
                      lp.isEnglish ? "en-US" : "ar-SA",
                    );
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: Text(lp.getText('delete'),
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Add/Edit dialog ───────────────────────────────────────────────────────
  void _showAddAddressDialog(BuildContext context,
      {AddressModel? existingAddress}) {
    final labelController   = TextEditingController(text: existingAddress?.label ?? '');
    final addressController = TextEditingController(text: existingAddress?.address ?? '');
    String selectedIconType = existingAddress?.iconType ?? 'home';
    final userId   = FirebaseAuth.instance.currentUser?.uid;
    bool isEditing = existingAddress != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    _buildIconChoice(
                        Icons.home_outlined, 'home', selectedIconType,
                        lp.getText('home_label'),
                            (t) => setDialogState(() => selectedIconType = t)),
                    _buildIconChoice(
                        Icons.work_outline, 'work', selectedIconType,
                        lp.getText('work_label'),
                            (t) => setDialogState(() => selectedIconType = t)),
                    _buildIconChoice(
                        Icons.location_on_outlined, 'other', selectedIconType,
                        lp.getText('other_label'),
                            (t) => setDialogState(() => selectedIconType = t)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            // ✅ Cancel button closes dialog and announces
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final audio =
                Provider.of<AppAudioProvider>(context, listen: false);
                await audio.speak(
                  lp.isEnglish ? "Cancelled." : "تم الإلغاء.",
                  lp.isEnglish ? "en-US" : "ar-SA",
                );
              },
              child: Text(lp.getText('cancel')),
            ),
            // ✅ Update/Save button announces on success
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
                  final audio =
                  Provider.of<AppAudioProvider>(context, listen: false);
                  await audio.speak(
                    lp.isEnglish
                        ? isEditing
                        ? "Address updated successfully."
                        : "Address saved successfully."
                        : isEditing
                        ? "تم تحديث العنوان بنجاح."
                        : "تم حفظ العنوان بنجاح.",
                    lp.isEnglish ? "en-US" : "ar-SA",
                  );
                } else {
                  final audio =
                  Provider.of<AppAudioProvider>(context, listen: false);
                  await audio.speak(
                    lp.isEnglish
                        ? "Please fill in all fields."
                        : "من فضلك اكمل جميع الحقول.",
                    lp.isEnglish ? "en-US" : "ar-SA",
                  );
                }
              },
              child: Text(
                isEditing ? lp.getText('update_address') : lp.getText('save_address'),
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
                color:
                isSelected ? const Color(0xFFD32F2F) : Colors.grey),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color:
                isSelected ? const Color(0xFFD32F2F) : Colors.grey)),
      ],
    );
  }
}