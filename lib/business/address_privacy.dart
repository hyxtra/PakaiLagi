/// Aturan privasi alamat PakaiLagi.
///
/// Alamat lengkap dan koordinat GPS bersifat privat. Pengguna lain hanya
/// melihat kelurahan dan kota/kabupaten. Alamat lengkap hanya dapat dibaca
/// pemilik barang dan peminta yang pengajuannya sudah diterima (ditegakkan
/// oleh `firestore.rules`).
abstract final class AddressPrivacy {
  /// Field yang dilarang ada di dokumen `items` karena dokumen itu publik.
  static const privateItemFields = {'address', 'latitude', 'longitude'};

  /// Label publik, mis. "Kel. Melati, Jakarta Selatan".
  static String areaLabel({required String kelurahan, required String kota}) {
    final kel = kelurahan.trim();
    final city = kota.trim();
    final parts = [
      if (kel.isNotEmpty) _withKelurahanPrefix(kel),
      if (city.isNotEmpty) city,
    ];
    return parts.join(', ');
  }

  static String _withKelurahanPrefix(String kelurahan) {
    final lower = kelurahan.toLowerCase();
    if (lower.startsWith('kel.') ||
        lower.startsWith('kelurahan') ||
        lower.startsWith('desa')) {
      return kelurahan;
    }
    return 'Kel. $kelurahan';
  }

  /// Menyusun bagian alamat dari hasil reverse geocoding.
  ///
  /// Di Indonesia, `subLocality` umumnya berisi kelurahan/desa dan
  /// `subAdministrativeArea` berisi kota/kabupaten. `locality` dipakai sebagai
  /// cadangan kota karena sebagian perangkat mengisinya dengan nama kota.
  static ({String fullAddress, String kelurahan, String kota}) fromPlacemark({
    String? street,
    String? subLocality,
    String? locality,
    String? subAdministrativeArea,
    String? administrativeArea,
    String? postalCode,
  }) {
    String clean(String? value) => value?.trim() ?? '';

    final kelurahan = clean(subLocality);
    final kota = clean(subAdministrativeArea).isNotEmpty
        ? clean(subAdministrativeArea)
        : clean(locality);

    final seen = <String>{};
    final parts = [
      clean(street),
      kelurahan,
      clean(locality),
      clean(subAdministrativeArea),
      clean(administrativeArea),
      clean(postalCode),
    ].where((part) => part.isNotEmpty && seen.add(part.toLowerCase()));

    return (fullAddress: parts.join(', '), kelurahan: kelurahan, kota: kota);
  }
}
