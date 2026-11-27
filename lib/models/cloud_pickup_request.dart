import 'package:cloud_firestore/cloud_firestore.dart';

class CloudPickupRequest {
  const CloudPickupRequest({
    required this.id,
    required this.itemId,
    required this.requesterId,
    required this.requesterName,
    required this.method,
    required this.status,
    this.ownerId = '',
    this.reason = '',
    this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String itemId;
  final String ownerId;
  final String requesterId;
  final String requesterName;
  final String method;
  final String status;
  final String reason;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  factory CloudPickupRequest.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CloudPickupRequest(
      id: doc.id,
      itemId: data['itemId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      requesterId: data['requesterId'] as String? ?? '',
      requesterName: data['requesterName'] as String? ?? 'Pengguna',
      method: data['method'] as String? ?? 'Tidak dicantumkan',
      status: data['status'] as String? ?? 'pending',
      reason: data['reason'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      decidedAt: _parseTimestamp(data['decidedAt']),
    );
  }

  static DateTime? _parseTimestamp(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
