import 'package:flutter/material.dart';

class DeliveryAddressesPage extends StatefulWidget {
  const DeliveryAddressesPage({super.key});

  @override
  State<DeliveryAddressesPage> createState() => _DeliveryAddressesPageState();
}

class _DeliveryAddressesPageState extends State<DeliveryAddressesPage> {
  // Mock data for addresses
  final List<Map<String, dynamic>> _addresses = [
    {
      "label": "Home",
      "address": "123 Maple Avenue, Toronto, ON M5V 2L7",
      "icon": Icons.home_outlined,
      "isDefault": true,
    },
    {
      "label": "Work",
      "address": "88 Queens Quay W, Toronto, ON M5J 0B8",
      "icon": Icons.work_outline,
      "isDefault": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
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
        onPressed: () {
          // Logic to add a new address
        },
        backgroundColor: primaryRed,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _addresses.length,
        itemBuilder: (context, index) {
          final item = _addresses[index];
          return _buildAddressCard(item, primaryRed);
        },
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> item, Color accent) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: item['isDefault'] ? accent : Colors.grey[200]!, width: item['isDefault'] ? 2 : 1),
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
                  child: Icon(item['icon'], color: accent, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item['label'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (item['isDefault'])
                            Container(
                              margin: const EdgeInsets.only(left: 8),                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                        item['address'],
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
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                  label: const Text("Edit", style: TextStyle(color: Colors.blueGrey)),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}