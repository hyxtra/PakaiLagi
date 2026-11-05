import 'dart:async';
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
// STRATEGI GAMBAR:
//   Firebase Storage membutuhkan Blaze plan (kartu kredit). Agar tetap gratis,
//   gambar di-encode menjadi string Base64 dan disimpan sebagai field di
//   Firestore. Gambar dikompres via image_picker (maxWidth + imageQuality)
//   agar tidak melebihi batas dokumen Firestore (1 MiB per dokumen).
//
// PRIVASI ALAMAT (ditegakkan juga oleh firestore.rules):
//   items/{itemId}                   publik: kelurahan & kota saja
//   items/{itemId}/private/location  privat: alamat lengkap + koordinat GPS,
//                                    dibaca pemilik & peminta yang diterima
//   profiles/{uid}                   privat: hanya pemilik akun
//
// ID PENGAJUAN:
//   pickupRequests/{itemId}_{requesterId}. ID deterministik ini mencegah
//   pengajuan ganda dan memungkinkan rules memeriksa status pengajuan peminta
//   tanpa query.
// =============================================================================

class FirebaseRepository {
  FirebaseRepository(this._firestore, this._authService);

  final FirebaseFirestore _firestore;
  final FirebaseAuthService _authService;

  static const String _itemsCollection = 'items';
  static const String _privateCollection = 'private';
  static const String _locationDoc = 'location';
  static const String _requestsCollection = 'pickupRequests';
  static const String _profilesCollection = 'profiles';
  static const String _notificationsCollection = 'notifications';

  /// ID dokumen pengajuan untuk pasangan barang + peminta.
  static String requestIdFor(String itemId, String requesterId) =>
      '${itemId}_$requesterId';

  DocumentReference<Map<String, dynamic>> _locationRef(String itemId) =>
      _firestore
          .collection(_itemsCollection)
          .doc(itemId)
          .collection(_privateCollection)
          .doc(_locationDoc);

  // ---------------------------------------------------------------------------
  // HELPER: Encode bytes gambar ke Base64
  // ---------------------------------------------------------------------------

  /// Encoding dilakukan di isolate terpisah (compute) agar UI tidak tersendat.
  Future<String> _encodeBytesToBase64(Uint8List bytes) async {
    return compute(_base64Encode, bytes);
  }

  static String _base64Encode(Uint8List bytes) => ImageBase64.encode(bytes);

  // ---------------------------------------------------------------------------
  // CREATE — Simpan barang baru ke Firestore
  // ---------------------------------------------------------------------------

