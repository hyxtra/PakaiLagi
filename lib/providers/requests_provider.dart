import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../models/pickup_request.dart';
import 'auth_provider.dart';

/// Sumber tunggal daftar pengajuan pengambilan barang.
class RequestsNotifier extends StateNotifier<List<PickupRequest>> {
  RequestsNotifier() : super(List.of(seedRequests));

  void addRequest({
    required String itemId,
    required String requesterId,
    required String requesterName,
    required String method,
    required String message,
  }) {
    state = [
      PickupRequest(
        id: 'r_${DateTime.now().millisecondsSinceEpoch}',
        itemId: itemId,
        requesterId: requesterId,
        requesterName: requesterName,
        method: method,
        message: message,
        time: 'Baru saja',
      ),
      ...state,
    ];
  }

  void decide(String requestId, RequestStatus status) {
    state = [
      for (final r in state) r.id == requestId ? r.copyWith(status: status) : r,
    ];
  }
}

final requestsProvider =
    StateNotifierProvider<RequestsNotifier, List<PickupRequest>>(
        (ref) => RequestsNotifier());

/// Pengajuan untuk satu barang tertentu.
final requestsForItemProvider =
    Provider.family<List<PickupRequest>, String>((ref, itemId) {
  return ref.watch(requestsProvider).where((r) => r.itemId == itemId).toList();
});

/// Pengajuan yang dibuat oleh user login (POV peminta — "Menunggu Persetujuan").
final myOutgoingRequestsProvider = Provider<List<PickupRequest>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return const [];
  return ref
      .watch(requestsProvider)
      .where((r) => r.requesterId == user.id && r.status == RequestStatus.pending)
      .toList();
});
