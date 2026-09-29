import 'package:flutter/foundation.dart';

enum RequestStatus { pending, accepted, rejected }

@immutable
class PickupRequest {
  const PickupRequest({
    required this.id,
    required this.itemId,
    required this.requesterId,
    required this.requesterName,
    required this.method,
    required this.message,
    required this.time,
    this.status = RequestStatus.pending,
  });

  final String id;
  final String itemId;
  final String requesterId;
  final String requesterName;
  final String method;
  final String message;
  final String time;
  final RequestStatus status;

  PickupRequest copyWith({RequestStatus? status}) {
    return PickupRequest(
      id: id,
      itemId: itemId,
      requesterId: requesterId,
      requesterName: requesterName,
      method: method,
      message: message,
      time: time,
      status: status ?? this.status,
    );
  }
}
