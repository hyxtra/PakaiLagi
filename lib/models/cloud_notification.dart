import 'package:cloud_firestore/cloud_firestore.dart';

/// Pesan aktivitas yang disimpan di Firestore untuk satu penerima.
class CloudNotification {
  const CloudNotification({
    required this.id,
    required this.recipientId,
    required this.senderName,
    required this.title,
    required this.body,
    required this.itemId,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String recipientId;
  final String senderName;
  final String title;
  final String body;
  final String itemId;
  final bool isRead;
  final DateTime? createdAt;

  factory CloudNotification.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];
    return CloudNotification(
      id: doc.id,
      recipientId: data['recipientId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Pengguna',
      title: data['title'] as String? ?? 'Aktivitas PakaiLagi',
      body: data['body'] as String? ?? '',
      itemId: data['itemId'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
