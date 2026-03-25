import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/AddressModel.dart';
//Done
class DeliveryAddressesPage extends StatefulWidget {
  const DeliveryAddressesPage({super.key});

  @override
  State<DeliveryAddressesPage> createState() => _DeliveryAddressesPageState();
}

class _DeliveryAddressesPageState extends State<DeliveryAddressesPage> {
 

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    const primaryRed = Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Delivery Addresses", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // Floating Action Button to add new address
     floatingActionButton: FloatingActionButton(
  onPressed: () => _showAddAddressDialog(context), // Logic connected here
  backgroundColor: const Color(0xFFD32F2F),
  child: const Icon(Icons.add, color: Colors.white),
),
    body: StreamBuilder<List<AddressModel>>(
      stream: DatabaseService().getAddresses(userId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Something went wrong"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final addresses = snapshot.data ?? [];

        if (addresses.isEmpty) return const Center(child: Text("No addresses saved yet."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            final item = addresses[index];
            return _buildAddressCard(item, const Color(0xFFD32F2F), userId);
          },
        );
      },
    ),
    );
  }

  Widget _buildAddressCard(AddressModel item, Color accent, String userId) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: item.isDefault ? accent : Colors.grey[200]!, width: item.isDefault ? 2 : 1),
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
                    color: accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: accent, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.label,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (item.isDefault)
                            Container(
                              margin: const EdgeInsets.only(left: 8),          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "DEFAULT",
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.address,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
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
  onPressed: () {
    // Pass the current 'item' (AddressModel) to the dialog
    _showAddAddressDialog(context, existingAddress: item); 
  },
  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
  label: const Text("Edit", style: TextStyle(color: Colors.blueGrey)),
),
                const SizedBox(width: 10),
                TextButton.icon(
              onPressed: () => DatabaseService().deleteAddress(userId, item.id),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
              ],
            )
          ],
        ),
      ),
    );
  }

void _showAddAddressDialog(BuildContext context,{AddressModel? existingAddress}) {
  final labelController = TextEditingController();
  final addressController = TextEditingController();
  String selectedIconType = 'home'; // Default selection
  final userId = FirebaseAuth.instance.currentUser?.uid;
bool isEditing = existingAddress != null;
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEditing ? "Edit Address" : "Add New Address"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField("Label", "e.g. Home, Work, Gym", labelController),
              const SizedBox(height: 15),
              _buildDialogField("Address", "Street, City, Province", addressController, maxLines: 2),
              const SizedBox(height: 20),
              const Text("Select Icon", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              
              // Icon Selection Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _iconPicker(Icons.home_outlined, 'home', selectedIconType, (type) {
                    setDialogState(() => selectedIconType = type);
                  }),
                  _iconPicker(Icons.work_outline, 'work', selectedIconType, (type) {
                    setDialogState(() => selectedIconType = type);
                  }),
                  _iconPicker(Icons.location_on_outlined, 'other', selectedIconType, (type) {
                    setDialogState(() => selectedIconType = type);
                  }),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
      ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
  onPressed: () async {
    // 1. Basic Validation: Don't save if fields are empty
    if (labelController.text.isNotEmpty && addressController.text.isNotEmpty) {
      
      // 2. Create the data object
      final addressData = AddressModel(
        id: isEditing ? existingAddress.id : '', // Use existing ID if editing
        label: labelController.text,
        address: addressController.text,
        iconType: selectedIconType,
      );

      // 3. Choose the Database Operation
      if (isEditing) {
        // Calls the update method
        await DatabaseService().updateAddress(userId!, addressData);
      } else {
        // Calls the add method
        await DatabaseService().addAddress(userId!, addressData);
      }

      // 4. Close the dialog
      Navigator.pop(context);
      
      // Optional: Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? "Address updated!" : "Address saved!"))
      );
    } else {
      // Show error if fields are empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields"))
      );
    }
  },
  child: Text(
    isEditing ? "Update Address" : "Save Address", 
    style: const TextStyle(color: Colors.white),
  ),
),
        ],
      ),
    ),
  );
}

Widget _buildDialogField(String label, String hint, TextEditingController controller, {int maxLines = 1}) {
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

Widget _iconPicker(IconData icon, String type, String current, Function(String) onSelect) {
  bool isSelected = type == current;
  return GestureDetector(
    onTap: () => onSelect(type),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD32F2F).withOpacity(0.1) : Colors.transparent,
        border: Border.all(color: isSelected ? const Color(0xFFD32F2F) : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: isSelected ? const Color(0xFFD32F2F) : Colors.grey),
    ),
  );
}


}