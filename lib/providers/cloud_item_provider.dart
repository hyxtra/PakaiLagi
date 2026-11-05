import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/firebase_repository.dart';
import '../models/item_model.dart';
import '../models/app_user.dart';
import '../models/cloud_pickup_request.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_messages.dart';

export '../services/user_messages.dart' show WriteOutcome;

// =============================================================================
// cloud_item_provider.dart
// Riverpod provider yang mengelola state barang dari Firestore (100% Cloud).
//
// PROVIDER YANG DISEDIAKAN:
//   1. cloudItemsStreamProvider — StreamProvider yang subscribe ke
//      `getCloudItems()` realtime dari Firestore. UI otomatis rebuild
//      saat ada data baru.
//   2. CloudItemNotifier — StateNotifier untuk menangani proses CREATE
//      (addItemToCloud) dengan state loading/success/error.
//
// ARSITEKTUR: UI → Provider → Repository → Firestore
// =============================================================================

// =============================================================================
// 1. STREAM PROVIDER — Mendengarkan daftar barang realtime dari Firestore
// =============================================================================

/// StreamProvider yang subscribe ke Firestore `items` collection.
/// UI menggunakan `ref.watch(cloudItemsStreamProvider)` untuk mendapat
/// AsyncValue<List<Map<String, dynamic>>> yang otomatis rebuild realtime.
///
/// Firestore rules mewajibkan login, jadi stream baru dibuka setelah sesi
/// Firebase (anonim) dipastikan ada. Tombol "Coba lagi" yang meng-invalidate
/// provider ini sekaligus mengulang proses login bila sebelumnya gagal.
final cloudItemsStreamProvider = StreamProvider<List<ItemModel>>((ref) async* {
  await ref.watch(firebaseAuthServiceProvider).ensureSignedIn();
  yield* ref.watch(firebaseRepositoryProvider).getCloudItems();
});

/// Daftar barang milik user Firebase aktif, realtime dari Firestore.
final myCloudItemsStreamProvider = StreamProvider<List<ItemModel>>((ref) {
  // Jika provider dibuat sebelum login anonim Firebase selesai, stream kosong
  // sebelumnya akan dibatalkan dan dibuat ulang saat UID tersedia.
  final firebaseUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (firebaseUser == null) return Stream.value(const []);

  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.getMyItems(firebaseUser.uid);
});

/// Detail satu barang berdasarkan Firestore document ID.
final cloudItemByIdProvider =
    StreamProvider.family<ItemModel?, String>((ref, id) {
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.getItemById(id);
});

/// ID barang cloud yang sedang diajukan oleh user Firebase aktif.
final myOutgoingCloudRequestItemIdsProvider =
    StreamProvider<List<String>>((ref) {
  final firebaseUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (firebaseUser == null) return Stream.value(const []);
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.getMyOutgoingRequestItemIds(firebaseUser.uid);
});

/// Profil akun yang tersimpan di Firestore untuk Firebase UID aktif.
final cloudProfileProvider = StreamProvider<AppUser?>((ref) {
  final firebaseUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (firebaseUser == null) return Stream.value(null);
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.getMyProfile(firebaseUser.uid);
});

/// Daftar pengajuan untuk barang milik user aktif (POV pemberi).
final cloudRequestsForItemProvider =
    StreamProvider.family<List<CloudPickupRequest>, String>((ref, itemId) {
  final firebaseUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (firebaseUser == null) return Stream.value(const []);
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.getRequestsForItem(itemId, firebaseUser.uid);
});

/// Pengajuan user aktif untuk satu barang (POV peminta). Null jika belum ada.
final myCloudRequestForItemProvider =
    StreamProvider.family<CloudPickupRequest?, String>((ref, itemId) {
  final firebaseUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (firebaseUser == null) return Stream.value(null);
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.getMyRequestForItem(itemId, firebaseUser.uid);
});

