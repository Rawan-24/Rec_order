import 'package:flutter/material.dart';

class AddressModel {
  String id;
  String label;
  String address;
  String iconType; // "home", "work", or "other"
  bool isDefault;

  AddressModel({
    required this.id,
    required this.label,
    required this.address,
    required this.iconType,
    this.isDefault = false,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'address': address,
      'iconType': iconType,
      'isDefault': isDefault,
    };
  }

  // Create from Firestore document
  factory AddressModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AddressModel(
      id: id,
      label: data['label'] ?? '',
      address: data['address'] ?? '',
      iconType: data['iconType'] ?? 'other',
      isDefault: data['isDefault'] ?? false,
    );
  }

  // Helper to get the actual Flutter Icon
  IconData get icon {
    switch (iconType) {
      case 'home': return Icons.home_outlined;
      case 'work': return Icons.work_outline;
      default: return Icons.location_on_outlined;
    }
  }
}