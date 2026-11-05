import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_palette.dart';

/// Peta kecil non-interaktif yang menampilkan satu pin.
class PinPreviewMap extends StatelessWidget {
  const PinPreviewMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 150,
    this.onTap,
    this.semanticLabel = 'Peta titik penjemputan',
  });

  final double latitude;
  final double longitude;
  final double height;
  final VoidCallback? onTap;

  /// Dibacakan pembaca layar (peta sendiri tidak punya teks yang bermakna).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: onTap == null,
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: _map(context),
    );
  }

  Widget _map(BuildContext context) {
    final p = context.palette;
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              // initialCenter hanya dipakai saat build pertama; key memaksa
              // peta dibuat ulang ketika titik berubah.
              key: ValueKey('$latitude,$longitude'),
              options: MapOptions(
                initialCenter: point,
                initialZoom: 17,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pakailagi.pakailagi',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: Icon(Icons.location_on, size: 40, color: p.danger),
                  ),
                ]),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onTap),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
