import 'package:flutter/foundation.dart' hide Category;

import '../models/item.dart';

// =============================================================================
// FILE 3: item_state.dart
// Class state yang merepresentasikan semua kemungkinan kondisi UI.
// Menggunakan pola "sealed class" (union type) agar setiap kondisi
// memiliki tipe data eksplisit — Widget bisa melakukan pattern matching.
// =============================================================================

/// Base state — sealed agar compiler memastikan semua subclass ditangani
/// di switch/if-else (exhaustiveness check).
@immutable
sealed class PostItemState {
  const PostItemState();
}

// ── KONDISI 1: Initial loading ──
// State saat data awal (daftar kategori) sedang dimuat dari repository.
// UI menampilkan spinner/loading indicator.
class PostItemLoading extends PostItemState {
  const PostItemLoading();
}

// ── KONDISI 2: Data berhasil dimuat ──
// State saat daftar kategori berhasil didapat, form siap ditampilkan.
// Berisi data kategori + state submit (untuk kondisi 6).
class PostItemLoaded extends PostItemState {
  const PostItemLoaded({
    required this.categories,
    this.isSubmitting = false,
    this.submitError,
  });

  /// Daftar kategori yang berhasil dimuat dari repository.
  /// Memakai model [Category] dari item.dart agar konsisten dengan kCategories.
  final List<Category> categories;

  /// ── KONDISI 6: Loading saat proses submit ──
  /// True saat form sedang dikirim ke server.
  /// UI: tombol berubah menjadi loading indicator dan di-disable.
  final bool isSubmitting;

  /// Pesan error jika submit gagal (opsional).
  final String? submitError;

  /// Helper untuk membuat salinan state dengan perubahan tertentu.
  PostItemLoaded copyWith({
    List<Category>? categories,
    bool? isSubmitting,
    String? submitError,
  }) {
    return PostItemLoaded(
      categories: categories ?? this.categories,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: submitError,
    );
  }
}

// ── KONDISI 3: Empty state ──
// State saat data kategori berhasil dimuat TAPI hasilnya kosong.
// UI menampilkan pesan informatif bahwa belum ada kategori.
class PostItemEmpty extends PostItemState {
  const PostItemEmpty();
}

// ── KONDISI 4: Error state ──
// State saat terjadi kesalahan saat fetch data awal.
// UI menampilkan pesan error + tombol "Coba Lagi" (retry).
class PostItemError extends PostItemState {
  const PostItemError(this.message);

  /// Pesan error untuk ditampilkan ke user.
  final String message;
}
