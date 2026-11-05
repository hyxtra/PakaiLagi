import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../widgets/progress_dialog.dart';
import '../theme/app_palette.dart';

// =============================================================================
// location_picker_screen.dart
// Pinpoint lokasi penjemputan di peta (OpenStreetMap via flutter_map).
//
// CARA KERJA:
//   - Saat dibuka tanpa titik awal, GPS langsung dicari (akurasi terbaik) dan
//     peta diarahkan ke posisi itu, lengkap dengan lingkaran akurasi.
//   - Pin diam di tengah layar; pengguna menggeser peta untuk menyempurnakan
//     titik (mis. tepat di depan pagar rumah).
//   - Setiap kali peta berhenti digeser, alamat dibaca ulang (Android/iOS).
//   - "Pilih Titik Ini" mengembalikan [PickedLocation] ke pemanggil.
// =============================================================================

/// Hasil pinpoint. [address] null bila alamat tidak bisa dibaca otomatis.
@immutable
class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final AddressParts? address;
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen(
      {super.key, this.initialLatitude, this.initialLongitude});

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  /// Titik awal sebelum GPS didapat (Monas, Jakarta).
  static const _fallbackCenter = LatLng(-6.175392, 106.827153);
  static const _pinZoom = 18.0;
  static const _osmCopyright = 'https://www.openstreetmap.org/copyright';

  final _mapController = MapController();
  late LatLng _center;
  bool _mapReady = false;

  LatLng? _gpsPoint;
  double? _gpsAccuracy;
  bool _locating = false;

  AddressParts? _address;
  bool _resolving = false;
  Timer? _debounce;
  int _geocodeRequest = 0;

  bool get _hasInitial =>
      widget.initialLatitude != null && widget.initialLongitude != null;

  @override
  void initState() {
    super.initState();
    _center = _hasInitial
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : _fallbackCenter;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    if (_hasInitial) {
      _resolveAddress();
    } else {
      _locate();
    }
  }

  /// Ambil posisi GPS lalu pindahkan peta ke sana.
  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final position = await LocationService.currentPosition();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _gpsPoint = point;
        _gpsAccuracy = position.accuracy;
        _center = point;
      });
      if (_mapReady) _mapController.move(point, _pinZoom);
      _resolveAddress();
    } on LocationFailure catch (failure) {
      _snack(failure.message);
    } catch (_) {
      _snack('Gagal mengambil lokasi. Geser peta untuk memilih titik.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (!hasGesture) return;
    // Tunggu peta berhenti digeser sebelum membaca alamat.
    _debounce?.cancel();
    setState(() => _resolving = LocationService.reverseGeocodingSupported);
    _debounce = Timer(const Duration(milliseconds: 700), _resolveAddress);
  }

  Future<void> _resolveAddress() async {
    if (!LocationService.reverseGeocodingSupported) {
      if (mounted) setState(() => _resolving = false);
      return;
    }
    final request = ++_geocodeRequest;
    final point = _center;
    setState(() => _resolving = true);
    final parts =
        await LocationService.reverseGeocode(point.latitude, point.longitude);
    // Abaikan hasil lama bila peta sudah digeser lagi.
    if (!mounted || request != _geocodeRequest) return;
    setState(() {
      _address = parts;
      _resolving = false;
    });
  }

  void _confirm() {
    Navigator.of(context).pop(PickedLocation(
      latitude: _center.latitude,
      longitude: _center.longitude,
      address: _resolving ? null : _address,
    ));
  }

  /// Semua pesan di layar ini adalah kegagalan GPS/izin → merah.
  void _snack(String message) {
    if (!mounted) return;
    AppMessenger.of(context).error(message);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Pinpoint Lokasi'),
        backgroundColor: p.surface,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Semantics(
                  label: 'Peta. Geser peta dengan dua jari untuk memindahkan '
                      'pin penjemputan di tengah layar.',
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: _hasInitial ? _pinZoom : 12,
                      minZoom: 4,
                      maxZoom: 19,
                      onMapReady: _onMapReady,
                      onPositionChanged: _onPositionChanged,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.pakailagi.pakailagi',
                        maxNativeZoom: 19,
                      ),
                      if (_gpsPoint != null && _gpsAccuracy != null)
                        CircleLayer(circles: [
                          CircleMarker(
                            point: _gpsPoint!,
                            radius: _gpsAccuracy!,
                            useRadiusInMeter: true,
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderColor: Colors.blue.withValues(alpha: 0.5),
                            borderStrokeWidth: 1.5,
                          ),
                        ]),
                      if (_gpsPoint != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: _gpsPoint!,
                            width: 18,
                            height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ]),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(Uri.parse(_osmCopyright)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Pin tetap di tengah; ujung bawah ikon tepat di titik pusat.
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -22),
                      child: Icon(Icons.location_on, size: 48, color: p.danger),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'locate-me',
                    backgroundColor: p.surface,
                    foregroundColor: p.primary,
                    tooltip: 'Lokasi saya (GPS)',
                    onPressed: _locating ? null : _locate,
                    child: _locating
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: p.primary),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          _bottomPanel(p),
        ],
      ),
    );
  }

  Widget _bottomPanel(AppPalette p) {
    final String addressText;
    if (_locating) {
      // Sebelumnya saat GPS dicari panel menulis "Alamat tidak terbaca",
      // padahal aplikasi masih bekerja.
      addressText = 'Mencari lokasi GPS kamu…';
    } else if (_resolving) {
      addressText = 'Membaca alamat…';
    } else if (_address != null) {
      addressText = _address!.fullAddress;
    } else if (LocationService.reverseGeocodingSupported) {
      addressText = 'Alamat tidak terbaca. Kamu bisa mengisinya manual '
          'setelah memilih titik.';
    } else {
      addressText = 'Alamat diisi manual setelah memilih titik '
          '(baca alamat otomatis hanya di Android/iOS).';
    }
    final busy = _locating || _resolving;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Geser peta sampai pin tepat di titik penjemputan.',
                style: TextStyle(fontSize: 12.5, color: p.textMuted)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 18, color: p.primary),
                const SizedBox(width: 8),
                Expanded(
                  // liveRegion: alamat baru langsung dibacakan pembaca layar.
                  child: Semantics(
                    liveRegion: true,
                    child: Text(addressText,
                        style: TextStyle(
                            fontSize: 14, height: 1.4, color: p.text)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_center.latitude.toStringAsFixed(6)}, '
              '${_center.longitude.toStringAsFixed(6)}'
              '${_gpsAccuracy != null ? '  •  Akurasi GPS ±${_gpsAccuracy!.round()} m' : ''}',
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                // Nonaktif selama GPS dicari (titik akan berpindah) dan selama
                // alamat dibaca, agar titik & alamat yang dipilih cocok.
                onPressed: busy ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  disabledBackgroundColor: p.primary.withValues(alpha: 0.6),
                  disabledForegroundColor: p.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: p.onPrimary),
                      )
                    : const Icon(Icons.check),
                label: Text(
                    _locating
                        ? 'Mencari GPS…'
                        : _resolving
                            ? 'Membaca alamat…'
                            : 'Pilih Titik Ini',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
