import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../business/image_base64.dart';

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
    this.imageBase64 = '',
    this.donorId = '',
    this.ownerName = 'Pengguna',
    this.status = 'available',
    this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String address;
  final String pickupMethod;
  final String imageBase64;
  final String donorId;
  final String ownerName;
  final String status;
  final DateTime? createdAt;

  /// Membuat model cloud dari dokumen Firestore. ID selalu berasal dari
  /// [DocumentSnapshot.id], bukan dari field data, agar route detail memakai
  /// identitas dokumen yang benar.
  factory ItemModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ItemModel.fromMap(doc.data() ?? const <String, dynamic>{},
        id: doc.id);
  }

  /// Factory terpisah agar parsing dapat diuji tanpa koneksi Firestore.
  factory ItemModel.fromMap(Map<String, dynamic> data, {required String id}) {
    final rawCreatedAt = data['createdAt'];
    return ItemModel(
      id: id,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      address: data['address'] as String? ?? '',
      pickupMethod: data['pickupMethod'] as String? ?? 'Ambil Sendiri',
      imageBase64: data['imageBase64'] as String? ?? '',
      donorId: data['donorId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? 'Pengguna',
      status: data['status'] as String? ?? 'available',
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : rawCreatedAt is DateTime
              ? rawCreatedAt
              : null,
    );
  }

  /// Bytes gambar untuk Image.memory; null untuk gambar kosong/rusak.
  Uint8List? get imageBytes {
    return ImageBase64.decodeOrNull(imageBase64);
  }

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