  /// Menyimpan barang baru dalam satu batch:
  /// - `items/{id}` berisi data publik (tanpa alamat lengkap/koordinat)
  /// - `items/{id}/private/location` berisi alamat lengkap & koordinat
  ///
  /// Return: Document ID yang baru dibuat.
  Future<String> addItemToCloud({
    required String title,
    required String category,
    required String description,
    required Uint8List imageBytes,
    required String ownerName,
    required String fullAddress,
    required String kelurahan,
    required String kota,
    double? latitude,
    double? longitude,
  }) async {
    final donorId = (await _authService.ensureSignedIn()).uid;
    final imageBase64 = await _encodeBytesToBase64(imageBytes);

    final itemRef = _firestore.collection(_itemsCollection).doc();
    final batch = _firestore.batch();
    batch.set(itemRef, {
      'title': title,
      'category': category,
      'description': description,
      'imageBase64': imageBase64,
      'donorId': donorId,
      'ownerName': ownerName,
      'kelurahan': kelurahan,
      'kota': kota,
      'status': ItemStatusRules.available,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_locationRef(itemRef.id), {
      'address': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
    });
    await batch.commit();
    return itemRef.id;
  }

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  /// Stream realtime koleksi `items`, terbaru lebih dulu.
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

  /// Alamat lengkap barang. Rules menolak akses selain pemilik dan peminta
  /// yang diterima, jadi pemanggil wajib memeriksa hak akses lebih dulu.
  Stream<ItemPrivateLocation?> getItemPrivateLocation(String itemId) {
    return _locationRef(itemId).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : ItemPrivateLocation.fromMap(data);
    });
  }

  // ---------------------------------------------------------------------------
  // UPDATE / DELETE barang
  // ---------------------------------------------------------------------------

  /// Menghapus barang beserta dokumen lokasi privatnya. Subkoleksi tidak ikut
  /// terhapus otomatis oleh Firestore, jadi keduanya dihapus dalam satu batch.
  Future<void> deleteItem(String itemId) {
    final batch = _firestore.batch()
      ..delete(_locationRef(itemId))
      ..delete(_firestore.collection(_itemsCollection).doc(itemId));
    return batch.commit();
  }

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

  // ---------------------------------------------------------------------------
  // PENGAJUAN PENGAMBILAN
  // ---------------------------------------------------------------------------

  Future<void> createPickupRequest({
    required String itemId,
    required String method,
  }) async {
    final requesterId = (await _authService.ensureSignedIn()).uid;
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
    if (itemData['status'] != ItemStatusRules.available) {
      throw Exception('Barang ini sudah tidak tersedia.');
    }

    final requestRef = _firestore
        .collection(_requestsCollection)
        .doc(requestIdFor(itemId, requesterId));
    if ((await requestRef.get()).exists) {
      throw Exception('Kamu sudah mengajukan barang ini.');
    }

    final profile =
        await _firestore.collection(_profilesCollection).doc(requesterId).get();
    final requesterName = profile.data()?['name'] as String? ?? 'Pengguna';
    final itemTitle = itemData['title'] as String? ?? 'barang Anda';

    final batch = _firestore.batch()
      ..set(requestRef, {
        'itemId': itemId,
        'ownerId': ownerId,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'method': method,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(
          _firestore.collection(_notificationsCollection).doc(),
          _notificationData(
            recipientId: ownerId,
            senderName: requesterName,
            title: 'Pengajuan baru',
            body: '$requesterName ingin mengambil "$itemTitle".',
            itemId: itemId,
          ));
    await batch.commit();
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

  /// Pengajuan milik peminta untuk satu barang (null jika belum mengajukan).
  Stream<CloudPickupRequest?> getMyRequestForItem(
      String itemId, String requesterId) {
    return _firestore
        .collection(_requestsCollection)
        .doc(requestIdFor(itemId, requesterId))
        .snapshots()
        .map(
            (doc) => doc.exists ? CloudPickupRequest.fromFirestore(doc) : null);
  }

  /// Pengajuan untuk barang milik [ownerId]. Filter `ownerId` wajib ada agar
  /// query lolos rules (peminta lain tidak boleh melihat daftar ini).
  Stream<List<CloudPickupRequest>> getRequestsForItem(
      String itemId, String ownerId) {
    return _firestore
        .collection(_requestsCollection)
        .where('itemId', isEqualTo: itemId)
        .where('ownerId', isEqualTo: ownerId)
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
        'status': ItemStatusRules.reserved,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Notifikasi bersifat pelengkap dan TIDAK ditunggu: keputusan dianggap
    // selesai begitu batch di atas terkonfirmasi. Kegagalan notifikasi (mis.
    // pengajuan lama dengan ID acak yang tidak lolos rules) diabaikan.
    final itemTitle = itemData['title'] as String? ?? 'barang';
    unawaited(_firestore
        .collection(_notificationsCollection)
        .add(_notificationData(
          recipientId: requestData['requesterId'] as String? ?? '',
          senderName: itemData['ownerName'] as String? ?? 'Pemberi barang',
          title: accepted ? 'Pengajuan diterima' : 'Pengajuan ditolak',
          body: accepted
              ? 'Pengajuan Anda untuk "$itemTitle" telah diterima. Alamat lengkap kini dapat dilihat di detail barang.'
              : 'Pengajuan Anda untuk "$itemTitle" belum dapat diterima.',
          itemId: itemId,
        ))
        .then<void>((_) {}, onError: (Object _) {}));
  }

  // ---------------------------------------------------------------------------
  // NOTIFIKASI
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _notificationData({
    required String recipientId,
    required String senderName,
    required String title,
    required String body,
    required String itemId,
  }) =>
      {
        'recipientId': recipientId,
        'senderName': senderName,
        'title': title,
        'body': body,
        'itemId': itemId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Membutuhkan composite index (recipientId ASC, createdAt DESC) yang
  /// didefinisikan di firestore.indexes.json.
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

  // ---------------------------------------------------------------------------
  // PROFIL (privat)
  // ---------------------------------------------------------------------------

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
          kelurahan: data['kelurahan'] as String? ?? '',
          kota: data['kota'] as String? ?? '',
          latitude: (data['latitude'] as num?)?.toDouble(),
          longitude: (data['longitude'] as num?)?.toDouble(),
        );
      },
    );
  }

  /// Menyimpan profil pada dokumen yang identik dengan Firebase UID.
  /// Koordinat yang null dihapus dari dokumen agar tidak tertinggal koordinat
  /// lama yang tidak cocok dengan alamat baru.
  Future<void> saveMyProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String kelurahan,
    required String kota,
    double? latitude,
    double? longitude,
  }) async {
    final uid = (await _authService.ensureSignedIn()).uid;

    await _firestore.collection(_profilesCollection).doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'kelurahan': kelurahan,
      'kota': kota,
      'latitude': latitude ?? FieldValue.delete(),
      'longitude': longitude ?? FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

// =============================================================================
// PROVIDER DEFINITIONS
// =============================================================================

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseRepositoryProvider = Provider<FirebaseRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authService = ref.watch(firebaseAuthServiceProvider);
  return FirebaseRepository(firestore, authService);
});
