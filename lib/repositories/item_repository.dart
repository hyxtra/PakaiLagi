import '../models/item.dart';

// =============================================================================
// FILE 2: item_repository.dart
// Repository yang mengelola fetch kategori.
// Submit barang TIDAK dilakukan di sini — diserahkan ke PostItemNotifier
// yang memanggil itemsProvider langsung (agar barang baru masuk ke state
// global dan langsung muncul di HomeScreen).
//
// Pada aplikasi nyata, fetchCategories() akan memanggil GET /api/categories.
// =============================================================================

/// Repository bertanggung jawab sebagai sumber data kategori.
class ItemRepository {
  /// Simulasi delay jaringan (bisa diatur dari luar untuk testing).
  final Duration fetchDelay;

  /// Flag untuk memaksa error — berguna saat testing & demo.
  final bool simulateError;

  /// Flag untuk mensimulasikan data kosong.
  final bool simulateEmpty;

  const ItemRepository({
    this.fetchDelay = const Duration(seconds: 1),
    this.simulateError = false,
    this.simulateEmpty = false,
  });

  // ---------------------------------------------------------------------------
  // FETCH KATEGORI
  // Di aplikasi nyata: GET /api/categories
  // ---------------------------------------------------------------------------

  /// Mengambil daftar kategori barang.
  /// Memakai [kCategories] dari item.dart sebagai sumber data agar konsisten
  /// dengan data yang ditampilkan di seluruh aplikasi.
  Future<List<Category>> fetchCategories() async {
    // Simulasi latency jaringan
    await Future.delayed(fetchDelay);

    // ── KONDISI 4: Error state ──
    if (simulateError) {
      throw Exception('Gagal memuat data kategori. Periksa koneksi internet.');
    }

    // ── KONDISI 3: Empty state ──
    if (simulateEmpty) return [];

    // ── KONDISI 2: Data berhasil dimuat ──
    // Pakai kCategories yang sudah ada di item.dart — tidak duplikasi data.
    return kCategories;
  }
}
