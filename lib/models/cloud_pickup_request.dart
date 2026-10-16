import 'package:cloud_firestore/cloud_firestore.dart';

class CloudPickupRequest {
  const CloudPickupRequest({
    required this.id,
    required this.itemId,
    required this.requesterId,
    required this.requesterName,
    required this.method,
    required this.status,
  });

  final String id;
  final String itemId;
  final String requesterId;
  final String requesterName;
  final String method;
  final String status;

  factory CloudPickupRequest.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CloudPickupRequest(
      id: doc.id,
      itemId: data['itemId'] as String? ?? '',
      requesterId: data['requesterId'] as String? ?? '',
      requesterName: data['requesterName'] as String? ?? 'Pengguna',
      method: data['method'] as String? ?? 'Ambil Sendiri',
      status: data['status'] as String? ?? 'pending',
    );
  }
}
