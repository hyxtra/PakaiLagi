import 'package:flutter/foundation.dart';

// =============================================================================
// FILE 1: item_model.dart
// Model data sederhana untuk barang yang akan diposting.
// Dipakai oleh Repository dan Notifier sebagai kontrak data.
// =============================================================================

/// Model data sederhana merepresentasikan barang yang diposting user.
/// Immutable — menggunakan @immutable annotation sesuai best practice Flutter.
@immutable
class ItemModel {
  const ItemModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.address,
    required this.pickupMethod,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String address;
  final String pickupMethod;

  @override
  String toString() =>
      'ItemModel(id: $id, title: $title, category: $category, pickupMethod: $pickupMethod)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemModel &&
          id == other.id &&
          title == other.title &&
          category == other.category &&
          description == other.description &&
          address == other.address &&
          pickupMethod == other.pickupMethod;

  @override
  int get hashCode =>
      Object.hash(id, title, category, description, address, pickupMethod);
}
