import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notification_provider.dart';
import '../repositories/firebase_repository.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final notifications = ref.watch(cloudNotificationsProvider);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: p.surface,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
      ),
      body: notifications.when(
        loading: () => Center(
            child: CircularProgressIndicator(
                color: p.primary, semanticsLabel: 'Memuat notifikasi')),
        error: (_, __) => Center(
          child: Text('Gagal memuat notifikasi.',
              style: TextStyle(color: p.textMuted)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text('Belum ada pesan atau pengajuan baru.',
                  style: TextStyle(color: p.textMuted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final item = items[index];
              return Material(
                color: item.isRead ? p.surface : p.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: p.border),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: p.primary.withValues(alpha: 0.14),
                    child: Icon(Icons.chat_bubble_outline, color: p.primary),
                  ),
                  title: Text(item.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: p.text)),
                  subtitle: Text('${item.senderName}: ${item.body}',
                      style: TextStyle(color: p.textMuted)),
                  trailing: item.isRead
                      ? null
                      : Semantics(
                          label: 'Belum dibaca',
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                                color: p.primary, shape: BoxShape.circle),
                          ),
                        ),
                  onTap: () {
                    // Pindah halaman langsung; tanda "sudah dibaca" dikirim
                    // di belakang. Sebelumnya aplikasi menunggu server dulu,
                    // sehingga ketukan terasa tidak merespons (dan macet saat
                    // offline). Cache Firestore langsung menghapus titik.
                    if (!item.isRead) {
                      unawaited(ref
                          .read(firebaseRepositoryProvider)
                          .markNotificationAsRead(item.id)
                          .then<void>((_) {}, onError: (Object _) {}));
                    }
                    if (item.itemId.isNotEmpty) {
                      context.push(AppRoutes.itemDetail(item.itemId));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
