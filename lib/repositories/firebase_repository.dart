import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_auth_service.dart';
import '../models/item_model.dart';
import '../models/app_user.dart';
import '../models/cloud_pickup_request.dart';
import '../models/cloud_notification.dart';
import '../business/image_base64.dart';
import '../business/item_status_rules.dart';

// =============================================================================
// firebase_repository.dart
// Repository layer untuk semua operasi Firebase (100% Cloud-only).
//
// TANGGUNG JAWAB:
//   - Encode gambar (bytes) ke Base64 (tanpa Firebase Storage)
//   - Simpan data barang ke Firestore koleksi `items`
//   - Ambil daftar barang publik dari Firestore secara realtime (stream)
//
// STRATEGI GAMBAR:
//   Firebase Storage membutuhkan Blaze plan (kartu kredit). Agar tetap gratis,
//   kita encode gambar menjadi string Base64 lalu simpan langsung sebagai field
//   di Firestore. Gambar dikompres terlebih dahulu via image_picker (maxWidth)
//   agar ukurannya tidak melebihi batas dokumen Firestore (1 MB per doc).
//
// CATATAN KOMPATIBILITAS WEB:
//   Menggunakan Uint8List (bytes) sebagai input, BUKAN dart:io File,
//   agar kompatibel dengan semua platform (Web, Android, iOS).
//
// KOLEKSI FIRESTORE: `items`
// KOLOM:
//   - title        (String)
//   - category     (String)
//   - description  (String)
//   - imageBase64  (String) — foto dalam format Base64
//   - donorId      (String) — UID user dari Firebase Auth
//   - status       (String) — 'available' saat baru dibuat
//   - createdAt    (Timestamp) — server timestamp
// =============================================================================

class FirebaseRepository {
  FirebaseRepository(this._firestore, this._authService);

  final FirebaseFirestore _firestore;
  final FirebaseAuthService _authService;

  /// Nama koleksi Firestore untuk barang.
  static const String _itemsCollection = 'items';
  static const String _requestsCollection = 'pickupRequests';
  static const String _profilesCollection = 'profiles';
  static const String _notificationsCollection = 'notifications';

  // ---------------------------------------------------------------------------
  // HELPER: Encode bytes gambar ke Base64
  // ---------------------------------------------------------------------------

  /// Meng-encode byte gambar menjadi string Base64.
  /// Proses encoding dilakukan di isolate terpisah (compute) agar tidak
  /// memblokir UI thread.
  Future<String> _encodeBytesToBase64(Uint8List bytes) async {
    return compute(_base64Encode, bytes);
  }

  /// Fungsi top-level yang bisa dijalankan di isolate via `compute`.
  static String _base64Encode(Uint8List bytes) => ImageBase64.encode(bytes);

  // ---------------------------------------------------------------------------
  // CREATE — Simpan barang baru ke Firestore
  // ---------------------------------------------------------------------------

  /// Proses lengkap publish barang ke Firestore:
  /// 1. Encode gambar (bytes) ke Base64
  /// 2. Dapatkan donorId dari Firebase Auth
  /// 3. Simpan ke Firestore koleksi `items`
  ///
  /// [imageBytes] — Uint8List dari image_picker (XFile.readAsBytes()).
  /// Menggunakan bytes agar kompatibel Web, Android, dan iOS.
  ///
  /// Return: Document ID yang baru dibuat.
  /// Throws: Exception jika user belum login atau proses gagal.
  Future<String> addItemToCloud({
    required String title,
    required String category,
    required String description,
    required Uint8List imageBytes,
    required String ownerName,
  }) async {
    // 1. Pastikan user sudah login
    final donorId = _authService.currentUid;
    if (donorId == null) {
      throw Exception('User belum login. Silakan login terlebih dahulu.');
    }

    // 2. Encode gambar ke Base64
    final imageBase64 = await _encodeBytesToBase64(imageBytes);

    // 3. Susun data dokumen
    final itemData = <String, dynamic>{
      'title': title,
      'category': category,
      'description': description,
      'imageBase64': imageBase64,
      'donorId': donorId,
      'ownerName': ownerName,
      'status': 'available',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // 4. Simpan ke Firestore
    final docRef = await _firestore.collection(_itemsCollection).add(itemData);
    return docRef.id;
  }

  // ---------------------------------------------------------------------------
  // READ — Ambil daftar barang dari Firestore (Realtime Stream)
  // ---------------------------------------------------------------------------

  /// Mengembalikan stream realtime dari koleksi `items`,
  /// diurutkan berdasarkan `createdAt` terbaru (descending).
  ///
  /// Menggunakan `snapshots()` agar setiap perubahan di Firestore
  /// otomatis terpropagasi ke UI tanpa perlu refresh manual.
  Stream<List<ItemModel>> getCloudItems() {
    return _firestore
        .collection(_itemsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ItemModel.fromFirestore).toList());
  }

