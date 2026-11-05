import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pickup_methods.dart';
import '../models/cloud_pickup_request.dart';
import '../models/item.dart';
import '../models/item_model.dart';
import '../providers/cloud_item_provider.dart';
import '../repositories/firebase_repository.dart';
import '../services/user_messages.dart';
import '../theme/app_palette.dart';
import '../widgets/badges.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/progress_dialog.dart';

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
        loading: () => Center(
            child: CircularProgressIndicator(
                color: p.primary, semanticsLabel: 'Memuat barang')),
        error: (_, __) => const Center(child: Text('Gagal memuat barang.')),
        data: (model) {
          if (model == null) {
            return const Center(child: Text('Barang tidak ditemukan'));
          }
          final item = _toItem(model);
          return requestsState.when(
            loading: () => Center(
                child: CircularProgressIndicator(
                    color: p.primary, semanticsLabel: 'Memuat pengajuan')),
            error: (_, __) =>
                const Center(child: Text('Gagal memuat pengajuan.')),
            data: (requests) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _header(context, item),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text('Daftar Peminta (${requests.length})',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: p.text)),
                ),
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
        // Sebelumnya 'completed' terbaca sebagai available sehingga tombol
        // Terima aktif untuk barang yang sudah selesai.
        status: item.status == 'completed'
            ? ItemStatus.completed
            : item.status == 'reserved'
                ? ItemStatus.reserved
                : ItemStatus.available,
        swatch: const Color(0xFF2F6B4F),
        pickupMethods: kPickupMethodNames,
        address: item.areaLabel,
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
                        _decide(context, ref, request, item, false),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: p.danger,
                        minimumSize: const Size.fromHeight(48)),
                    child: Text('Tolak',
                        semanticsLabel:
                            'Tolak pengajuan ${request.requesterName}'))),
            const SizedBox(width: 10),
            Expanded(
                child: ElevatedButton(
                    onPressed: item.status == ItemStatus.available
                        ? () => _decide(context, ref, request, item, true)
                        : null,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: p.primary,
                        foregroundColor: p.onPrimary),
                    child: Text('Terima',
                        semanticsLabel:
                            'Terima pengajuan ${request.requesterName}'))),
          ]),
          // Menjelaskan kenapa tombol Terima nonaktif.
          if (item.status != ItemStatus.available) ...[
            const SizedBox(height: 8),
            Text(
              'Barang sudah direservasi untuk peminta lain, jadi pengajuan '
              'ini hanya bisa ditolak.',
              style: TextStyle(fontSize: 12.5, color: p.textMuted),
            ),
          ],
        ],
      ]),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref,
      CloudPickupRequest request, Item item, bool accepted) async {
    final p = context.palette;
    final name = request.requesterName;
    // Keputusan tidak bisa diubah (dikunci firestore.rules), jadi minta
    // konfirmasi dulu.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(accepted ? 'Terima Pengajuan?' : 'Tolak Pengajuan?'),
        content: Text(accepted
            ? 'Barang "${item.title}" akan direservasi untuk $name, dan '
                'alamat lengkap penjemputan dibagikan kepadanya. Keputusan ini '
                'tidak bisa diubah.'
            : 'Pengajuan $name untuk "${item.title}" akan ditolak. Keputusan '
                'ini tidak bisa diubah.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                  foregroundColor: accepted ? p.primary : p.danger),
              child: Text(accepted ? 'Terima' : 'Tolak')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = AppMessenger.of(context);
    try {
      final outcome = await runWithProgress(
        context,
        message: accepted ? 'Menerima pengajuan…' : 'Menolak pengajuan…',
        task: () => awaitWrite(
            ref.read(firebaseRepositoryProvider).decidePickupRequest(
                requestId: request.id, itemId: item.id, accepted: accepted),
            timeout: const Duration(seconds: 12)),
      );
      final done = accepted
          ? 'Pengajuan $name diterima. Barang kini berstatus disetujui.'
          : 'Pengajuan $name ditolak.';
      messenger.result(outcome, done: done);
    } catch (error) {
      showAppSnackBar(
          messenger,
          friendlyError(error,
              fallback: 'Gagal memperbarui pengajuan. Coba lagi.'),
          isError: true);
    }
  }
}
