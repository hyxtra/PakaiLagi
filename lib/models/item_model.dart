import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../business/address_privacy.dart';
import '../business/image_base64.dart';
import '../data/pickup_methods.dart';

// =============================================================================
// FILE 1: item_model.dart
// Model data barang yang tersimpan di koleksi publik `items`.
//
// PRIVASI: dokumen `items` dapat dibaca semua pengguna yang login, sehingga
// hanya menyimpan kelurahan & kota. Alamat lengkap dan koordinat GPS berada
// di `items/{id}/private/location` (lihat [ItemPrivateLocation]).
// =============================================================================

@immutable
class ItemModel {
  const ItemModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.kelurahan = '',
    this.kota = '',
    this.pickupMethods = const [],
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
  final String kelurahan;
  final String kota;

  /// Metode pengambilan yang dipilih pemberi. Kosong untuk barang lama yang
  /// diposting sebelum metode disimpan; gunakan [availablePickupMethods].
  final List<String> pickupMethods;
  final String imageBase64;
  final String donorId;
  final String ownerName;
  final String status;
  final DateTime? createdAt;

  /// Metode yang boleh dipilih peminta. Barang lama (tanpa data metode)
  /// menawarkan semua metode, seperti perilaku sebelum metode disimpan.
  List<String> get availablePickupMethods =>
      pickupMethods.isEmpty ? kPickupMethodNames : pickupMethods;

  /// Lokasi yang boleh dilihat publik, mis. "Kel. Melati, Jakarta Selatan".
  String get areaLabel =>
      AddressPrivacy.areaLabel(kelurahan: kelurahan, kota: kota);

  /// Membuat model cloud dari dokumen Firestore. ID selalu berasal dari
  /// [DocumentSnapshot.id], bukan dari field data, agar route detail memakai
  /// identitas dokumen yang benar.
  factory ItemModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ItemModel.fromMap(doc.data() ?? const <String, dynamic>{},
        id: doc.id);
  }

  /// Factory terpisah agar parsing dapat diuji tanpa koneksi Firestore.
  /// Field privat lama (`address`, `latitude`, `longitude`) sengaja diabaikan.
  factory ItemModel.fromMap(Map<String, dynamic> data, {required String id}) {
    final rawCreatedAt = data['createdAt'];
    return ItemModel(
      id: id,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      kelurahan: data['kelurahan'] as String? ?? '',
      kota: data['kota'] as String? ?? '',
      pickupMethods: _parsePickupMethods(data['pickupMethods']),
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

  /// Hanya nama metode yang dikenal aplikasi yang diterima; data rusak atau
  /// bertipe salah menghasilkan daftar kosong (dianggap barang lama).
  static List<String> _parsePickupMethods(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .where(kPickupMethodNames.contains)
        .toSet()
        .toList(growable: false);
  }

  /// Bytes gambar untuk Image.memory; null untuk gambar kosong/rusak.
  Uint8List? get imageBytes {
    return ImageBase64.decodeOrNull(imageBase64);
  }

  @override
  String toString() => 'ItemModel(id: $id, title: $title, category: $category)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemModel &&
          id == other.id &&
          title == other.title &&
          category == other.category &&
          description == other.description &&
          kelurahan == other.kelurahan &&
          kota == other.kota;

  @override
  int get hashCode =>
      Object.hash(id, title, category, description, kelurahan, kota);
}

/// Lokasi lengkap barang di `items/{id}/private/location`.
/// Hanya dapat dibaca pemilik dan peminta yang pengajuannya diterima.
@immutable
class ItemPrivateLocation {
  const ItemPrivateLocation({
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String address;
  final double? latitude;
  final double? longitude;

  factory ItemPrivateLocation.fromMap(Map<String, dynamic> data) {
    return ItemPrivateLocation(
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }
}
