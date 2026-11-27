import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/chat_message.dart';
import '../models/item.dart';
import '../models/item_model.dart';
import '../providers/chat_provider.dart';
import '../providers/cloud_item_provider.dart';
import '../router/app_router.dart';
import '../services/firebase_auth_service.dart';
import '../theme/app_palette.dart';
import '../widgets/accessible_tap.dart';
import '../widgets/photo_placeholder.dart';

/// Layar inbox chat realtime berbasis Firestore — menampilkan semua
/// percakapan yang pernah terhubung, diurutkan dari yang paling baru.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final threadsState = ref.watch(chatThreadsProvider);
    final currentUid = ref.watch(currentFirebaseUidProvider) ?? '';
    final cloudItems = ref.watch(cloudItemsStreamProvider).valueOrNull ?? const [];
    final itemById = {for (final it in cloudItems) it.id: it};

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Semantics(
              header: true,
              child: Text(
                'Pesan',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: p.text),
              ),
            ),
          ),
          Divider(height: 1, color: p.border),
          Expanded(
            child: threadsState.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                    color: p.primary, semanticsLabel: 'Memuat daftar pesan'),
              ),
              error: (_, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Gagal memuat daftar pesan.',
                          style: TextStyle(color: p.textMuted)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(chatThreadsProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (threads) => threads.isEmpty
                  ? _empty(p)
                  : ListView.separated(
                      itemCount: threads.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: p.border, indent: 76),
                      itemBuilder: (_, i) {
                        final t = threads[i];
                        return _ThreadTile(
                          thread: t,
                          currentUid: currentUid,
                          itemModel: itemById[t.itemId],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(AppPalette p) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 56, color: p.textMuted),
              const SizedBox(height: 16),
              Text(
                'Belum ada percakapan',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: p.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Buka barang dan tekan tombol Chat\nuntuk memulai percakapan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.textMuted),
              ),
            ],
          ),
        ),
      );
}

class _ThreadTile extends ConsumerWidget {
  const _ThreadTile({
    required this.thread,
    required this.currentUid,
    this.itemModel,
  });

  final ChatThread thread;
  final String currentUid;
  final ItemModel? itemModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final peerName = thread.peerNameFor(currentUid);
    final unread = thread.unreadFor(currentUid);
    final hasUnread = unread > 0;
    final sentByMe = thread.lastSenderId == currentUid;
    final preview =
        sentByMe ? 'Kamu: ${thread.lastMessage}' : thread.lastMessage;
    final item = itemModel == null ? null : _toItem(itemModel!);

    return AccessibleTap(
      label: 'Buka chat dengan $peerName untuk barang ${thread.itemTitle}',
      onTap: () {
        context.push(AppRoutes.chat(
          thread.itemId,
          peerName,
          chatId: thread.chatId,
          requesterId: thread.requesterId,
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _avatar(peerName, p),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight:
                                hasUnread ? FontWeight.w800 : FontWeight.w600,
                            color: p.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        thread.lastTime,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: hasUnread ? p.accentText : p.textMuted,
                          fontWeight:
                              hasUnread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    itemModel?.title ?? thread.itemTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: p.accentText),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread ? p.text : p.textMuted,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _badge(unread, p),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (item != null) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                height: 44,
                child: PhotoPlaceholder(item: item, height: 44, radius: 8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Item _toItem(ItemModel data) => Item(
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
        pickupMethods: data.availablePickupMethods,
        address: data.areaLabel,
        condition: data.condition,
        listingType: data.listingType,
        price: data.price,
        imageUrl:
            data.imageBase64.isEmpty ? null : 'base64:${data.imageBase64}',
      );

  Widget _avatar(String name, AppPalette p) {
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: p.border),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: p.primary),
      ),
    );
  }

  Widget _badge(int count, AppPalette p) => Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: p.onAccent),
        ),
      );
}
