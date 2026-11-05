import 'package:flutter/foundation.dart';

import '../business/address_privacy.dart';

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.kelurahan = '',
    this.kota = '',
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String email;
  final String phone;

  /// Alamat lengkap. Hanya disimpan di profil privat dan dokumen lokasi
  /// privat barang; tidak pernah ditulis ke dokumen `items` yang publik.
  final String address;

  /// Bagian alamat yang boleh terlihat oleh pengguna lain.
  final String kelurahan;
  final String kota;

  /// Koordinat GPS (opsional), ikut privat bersama alamat lengkap.
  final double? latitude;
  final double? longitude;

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
  }

  /// Label publik, mis. "Kel. Melati, Jakarta Selatan".
  String get areaLabel =>
      AddressPrivacy.areaLabel(kelurahan: kelurahan, kota: kota);

  /// Alamat dianggap siap dipakai untuk posting barang bila alamat lengkap
  /// dan bagian publiknya (kelurahan & kota) sudah terisi.
  bool get hasPickupAddress =>
      address.trim().isNotEmpty &&
      kelurahan.trim().isNotEmpty &&
      kota.trim().isNotEmpty;

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? kelurahan,
    String? kota,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      kelurahan: kelurahan ?? this.kelurahan,
      kota: kota ?? this.kota,
      latitude: clearCoordinates ? null : latitude ?? this.latitude,
      longitude: clearCoordinates ? null : longitude ?? this.longitude,
    );
  }
}
