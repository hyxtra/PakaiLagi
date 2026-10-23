/// Aturan validasi murni untuk data barang sebelum dipublikasikan.
abstract final class ItemValidator {
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Judul wajib diisi';
    return null;
  }

  static String? validateCategory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pilih kategori barang dulu ya';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    if (value == null || value.trim().length < 5) {
      return 'Deskripsi minimal 5 karakter';
    }
    return null;
  }
}
