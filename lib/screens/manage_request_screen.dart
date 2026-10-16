import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cloud_pickup_request.dart';
import '../models/item.dart';
import '../models/item_model.dart';
import '../providers/cloud_item_provider.dart';
import '../repositories/firebase_repository.dart';
import '../theme/app_palette.dart';
import '../widgets/badges.dart';
import '../widgets/photo_placeholder.dart';

class ManageRequestScreen extends ConsumerWidget {
  const ManageRequestScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final itemState = ref.watch(cloudItemByIdProvider(itemId));
    final requestsState = ref.watch(cloudRequestsForItemProvider(itemId));
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Kelola Pengajuan'),
        backgroundColor: p.surface,
        foregroundColor: p.text,
      ),
      body: itemState.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: p.primary)),
        error: (_, __) => const Center(child: Text('Gagal memuat barang.')),
        data: (model) {
          if (model == null) {
            return const Center(child: Text('Barang tidak ditemukan'));
          }
          final item = _toItem(model);
          return requestsState.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: p.primary)),
            error: (_, __) =>
                const Center(child: Text('Gagal memuat pengajuan.')),
            data: (requests) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _header(context, item),
                const SizedBox(height: 20),
                Text('Daftar Peminta (${requests.length})',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: p.text)),
                const SizedBox(height: 12),
                if (requests.isEmpty)
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Belum ada yang mengajukan barang ini.',
                        style: TextStyle(color: p.textMuted)),
                  )),
                for (final request in requests)
                  _requestCard(context, ref, item, request),
              ],
            ),
          );
        },
      ),
    );
  }

  Item _toItem(ItemModel item) => Item(
        id: item.id,
        title: item.title,
        category: item.category,
        description: item.description,
        ownerId: item.donorId,
        ownerName: item.ownerName,
        ownerPhone: '',
        status: item.status == 'reserved'
            ? ItemStatus.reserved
            : ItemStatus.available,
        swatch: const Color(0xFF2F6B4F),
        pickupMethods: const ['Ambil Sendiri'],
        address: item.address,
        imageUrl:
            item.imageBase64.isEmpty ? null : 'base64:${item.imageBase64}',
      );

  Widget _header(BuildContext context, Item item) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border)),
      child: Row(children: [
        SizedBox(width: 64, child: PhotoPlaceholder(item: item, height: 64)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title,
              style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 6),
          StatusBadge(status: item.status),
        ])),
      ]),
    );
  }

  Widget _requestCard(BuildContext context, WidgetRef ref, Item item,
      CloudPickupRequest request) {
    final p = context.palette;
    final pending = request.status == 'pending';
    final label = request.status == 'accepted'
        ? 'Diterima'
        : request.status == 'rejected'
            ? 'Ditolak'
            : 'Menunggu';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              backgroundColor: p.surfaceAlt,
              child: const Icon(Icons.person_outline)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(request.requesterName,
                  style:
                      TextStyle(fontWeight: FontWeight.w800, color: p.text))),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color:
                      request.status == 'accepted' ? p.primary : p.textMuted)),
        ]),
        const SizedBox(height: 12),
        Text('Metode: ${request.method}', style: TextStyle(color: p.textMuted)),
        if (pending) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () =>
                        _decide(context, ref, request, item.id, false),
                    style: OutlinedButton.styleFrom(foregroundColor: p.danger),
                    child: const Text('Tolak'))),
            const SizedBox(width: 10),
            Expanded(
                child: ElevatedButton(
                    onPressed: item.status == ItemStatus.available
                        ? () => _decide(context, ref, request, item.id, true)
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: p.onPrimary),
                    child: const Text('Terima'))),
          ]),
        ],
      ]),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref,
      CloudPickupRequest request, String itemId, bool accepted) async {
    try {
      await ref.read(firebaseRepositoryProvider).decidePickupRequest(
          requestId: request.id, itemId: itemId, accepted: accepted);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(accepted ? 'Pengajuan diterima.' : 'Pengajuan ditolak.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui pengajuan.')));
      }
    }
  }
}
