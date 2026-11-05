import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../business/address_privacy.dart';

/// Kegagalan lokasi dengan pesan yang siap ditampilkan ke pengguna.
class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Bagian alamat hasil reverse geocoding.
typedef AddressParts = ({String fullAddress, String kelurahan, String kota});

/// Akses GPS, reverse geocoding, dan Google Maps di satu tempat.
abstract final class LocationService {
  static const gpsTimeout = Duration(seconds: 15);
  static const _geocodeTimeout = Duration(seconds: 10);

  /// Paket `geocoding` hanya punya implementasi Android & iOS. Di Web/desktop
  /// titik peta tetap bisa dipilih, tetapi alamat diisi manual.
  static bool get reverseGeocodingSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Posisi GPS akurasi tinggi (satu kali, izin saat aplikasi dipakai).
  /// Melempar [LocationFailure] dengan pesan berbahasa Indonesia.
  static Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
          'Layanan lokasi sedang mati. Aktifkan GPS terlebih dahulu.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
          'Izin lokasi ditolak. Geser peta untuk memilih titik secara manual.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
          'Izin lokasi ditolak permanen. Aktifkan dari Pengaturan HP.');
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: gpsTimeout,
      );
    } on TimeoutException {
      throw const LocationFailure(
          'Lokasi tidak didapat dalam 15 detik. Coba di tempat terbuka atau '
          'geser peta secara manual.');
    }
  }

  /// Alamat untuk koordinat. Null bila tidak didukung platform, gagal, atau
  /// tidak ada hasil (pemanggil meminta pengguna mengisi alamat manual).
  static Future<AddressParts?> reverseGeocode(
      double latitude, double longitude) async {
    if (!reverseGeocodingSupported) return null;
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude)
          .timeout(_geocodeTimeout);
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final parts = AddressPrivacy.fromPlacemark(
        street: place.street,
        subLocality: place.subLocality,
        locality: place.locality,
        subAdministrativeArea: place.subAdministrativeArea,
        administrativeArea: place.administrativeArea,
        postalCode: place.postalCode,
      );
      return parts.fullAddress.isEmpty ? null : parts;
    } catch (_) {
      return null;
    }
  }

  /// URL Google Maps (Maps URLs API, tanpa API key). Di Android/iOS tautan
  /// ini dibuka oleh aplikasi Google Maps bila terpasang.
  static Uri googleMapsUri(
      {double? latitude, double? longitude, String? query}) {
    final q = latitude != null && longitude != null
        ? '$latitude,$longitude'
        : (query ?? '').trim();
    return Uri.https(
        'www.google.com', '/maps/search/', {'api': '1', 'query': q});
  }

  /// Membuka Google Maps. Return false bila tidak ada aplikasi yang bisa
  /// membuka tautan.
  static Future<bool> openInGoogleMaps(
      {double? latitude, double? longitude, String? query}) {
    return launchUrl(
      googleMapsUri(latitude: latitude, longitude: longitude, query: query),
      mode: LaunchMode.externalApplication,
    );
  }
}