  /// Stream barang yang dimiliki akun Firebase aktif.
  Stream<List<ItemModel>> getMyItems([String? ownerUid]) {
    final donorId = ownerUid ?? _authService.currentUid;
    if (donorId == null) return Stream.value(const []);
    return _firestore
        .collection(_itemsCollection)
        .where('donorId', isEqualTo: donorId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ItemModel.fromFirestore).toList());
  }

  /// Stream satu dokumen agar layar detail tidak bergantung pada state lokal.
  Stream<ItemModel?> getItemById(String itemId) {
    return _firestore
        .collection(_itemsCollection)
        .doc(itemId)
        .snapshots()
        .map((doc) => doc.exists ? ItemModel.fromFirestore(doc) : null);
  }

  Future<void> deleteItem(String itemId) =>
      _firestore.collection(_itemsCollection).doc(itemId).delete();

  /// UPDATE status barang melalui Cloud Firestore.
  Future<void> updateItemStatus(String itemId, String status) {
    if (!ItemStatusRules.isValid(status)) {
      throw ArgumentError.value(status, 'status', 'Status item tidak valid');
    }
    return _firestore
        .collection(_itemsCollection)
        .doc(itemId)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> createPickupRequest({
    required String itemId,
    required String method,
  }) async {
    final requesterId = _authService.currentUid;
    if (requesterId == null) {
      throw Exception('User belum login. Silakan coba lagi.');
    }
    final item =
        await _firestore.collection(_itemsCollection).doc(itemId).get();
    final itemData = item.data();
    if (itemData == null) {
      throw Exception('Barang tidak ditemukan.');
    }
    final ownerId = itemData['donorId'] as String?;
    if (ownerId == null || ownerId.isEmpty) {
      throw Exception('Pemilik barang tidak valid.');
    }
    if (ownerId == requesterId) {
      throw Exception('Tidak dapat mengajukan barang sendiri.');
    }

    final profile =
        await _firestore.collection(_profilesCollection).doc(requesterId).get();
    final requesterName = profile.data()?['name'] as String? ?? 'Pengguna';

    await _firestore.collection(_requestsCollection).add({
      'itemId': itemId,
      'ownerId': ownerId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'method': method,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _createNotification(
      recipientId: ownerId,
      senderName: requesterName,
      title: 'Pengajuan baru',
      body:
          '$requesterName ingin mengambil "${itemData['title'] as String? ?? 'barang Anda'}".',
      itemId: itemId,
    );
  }

  Stream<List<String>> getMyOutgoingRequestItemIds(String requesterId) {
    return _firestore
        .collection(_requestsCollection)
        .where('requesterId', isEqualTo: requesterId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['itemId'] as String? ?? '')
            .where((itemId) => itemId.isNotEmpty)
            .toList());
  }

  Stream<List<CloudPickupRequest>> getRequestsForItem(String itemId) {
    return _firestore
        .collection(_requestsCollection)
        .where('itemId', isEqualTo: itemId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(CloudPickupRequest.fromFirestore).toList());
  }

  Future<void> decidePickupRequest({
    required String requestId,
    required String itemId,
    required bool accepted,
  }) async {
    final requestDoc =
        await _firestore.collection(_requestsCollection).doc(requestId).get();
    final requestData = requestDoc.data();
    if (requestData == null) throw Exception('Pengajuan tidak ditemukan.');
    final itemDoc =
        await _firestore.collection(_itemsCollection).doc(itemId).get();
    final itemData = itemDoc.data() ?? const <String, dynamic>{};
    final batch = _firestore.batch();
    batch.update(_firestore.collection(_requestsCollection).doc(requestId), {
      'status': accepted ? 'accepted' : 'rejected',
      'decidedAt': FieldValue.serverTimestamp(),
    });
    if (accepted) {
      batch.update(_firestore.collection(_itemsCollection).doc(itemId), {
        'status': 'reserved',
      });
    }
    await batch.commit();
    await _createNotification(
      recipientId: requestData['requesterId'] as String? ?? '',
      senderName: itemData['ownerName'] as String? ?? 'Pemberi barang',
      title: accepted ? 'Pengajuan diterima' : 'Pengajuan ditolak',
      body: accepted
          ? 'Pengajuan Anda untuk "${itemData['title'] as String? ?? 'barang'}" telah diterima.'
          : 'Pengajuan Anda untuk "${itemData['title'] as String? ?? 'barang'}" belum dapat diterima.',
      itemId: itemId,
    );
  }

  Future<void> _createNotification({
    required String recipientId,
    required String senderName,
    required String title,
    required String body,
    required String itemId,
  }) {
    if (recipientId.isEmpty) return Future.value();
    return _firestore.collection(_notificationsCollection).add({
      'recipientId': recipientId,
      'senderName': senderName,
      'title': title,
      'body': body,
      'itemId': itemId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CloudNotification>> getMyNotifications([String? recipientId]) {
    final uid = recipientId ?? _authService.currentUid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(_notificationsCollection)
        .where('recipientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(CloudNotification.fromFirestore).toList());
  }

  Future<void> markNotificationAsRead(String notificationId) {
    return _firestore
        .collection(_notificationsCollection)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Stream<AppUser?> getMyProfile(String uid) {
    return _firestore.collection(_profilesCollection).doc(uid).snapshots().map(
      (doc) {
        final data = doc.data();
        if (data == null) return null;
        return AppUser(
          id: doc.id,
          name: data['name'] as String? ?? 'Pengguna',
          email: data['email'] as String? ?? '',
          phone: data['phone'] as String? ?? '',
          address: data['address'] as String? ?? '',
        );
      },
    );
  }

  /// Menyimpan profil pada dokumen yang identik dengan Firebase UID.
  Future<void> saveMyProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
  }) async {
    var uid = _authService.currentUid;
    if (uid == null) {
      final user = await _authService.signInAnonymously();
      uid = user?.uid;
    }
    if (uid == null) throw Exception('Gagal mendapatkan akun Firebase.');

    await _firestore.collection(_profilesCollection).doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

// =============================================================================
// PROVIDER DEFINITIONS
// =============================================================================

/// Provider untuk FirebaseFirestore instance.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Provider untuk FirebaseRepository.
/// Menghubungkan Firestore + AuthService.
final firebaseRepositoryProvider = Provider<FirebaseRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authService = ref.watch(firebaseAuthServiceProvider);
  return FirebaseRepository(firestore, authService);
});