/// Alamat lengkap barang. Hanya di-watch bila user adalah pemilik atau
/// peminta yang diterima; selain itu rules menolak dan provider berisi error.
final cloudItemPrivateLocationProvider =
    StreamProvider.family<ItemPrivateLocation?, String>((ref, itemId) {
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.getItemPrivateLocation(itemId);
});

// =============================================================================
// 2. STATE NOTIFIER — Mengelola proses publish (Create) barang ke Firestore
// =============================================================================

/// State untuk proses publish barang.
/// Menggunakan sealed class agar UI bisa pattern-match semua kemungkinan.
sealed class PublishState {
  const PublishState();
}

class PublishIdle extends PublishState {
  const PublishIdle();
}

class PublishLoading extends PublishState {
  const PublishLoading();
}

class PublishSuccess extends PublishState {
  const PublishSuccess(this.outcome);

  /// [WriteOutcome.queued] bila server belum mengonfirmasi dalam batas waktu
  /// (perangkat offline/lambat); Firestore mengirimnya otomatis nanti.
  final WriteOutcome outcome;
}

class PublishError extends PublishState {
  const PublishError(this.message);
  final String message;
}

/// Notifier yang mengelola state proses publish barang ke Firestore.
/// Hanya bertanggung jawab untuk operasi CREATE — bukan READ
/// (read ditangani oleh cloudItemsStreamProvider).
class CloudItemNotifier extends StateNotifier<PublishState> {
  CloudItemNotifier(this._repository) : super(const PublishIdle());

  final FirebaseRepository _repository;

  /// Publish barang baru ke Firestore.
  /// 1. Set state → Loading (UI tampilkan spinner)
  /// 2. Encode gambar & kirim ke Firestore
  /// 3. Set state → Success atau Error
  ///
  /// [imageBytes] — Uint8List dari XFile.readAsBytes() (kompatibel web + mobile)
  ///
  /// Return: hasil tulis bila berhasil, atau null bila gagal (pesan error
  /// tersedia di [PublishError.message]).
  Future<WriteOutcome?> publishItem({
    required String title,
    required String category,
    required String description,
    required Uint8List imageBytes,
    required String ownerName,
    required AppUser pickupAddress,
  }) async {
    state = const PublishLoading();

    try {
      // Alamat lengkap & koordinat masuk ke dokumen privat; dokumen publik
      // hanya menerima kelurahan & kota (lihat FirebaseRepository).
      // awaitWrite: saat offline tombol tidak berputar selamanya.
      final outcome = await awaitWrite(
        _repository.addItemToCloud(
          title: title,
          category: category,
          description: description,
          imageBytes: imageBytes,
          ownerName: ownerName,
          fullAddress: pickupAddress.address.trim(),
          kelurahan: pickupAddress.kelurahan.trim(),
          kota: pickupAddress.kota.trim(),
          latitude: pickupAddress.latitude,
          longitude: pickupAddress.longitude,
        ),
        timeout: const Duration(seconds: 10),
      );

      state = PublishSuccess(outcome);
      // Reset ke idle setelah berhasil agar form bisa dipakai lagi
      await Future.delayed(const Duration(milliseconds: 300));
      state = const PublishIdle();
      return outcome;
    } catch (e) {
      state = PublishError(friendlyError(e,
          fallback:
              'Gagal memposting barang. Periksa koneksi lalu coba lagi.'));
      return null;
    }
  }

  /// Reset state ke Idle (dipanggil jika perlu reset manual).
  void reset() => state = const PublishIdle();
}

// =============================================================================
// PROVIDER DEFINITION
// =============================================================================

/// Provider utama untuk CloudItemNotifier.
/// UI menggunakan `ref.watch(cloudItemNotifierProvider)` untuk mendapat
/// PublishState yang menggambarkan proses upload saat ini.
final cloudItemNotifierProvider =
    StateNotifierProvider<CloudItemNotifier, PublishState>((ref) {
  final repository = ref.watch(firebaseRepositoryProvider);
  return CloudItemNotifier(repository);
});
