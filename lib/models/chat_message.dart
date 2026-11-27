import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Satu pesan percakapan yang tersimpan di `chats/{chatId}/messages/{id}`.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.fromMe,
    required this.time,
    this.id = '',
    this.senderId = '',
    this.senderName = '',
    this.text,
    this.isItemCard = false,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final bool fromMe;
  final String time;
  final String? text;
  final DateTime? createdAt;

  /// Bila true, pesan ini dirender sebagai kartu "Barang yang Diminta".
  final bool isItemCard;

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String currentUserId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawCreated = data['createdAt'];
    final createdAt = rawCreated is Timestamp ? rawCreated.toDate() : null;
    final senderId = data['senderId'] as String? ?? '';
    return ChatMessage(
      id: doc.id,
      senderId: senderId,
      senderName: data['senderName'] as String? ?? 'Pengguna',
      fromMe: senderId == currentUserId,
      text: data['text'] as String? ?? '',
      time: formatChatTime(createdAt),
      createdAt: createdAt,
    );
  }
}

/// Ringkasan satu room percakapan di Firestore `chats/{itemId}_{requesterId}`.
@immutable
class ChatThread {
  const ChatThread({
    required this.chatId,
    required this.itemId,
    required this.itemTitle,
    required this.ownerId,
    required this.ownerName,
    required this.requesterId,
    required this.requesterName,
    required this.lastMessage,
    required this.lastSenderId,
    this.lastMessageAt,
    this.ownerUnread = 0,
    this.requesterUnread = 0,
  });

  final String chatId;
  final String itemId;
  final String itemTitle;
  final String ownerId;
  final String ownerName;
  final String requesterId;
  final String requesterName;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastMessageAt;
  final int ownerUnread;
  final int requesterUnread;

  bool isOwner(String uid) => uid == ownerId;

  String peerNameFor(String uid) => isOwner(uid) ? requesterName : ownerName;

  String peerIdFor(String uid) => isOwner(uid) ? requesterId : ownerId;

  int unreadFor(String uid) => isOwner(uid) ? ownerUnread : requesterUnread;

  String get lastTime => formatChatTime(lastMessageAt);

  factory ChatThread.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawAt = data['lastMessageAt'];
    return ChatThread(
      chatId: doc.id,
      itemId: data['itemId'] as String? ?? '',
      itemTitle: data['itemTitle'] as String? ?? 'Barang',
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? 'Pemberi',
      requesterId: data['requesterId'] as String? ?? '',
      requesterName: data['requesterName'] as String? ?? 'Peminta',
      lastMessage: data['lastMessage'] as String? ?? '',
      lastSenderId: data['lastSenderId'] as String? ?? '',
      lastMessageAt: rawAt is Timestamp ? rawAt.toDate() : null,
      ownerUnread: (data['ownerUnread'] as num?)?.toInt() ?? 0,
      requesterUnread: (data['requesterUnread'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Format jam ringkas untuk gelembung chat dan daftar inbox.
String formatChatTime(DateTime? dt) {
  if (dt == null) return 'Baru saja';
  final now = DateTime.now();
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (sameDay) return '$hh:$mm';
  final yesterday = now.subtract(const Duration(days: 1));
  if (dt.year == yesterday.year &&
      dt.month == yesterday.month &&
      dt.day == yesterday.day) {
    return 'Kemarin';
  }
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}';
}
