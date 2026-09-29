import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/item.dart';
import '../models/pickup_request.dart';
import '../providers/items_provider.dart';
import '../providers/requests_provider.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../widgets/badges.dart';
import '../widgets/photo_placeholder.dart';

class ManageRequestScreen extends ConsumerWidget {
  const ManageRequestScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final item = ref.watch(itemByIdProvider(itemId));
    final requests = ref.watch(requestsForItemProvider(itemId));

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Kelola Pengajuan',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        shape: Border(bottom: BorderSide(color: p.border)),
      ),
      body: item == null
          ? const Center(child: Text('Barang tidak ditemukan'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                _itemHeader(context, item),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Daftar Peminta',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.text)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: p.primarySoft, borderRadius: BorderRadius.circular(20)),
                      child: Text('${requests.length}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('Belum ada yang mengajukan barang ini.',
                          style: TextStyle(color: p.textMuted, fontSize: 14)),
                    ),
                  )
                else
                  for (final r in requests) _requestCard(context, ref, item, r),
              ],
            ),
    );
  }

  Widget _itemHeader(BuildContext context, Item item) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PhotoPlaceholder(item: item, height: 64, radius: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.text)),
                const SizedBox(height: 6),
                StatusBadge(status: item.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(BuildContext context, WidgetRef ref, Item item, PickupRequest r) {
    final p = context.palette;
    final decided = r.status != RequestStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: p.surfaceAlt,
                child: const Text('👤', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.requesterName,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.text)),
                    const SizedBox(height: 2),
                    Text(r.time, style: TextStyle(fontSize: 12, color: p.textMuted)),
                  ],
                ),
              ),
              _statusChip(context, r.status),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: p.surfaceAlt, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping_outlined, size: 14, color: p.textMuted),
                const SizedBox(width: 6),
                Text(r.method, style: TextStyle(fontSize: 12.5, color: p.text, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(r.message, style: TextStyle(fontSize: 13.5, color: p.textMuted, height: 1.45)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.chat(item.id, r.requesterName)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.primary,
                    side: BorderSide(color: p.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 17),
                  label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              if (!decided) ...[
                const SizedBox(width: 10),
                _iconAction(context, Icons.close, p.danger, () {
                  ref.read(requestsProvider.notifier).decide(r.id, RequestStatus.rejected);
                }),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(requestsProvider.notifier).decide(r.id, RequestStatus.accepted);
                      ref.read(itemsProvider.notifier).setStatus(item.id, ItemStatus.reserved);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Pengajuan ${r.requesterName} disetujui ✅')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.primary,
                      foregroundColor: p.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check, size: 17),
                    label: const Text('Terima', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconAction(BuildContext context, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 46,
      height: 42,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Icon(icon, size: 19),
      ),
    );
  }

  Widget _statusChip(BuildContext context, RequestStatus status) {
    final p = context.palette;
    late final Color bg;
    late final Color fg;
    late final String label;
    switch (status) {
      case RequestStatus.pending:
        bg = p.surfaceAlt;
        fg = p.textMuted;
        label = 'Menunggu';
        break;
      case RequestStatus.accepted:
        bg = p.primarySoft;
        fg = p.primary;
        label = 'Diterima';
        break;
      case RequestStatus.rejected:
        bg = p.danger.withValues(alpha: 0.14);
        fg = p.danger;
        label = 'Ditolak';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}
