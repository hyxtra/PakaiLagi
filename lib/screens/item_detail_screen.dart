import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/pickup_methods.dart';
import '../models/item.dart';
import '../providers/auth_provider.dart';
import '../providers/cloud_item_provider.dart';
import '../providers/items_provider.dart';
import '../providers/requests_provider.dart';
import '../repositories/firebase_repository.dart';
import '../services/firebase_auth_service.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../widgets/badges.dart';
import '../widgets/photo_placeholder.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localItem = ref.watch(itemByIdProvider(itemId));
    if (localItem != null) return _detailScaffold(context, ref, localItem);

    // Barang cloud tidak ada pada provider mock. Ambil langsung memakai
    // Firestore document ID yang diterima route.
    final cloudItem = ref.watch(cloudItemByIdProvider(itemId));
    return cloudItem.when(
      loading: () => Scaffold(
        backgroundColor: context.palette.bg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _notFoundScaffold(context),
      data: (data) {
        if (data == null) return _notFoundScaffold(context);
        return _detailScaffold(
            context,
            ref,
            Item(
              id: data.id,
              title: data.title,
              category: data.category,
              description: data.description,
              ownerId: data.donorId,
              ownerName: data.ownerName,
              ownerPhone: '',
              status: data.status == 'completed'
                  ? ItemStatus.completed
                  : data.status == 'reserved'
                      ? ItemStatus.reserved
                      : ItemStatus.available,
              swatch: const Color(0xFF2F6B4F),
              pickupMethods: const ['Ambil Sendiri'],
              address: data.address,
              imageUrl:
                  data.imageBytes == null ? null : 'base64:${data.imageBase64}',
            ),
            isCloudItem: true);
      },
    );
  }

  Scaffold _notFoundScaffold(BuildContext context) => Scaffold(
        backgroundColor: context.palette.bg,
        appBar: AppBar(),
        body: const Center(child: Text('Detail barang tidak dapat dimuat')),
      );

  Widget _detailScaffold(BuildContext context, WidgetRef ref, Item item,
      {bool isCloudItem = false}) {
    final p = context.palette;
    final user = ref.watch(authProvider);
    final firebaseUid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid;

    final ownedByMe = user != null && item.ownerId == user.id;
    final canDeleteCloudItem = isCloudItem && firebaseUid == item.ownerId;
    final available = item.status == ItemStatus.available;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    PhotoPlaceholder(
                        item: item, height: 280, radius: 0, large: true),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: SafeArea(
                        child: _circleButton(
                          Icons.arrow_back,
                          const Color(0xFF1E2621),
                          Colors.white.withValues(alpha: 0.92),
                          () => context.pop(),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CategoryBadge(category: item.category),
                        const SizedBox(width: 8),
                        StatusBadge(status: item.status),
                      ]),
                      const SizedBox(height: 14),
                      Text(item.title,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              color: p.text)),
                      const SizedBox(height: 20),
                      Text('Deskripsi',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: p.text)),
                      const SizedBox(height: 6),
                      Text(item.description,
                          style: TextStyle(
                              fontSize: 14.5,
                              height: 1.55,
                              color: p.textMuted)),
                      const SizedBox(height: 22),
                      Text('Pemberi Barang',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: p.text)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 23,
                              backgroundColor: p.surfaceAlt,
                              child: const Text('👤',
                                  style: TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.ownerName,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: p.text)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Icon(Icons.phone,
                                        size: 12, color: p.textMuted),
                                    const SizedBox(width: 4),
                                    Text(item.ownerPhone,
                                        style: TextStyle(
                                            fontSize: 13, color: p.textMuted)),
                                  ]),
                                ],
                              ),
                            ),
                            Icon(Icons.verified, size: 20, color: p.primary),
                          ],
                        ),
                      ),
                      if (!ownedByMe) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () => context
                                .push(AppRoutes.chat(item.id, item.ownerName)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.primary,
                              side: BorderSide(color: p.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon:
                                const Icon(Icons.chat_bubble_outline, size: 19),
                            label: const Text('Chat Pemberi',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canDeleteCloudItem)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDelete(context, ref, item.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus Barang',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            )
          else if (!ownedByMe)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: available
                        ? () => _openRequestSheet(context, ref, item,
                            isCloudItem: isCloudItem)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          available ? p.accent : const Color(0xFF9AA39C),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF9AA39C),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.card_giftcard, size: 20),
                    label: Text(
                        available
                            ? 'Ajukan Pengambilan'
                            : 'Barang Tidak Tersedia',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Barang'),
        content: const Text('Apakah Anda yakin ingin menghapus barang ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(firebaseRepositoryProvider).deleteItem(itemId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang berhasil dihapus.')));
      context.pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus barang. Coba lagi.')));
    }
  }

  Widget _circleButton(IconData icon, Color fg, Color bg, VoidCallback onTap) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
            width: 40, height: 40, child: Icon(icon, size: 20, color: fg)),
      ),
    );
  }

  void _openRequestSheet(BuildContext context, WidgetRef ref, Item item,
      {bool isCloudItem = false}) {
    final p = context.palette;
    final methods = item.pickupMethods.isNotEmpty
        ? item.pickupMethods
        : kPickupMethodInfo.map((e) => e.$2).toList();
    var selected = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                          color: p.border,
                          borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Metode Pengambilan',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: p.text)),
                  const SizedBox(height: 4),
                  Text('Pilih cara kamu ingin menerima barang ini.',
                      style: TextStyle(fontSize: 14, color: p.textMuted)),
                  const SizedBox(height: 18),
                  for (var i = 0; i < methods.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => setSheet(() => selected = i),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected == i ? p.surfaceAlt : p.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: selected == i ? p.primary : p.border,
                                width: selected == i ? 1.6 : 1),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(methods[i],
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: p.text)),
                              ),
                              Icon(
                                selected == i
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selected == i ? p.primary : p.border,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          if (isCloudItem) {
                            await ref
                                .read(firebaseRepositoryProvider)
                                .createPickupRequest(
                                  itemId: item.id,
                                  method: methods[selected],
                                );
                          } else {
                            final user = ref.read(authProvider);
                            if (user != null) {
                              ref.read(requestsProvider.notifier).addRequest(
                                    itemId: item.id,
                                    requesterId: user.id,
                                    requesterName: user.name,
                                    method: methods[selected],
                                    message:
                                        'Halo, saya berminat dengan barang ini.',
                                  );
                            }
                          }
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Pengajuan terkirim via "${methods[selected]}" 🎉')),
                          );
                        } catch (_) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Gagal mengirim pengajuan. Coba lagi.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Konfirmasi Pengajuan',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
