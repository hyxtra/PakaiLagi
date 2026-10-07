import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/items_provider.dart';
import '../repositories/item_repository.dart';
import 'item_state.dart';

// =============================================================================
// FILE 4: item_notifier.dart
// Riverpod StateNotifier yang mengelola state dan logika submit form.
//
// TANGGUNG JAWAB:
// 1. Memanggil repository untuk fetch data awal (kategori).
// 2. Memanggil itemsProvider untuk menambah barang baru ke state global
//    (agar barang langsung muncul di HomeScreen).
// 3. Mengubah state sesuai hasil operasi → UI otomatis rebuild.
//
// Notifier TIDAK tahu tentang Widget/UI sama sekali.
// =============================================================================

class PostItemNotifier extends StateNotifier<PostItemState> {
  PostItemNotifier(this._repository, this._ref)
      : super(const PostItemLoading());

  final ItemRepository _repository;
  final Ref _ref;

  // ---------------------------------------------------------------------------
  // LOAD DATA AWAL (KATEGORI)
  // ---------------------------------------------------------------------------

  /// Memuat daftar kategori dari repository.
  /// Menghasilkan state: [PostItemLoaded], [PostItemEmpty], atau [PostItemError].
  Future<void> loadCategories() async {
    // ── KONDISI 1: Set state loading → UI tampilkan spinner ──
    state = const PostItemLoading();

    try {
      final categories = await _repository.fetchCategories();

      if (categories.isEmpty) {
        // ── KONDISI 3: Data kosong → UI tampilkan empty state ──
        state = const PostItemEmpty();
      } else {
        // ── KONDISI 2: Data berhasil → UI tampilkan form ──
        state = PostItemLoaded(categories: categories);
      }
    } catch (e) {
      // ── KONDISI 4: Error → UI tampilkan pesan error + tombol retry ──
      state = PostItemError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ---------------------------------------------------------------------------
  // SUBMIT BARANG BARU
  // Dipanggil saat user menekan tombol "Kirim".
  // ---------------------------------------------------------------------------

  /// Menambah barang baru ke state global [itemsProvider].
  /// Mengubah [PostItemLoaded.isSubmitting] menjadi true selama proses.
  ///
  /// Return true jika berhasil, false jika gagal.
  Future<bool> submitItem({
    required String title,
    required String category,
    required String description,
    required List<String> pickupMethods,
    required String address,
    String? imageUrl,
  }) async {
    final currentState = state;

    // Guard: hanya bisa submit jika state saat ini adalah Loaded
    if (currentState is! PostItemLoaded) return false;

    // Guard: harus sudah login
    final user = _ref.read(authProvider);
    if (user == null) return false;

    // ── KONDISI 6: Set isSubmitting=true → tombol jadi loading & disabled ──
    state = currentState.copyWith(isSubmitting: true);

    try {
      // Simulasi delay jaringan (pada app nyata: POST ke API)
      await Future.delayed(const Duration(seconds: 1));

      // Tambahkan barang ke state global — langsung muncul di HomeScreen
      _ref.read(itemsProvider.notifier).addItem(
            title: title,
            category: category,
            description: description,
            pickupMethods: pickupMethods,
            address: address,
            ownerId: user.id,
            ownerName: user.name,
            ownerPhone: user.phone,
            imageUrl: imageUrl,
          );

      // Selesai: kembalikan isSubmitting ke false
      state = currentState.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      // Gagal: simpan error message, matikan loading
      state = currentState.copyWith(
        isSubmitting: false,
        submitError: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}

// =============================================================================
// PROVIDER DEFINITIONS
// =============================================================================

/// Provider untuk repository — bisa di-override saat testing.
final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return const ItemRepository();
});

/// Provider utama untuk PostItemNotifier.
/// AutoDispose: state dibersihkan saat screen tidak lagi digunakan.
final postItemNotifierProvider =
    StateNotifierProvider.autoDispose<PostItemNotifier, PostItemState>((ref) {
  final repository = ref.watch(itemRepositoryProvider);
  final notifier = PostItemNotifier(repository, ref);

  // Otomatis load kategori saat provider pertama kali dibuat
  notifier.loadCategories();

  return notifier;
});
