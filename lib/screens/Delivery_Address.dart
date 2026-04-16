import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/AddressModel.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';

class DeliveryAddressesPage extends StatefulWidget {
  const DeliveryAddressesPage({super.key});

  @override
  State<DeliveryAddressesPage> createState() => _DeliveryAddressesPageState();
}

class _DeliveryAddressesPageState extends State<DeliveryAddressesPage> {
  late LanguageProvider lp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePage();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    lp = Provider.of<LanguageProvider>(context);
  }

  void _announcePage() {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    String msg = lp.isRTL
        ? "عناوين التوصيل. المساعد الشخصي مفعل، يمكنك قول إضافة عنوان."
        : "Delivery addresses. Assistant mode is active, you can say add address.";
    audio.speak(msg, lp.currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    const primaryRed = Color(0xFFD32F2F);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(lp.getText('address'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          onPressed: () => _showAddAddressDialog(context),
          backgroundColor: primaryRed,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<AddressModel>>(
        stream: DatabaseService().getAddresses(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(lp.getText('error_something_wrong')));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty) {
            return Center(child: Text(lp.getText('no_addresses')));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
                left: 16, right: 16, top: 16, bottom: 100),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final item = addresses[index];
              return _buildAddressCard(item, primaryRed, userId, audio);
            },
          );
        },
      ),
    );
  }

  // Helper method to build each address card
  Widget _buildAddressCard(
      AddressModel item, Color accent, String userId, AppAudioProvider audio) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
            color: item.isDefault ? accent : Colors.grey[200]!,
            width: item.isDefault ? 2 : 1),
      ),
      child: InkWell(
        onTap: () {
          String details = lp.isRTL
              ? "عنوان ${item.label}: ${item.address}"
              : "${item.label} address: ${item.address}";
          audio.speak(details, lp.currentLanguage);
        },
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
                    onPressed: () async {
                      audio.speak(
                          lp.isRTL ? "تم حذف العنوان" : "Address deleted",
                          lp.currentLanguage);
                      await DatabaseService().deleteAddress(userId, item.id);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: Text(lp.getText('delete'),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // Dialog to Add/Edit Address
  void _showAddAddressDialog(BuildContext context,
      {AddressModel? existingAddress}) {
    final labelController =
    TextEditingController(text: existingAddress?.label ?? "");
    final addressController =
    TextEditingController(text: existingAddress?.address ?? "");
    String selectedIconType = existingAddress?.iconType ?? 'home';
    final userId = FirebaseAuth.instance.currentUser?.uid;
    bool isEditing = existingAddress != null;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

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
                _buildDialogField(
                    lp.getText('label'), lp.getText('label_hint'), labelController),
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
                    _iconWithLabel(
                        Icons.home_outlined,
                        'home',
                        selectedIconType,
                        lp.getText('home_label'),
                            (type) => setDialogState(() => selectedIconType = type)),
                    _iconWithLabel(
                        Icons.work_outline,
                        'work',
                        selectedIconType,
                        lp.getText('work_label'),
                            (type) => setDialogState(() => selectedIconType = type)),
                    _iconWithLabel(
                        Icons.location_on_outlined,
                        'other',
                        selectedIconType,
                        lp.getText('other_label'),
                            (type) => setDialogState(() => selectedIconType = type)),
                  ],
                )
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
                  final addressData = AddressModel(
                    id: isEditing ? existingAddress.id : '',
                    label: labelController.text,
                    address: addressController.text,
                    iconType: selectedIconType,
                  );

                  if (isEditing) {
                    await DatabaseService().updateAddress(userId!, addressData);
                    audio.speak(lp.isRTL ? "تم تحديث العنوان" : "Address updated",
                        lp.currentLanguage);
                  } else {
                    await DatabaseService().addAddress(userId!, addressData);
                    audio.speak(lp.isRTL ? "تم حفظ العنوان" : "Address saved",
                        lp.currentLanguage);
                  }
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(
                  isEditing
                      ? lp.getText('update_address')
                      : lp.getText('save_address'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconWithLabel(IconData icon, String type, String current, String label,
      Function(String) onSelect) {
    bool isSelected = type == current;
    return Column(
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
                  color: isSelected ? const Color(0xFFD32F2F) : Colors.grey[300]!),
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

  Widget _buildDialogField(
      String label, String hint, TextEditingController controller,
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
} // End of _DeliveryAddressesPageState