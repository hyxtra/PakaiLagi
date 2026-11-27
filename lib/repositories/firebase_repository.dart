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
import '../models/chat_message.dart';
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
  static const String _chatsCollection = 'chats';
  static const String _messagesCollection = 'messages';

  /// ID dokumen pengajuan untuk pasangan barang + peminta.
  static String requestIdFor(String itemId, String requesterId) =>
      '${itemId}_$requesterId';

  /// ID dokumen room chat untuk pasangan barang + peminta.
  static String chatIdFor(String itemId, String requesterId) =>
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
    required List<String> pickupMethods,
    double? latitude,
    double? longitude,
    List<Uint8List> additionalImageBytes = const [],
    String condition = 'Layak Pakai',
    String listingType = 'gratis',
    int price = 0,
  }) async {
    // Cek ukuran SEBELUM mengirim: server menolak foto yang lewat batas dengan
    // pesan "Akses ditolak", yang menyesatkan pengguna.
    final allPhotoBytes = [imageBytes, ...additionalImageBytes];
    if (allPhotoBytes.length > ImageBase64.maxPhotoCount) {
      throw Exception('Pilih maksimal 5 foto barang.');
    }
    final encodedLength = allPhotoBytes.fold<int>(
        0, (total, bytes) => total + ImageBase64.encodedLength(bytes.length));
    final hasMultiplePhotos = allPhotoBytes.length > 1;
    final photoTooLarge = hasMultiplePhotos
        ? allPhotoBytes.any((bytes) =>
            ImageBase64.encodedLength(bytes.length) >=
            ImageBase64.maxPhotoEncodedLength)
        : !ImageBase64.fitsFirestoreLimit(imageBytes.length);
    if (photoTooLarge ||
        (hasMultiplePhotos &&
            encodedLength > ImageBase64.maxGalleryEncodedLength)) {
      throw Exception('Ukuran foto terlalu besar untuk diunggah bersama. '
          'Pilih foto lain atau kurangi jumlah foto.');
    }
    final donorId = (await _authService.ensureSignedIn()).uid;
    final encodedPhotos =
        await Future.wait(allPhotoBytes.map(_encodeBytesToBase64));
    final imageBase64 = encodedPhotos.first;

    final itemRef = _firestore.collection(_itemsCollection).doc();
    final batch = _firestore.batch();
    batch.set(itemRef, {
      'title': title,
      'category': category,
      'description': description,
      'imageBase64': imageBase64,
      if (encodedPhotos.length > 1)
        'additionalImages': encodedPhotos.skip(1).toList(growable: false),
      'donorId': donorId,
      'ownerName': ownerName,
      'kelurahan': kelurahan,
      'kota': kota,
      'pickupMethods': pickupMethods,
      'condition': condition,
      'listingType': listingType,
      'price': price,
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
  ///
  /// Bila [from] diberikan, perubahannya harus transisi yang sah menurut
  /// [ItemStatusRules.canTransition] (mis. reserved -> completed).
  /// Saat barang dinyatakan selesai, penerima yang disetujui ikut diberi
  /// notifikasi di latar belakang.
  Future<void> updateItemStatus(
    String itemId,
    String status, {
    String? from,
    String? acceptedRequesterId,
    String? itemTitle,
    String? ownerName,
  }) async {
    if (!ItemStatusRules.isValid(status)) {
      throw ArgumentError.value(status, 'status', 'Status item tidak valid');
    }
    if (from != null &&
        !ItemStatusRules.canTransition(from: from, to: status)) {
      throw Exception('Perubahan status dari "$from" ke "$status" tidak '
          'diizinkan.');
    }
    await _firestore
        .collection(_itemsCollection)
        .doc(itemId)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});

    if (status == ItemStatusRules.completed &&
        acceptedRequesterId != null &&
        acceptedRequesterId.isNotEmpty) {
      final title = (itemTitle != null && itemTitle.isNotEmpty)
          ? itemTitle
          : 'barang';
      unawaited(_firestore
          .collection(_notificationsCollection)
          .add(_notificationData(
            recipientId: acceptedRequesterId,
            senderName: (ownerName != null && ownerName.isNotEmpty)
                ? ownerName
                : 'Pemberi barang',
            title: 'Serah terima selesai',
            body: 'Transaksi untuk "$title" telah dinyatakan selesai.',
            itemId: itemId,
          ))
          .then<void>((_) {}, onError: (Object _) {}));
    }
  }

  // ---------------------------------------------------------------------------
  // PENGAJUAN PENGAMBILAN
  // ---------------------------------------------------------------------------

  Future<void> createPickupRequest({
    required String itemId,
    required String method,
    String reason = '',
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
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
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

  /// Seluruh pengajuan yang pernah dibuat [requesterId] (pending, diterima,
  /// ditolak), diurutkan dari yang terbaru di klien agar tidak butuh composite index.
  Stream<List<CloudPickupRequest>> getMyOutgoingRequests(String requesterId) {
    return _firestore
        .collection(_requestsCollection)
        .where('requesterId', isEqualTo: requesterId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(CloudPickupRequest.fromFirestore).toList();
      list.sort((a, b) {
        final ta = a.decidedAt ?? a.createdAt;
        final tb = b.decidedAt ?? b.createdAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return -1;
        if (tb == null) return 1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  /// Seluruh pengajuan yang masuk untuk barang-barang milik [ownerId].
  Stream<List<CloudPickupRequest>> getRequestsForOwner(String ownerId) {
    return _firestore
        .collection(_requestsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(CloudPickupRequest.fromFirestore).toList();
      list.sort((a, b) {
        final ta = a.decidedAt ?? a.createdAt;
        final tb = b.decidedAt ?? b.createdAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return -1;
        if (tb == null) return 1;
        return tb.compareTo(ta);
      });
      return list;
    });
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

    // Saat satu pengajuan diterima, barang hanya untuk satu peminta. Pengajuan
    // lain yang masih menunggu ikut ditolak dalam batch yang sama, supaya
    // tidak menggantung selamanya dan tombol Terima-nya tidak menyesatkan.
    final autoRejected = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    if (accepted) {
      final ownerId = requestData['ownerId'] as String? ?? '';
      if (ownerId.isNotEmpty) {
        final others = await _firestore
            .collection(_requestsCollection)
            .where('itemId', isEqualTo: itemId)
            .where('ownerId', isEqualTo: ownerId)
            .get();
        autoRejected.addAll(others.docs.where(
            (doc) => doc.id != requestId && doc.data()['status'] == 'pending'));
      }
    }

    final batch = _firestore.batch();
    batch.update(_firestore.collection(_requestsCollection).doc(requestId), {
      'status': accepted ? 'accepted' : 'rejected',
      'decidedAt': FieldValue.serverTimestamp(),
    });
    for (final other in autoRejected) {
      batch.update(other.reference, {
        'status': 'rejected',
        'decidedAt': FieldValue.serverTimestamp(),
      });
    }
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

    // Beri tahu peminta lain yang otomatis ditolak (juga tidak ditunggu).
    for (final other in autoRejected) {
      unawaited(_firestore
          .collection(_notificationsCollection)
          .add(_notificationData(
            recipientId: other.data()['requesterId'] as String? ?? '',
            senderName: itemData['ownerName'] as String? ?? 'Pemberi barang',
            title: 'Pengajuan ditolak',
            body: '"$itemTitle" sudah diberikan kepada peminta lain.',
            itemId: itemId,
          ))
          .then<void>((_) {}, onError: (Object _) {}));
    }
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

  /// Profil satu kali baca saat sesi email/password dipulihkan atau masuk.
  Future<AppUser?> getMyProfileOnce(String uid) async {
    final doc = await _firestore.collection(_profilesCollection).doc(uid).get();
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

  // ---------------------------------------------------------------------------
  // CHAT REALTIME (Firestore)
  // ---------------------------------------------------------------------------

  /// Daftar seluruh thread percakapan yang diikuti [uid], diurutkan pesan
  /// terbaru paling atas di sisi klien agar tidak butuh composite index.
  Stream<List<ChatThread>> getMyChatThreads(String uid) {
    return _firestore
        .collection(_chatsCollection)
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(ChatThread.fromFirestore).toList();
      list.sort((a, b) {
        final ta = a.lastMessageAt;
        final tb = b.lastMessageAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return -1; // write lokal belum dikonfirmasi -> atas
        if (tb == null) return 1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  /// Stream satu dokumen room chat. Mengembalikan null bila percakapan belum dimulai.
  Stream<ChatThread?> getChatThreadById(String chatId) {
    return _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists ? ChatThread.fromFirestore(doc) : null);
  }

  /// Stream pesan dalam satu room, urut kronologis dari lama ke baru.
  Stream<List<ChatMessage>> getChatMessages(
    String chatId, {
    required String currentUserId,
  }) {
    return _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .collection(_messagesCollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ChatMessage.fromFirestore(doc, currentUserId: currentUserId))
            .toList());
  }

  /// Mengirim pesan ke room `{itemId}_{requesterId}`.
  /// Jika room belum ada di Firestore, room dibuat sekaligus dalam satu batch.
  Future<void> sendChatMessage({
    required String chatId,
    required String itemId,
    required String itemTitle,
    required String ownerId,
    required String ownerName,
    required String requesterId,
    required String requesterName,
    required String text,
    bool? knownThreadExists,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > 1000) {
      throw Exception('Pesan maksimal 1000 karakter.');
    }

    final user = await _authService.ensureSignedIn();
    final senderId = user.uid;
    final profile =
        await _firestore.collection(_profilesCollection).doc(senderId).get();
    final senderName = (profile.data()?['name'] as String?)?.trim();
    final effectiveSenderName = (senderName != null && senderName.isNotEmpty)
        ? senderName
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : (senderId == ownerId ? ownerName : requesterName));

    final chatRef = _firestore.collection(_chatsCollection).doc(chatId);
    final msgRef = chatRef.collection(_messagesCollection).doc();
    final exists = knownThreadExists ?? (await chatRef.get()).exists;
    final senderIsOwner = senderId == ownerId;

    final batch = _firestore.batch();
    if (!exists) {
      batch.set(chatRef, {
        'itemId': itemId,
        'itemTitle': itemTitle.isNotEmpty ? itemTitle : 'Barang',
        'ownerId': ownerId,
        'ownerName': ownerName.isNotEmpty ? ownerName : 'Pemberi',
        'requesterId': requesterId,
        'requesterName':
            requesterName.isNotEmpty ? requesterName : 'Pengguna',
        'participants': [ownerId, requesterId],
        'lastMessage': trimmed,
        'lastSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'ownerUnread': senderIsOwner ? 0 : 1,
        'requesterUnread': senderIsOwner ? 1 : 0,
      });
    } else {
      batch.update(chatRef, {
        'lastMessage': trimmed,
        'lastSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        if (senderIsOwner) ...{
          'ownerUnread': 0,
          'requesterUnread': FieldValue.increment(1),
        } else ...{
          'requesterUnread': 0,
          'ownerUnread': FieldValue.increment(1),
        },
      });
    }
    batch.set(msgRef, {
      'senderId': senderId,
      'senderName': effectiveSenderName,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Menandai seluruh pesan di room sebagai sudah dibaca untuk sisi pemanggil.
  Future<void> markChatAsRead({
    required String chatId,
    required bool isOwner,
  }) {
    return _firestore.collection(_chatsCollection).doc(chatId).update({
      isOwner ? 'ownerUnread' : 'requesterUnread': 0,
    });
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
