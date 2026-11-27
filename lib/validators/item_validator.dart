// Aturan validasi murni untuk data barang sebelum dipublikasikan.
//
// Semua fungsi bersifat pure (tidak bergantung pada Flutter / Firebase),
// sehingga dapat diuji dengan unit test biasa tanpa widget test.
//
// Dipakai oleh:
//   - PostItemScreen._validateForm() agar validasi UI konsisten dengan aturan di sini.
//   - test/validators/item_validator_test.dart
import '../models/item.dart' show ListingType;

abstract final class ItemValidator {
  /// Jenis penawaran yang saat ini didukung PakaiLagi.
  static String? validateListingType(String? value) {
    if (value != ListingType.gratis && value != ListingType.tebusMurah) {
      return 'Pilih Gratis atau Tebus Murah';
    }
    return null;
  }

  /// Harga simbolis hanya berlaku untuk tebus murah, dengan batas Rp50.000.
  static String? validateListingPrice({
    required String listingType,
    required int? price,
  }) {
    if (listingType == ListingType.gratis) return null;
    if (listingType != ListingType.tebusMurah) {
      return 'Pilih jenis penawaran yang valid';
    }
    if (price == null) return 'Masukkan harga tebus murah';
    if (price < 0) return 'Harga tidak boleh kurang dari Rp0';
    if (price > 50000) return 'Harga maksimal Rp50.000';
    return null;
  }

  // ---------------------------------------------------------------------------
  // VALIDASI JUDUL
  // ---------------------------------------------------------------------------

  /// Judul wajib diisi dan tidak boleh hanya spasi.
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Judul wajib diisi';
    return null;
  }

  // ---------------------------------------------------------------------------
  // VALIDASI KATEGORI
  // ---------------------------------------------------------------------------

  /// Kategori wajib dipilih (tidak boleh null atau kosong).
  static String? validateCategory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pilih kategori barang dulu ya';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // VALIDASI DESKRIPSI
  // ---------------------------------------------------------------------------

  /// Deskripsi minimal 5 karakter (di luar spasi).
  static String? validateDescription(String? value) {
    if (value == null || value.trim().length < 5) {
      return 'Deskripsi minimal 5 karakter';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // VALIDASI METODE PENGAMBILAN  ← BARU (P9)
  // ---------------------------------------------------------------------------

  /// Minimal satu metode pengambilan harus dipilih.
  static String? validatePickupMethods(Set<String> methods) {
    if (methods.isEmpty) return 'Pilih minimal satu metode pengambilan';
    return null;
  }

  // ---------------------------------------------------------------------------
  // VALIDASI FOTO  ← BARU (P9)
  // ---------------------------------------------------------------------------

  /// Foto barang wajib ada sebelum post.
  static String? validateImage(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return 'Foto barang wajib ditambahkan untuk post';
    }
    return null;
  }
}
