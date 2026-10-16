import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/firebase_repository.dart';
import '../models/item_model.dart';
import '../models/app_user.dart';
import '../models/cloud_pickup_request.dart';
import '../services/firebase_auth_service.dart';

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
final cloudItemsStreamProvider = StreamProvider<List<ItemModel>>((ref) {
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.getCloudItems();
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

final cloudRequestsForItemProvider =
    StreamProvider.family<List<CloudPickupRequest>, String>((ref, itemId) {
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.getRequestsForItem(itemId);
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
  const PublishSuccess(this.docId);
  final String docId;
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
  /// Return: true jika berhasil, false jika gagal.
  Future<bool> publishItem({
    required String title,
    required String category,
    required String description,
    required Uint8List imageBytes,
    required String ownerName,
  }) async {
    state = const PublishLoading();

    try {
      final docId = await _repository.addItemToCloud(
        title: title,
        category: category,
        description: description,
        imageBytes: imageBytes,
        ownerName: ownerName,
      );

      state = PublishSuccess(docId);
      // Reset ke idle setelah berhasil agar form bisa dipakai lagi
      await Future.delayed(const Duration(milliseconds: 300));
      state = const PublishIdle();
      return true;
    } catch (e) {
      state = PublishError(e.toString().replaceFirst('Exception: ', ''));
      return false;
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
