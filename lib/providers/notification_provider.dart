import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cloud_notification.dart';
import '../repositories/firebase_repository.dart';
import '../services/firebase_auth_service.dart';

/// Notifikasi Firestore milik akun Firebase yang sedang aktif.
final cloudNotificationsProvider =
    StreamProvider<List<CloudNotification>>((ref) {
  final firebaseUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (firebaseUser == null) return Stream.value(const []);
  return ref
      .watch(firebaseRepositoryProvider)
      .getMyNotifications(firebaseUser.uid);
});

/// Jumlah pesan/notifikasi yang belum dibaca untuk badge pada Beranda.
final unreadCloudNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(cloudNotificationsProvider).maybeWhen(
      data: (items) => items.where((item) => !item.isRead).length,
      orElse: () => 0);
});
