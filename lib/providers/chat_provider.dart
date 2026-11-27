import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../repositories/firebase_repository.dart';
import '../services/firebase_auth_service.dart';

// =============================================================================
// chat_provider.dart
// Provider Riverpod berbasis Cloud Firestore untuk fitur Chat & Inbox.
// Memantau firebaseAuthStateProvider agar pergantian akun otomatis membatalkan
// stream akun lama dan memuat percakapan akun baru.
// =============================================================================

/// Daftar seluruh percakapan user Firebase aktif, terbaru di urutan teratas.
final chatThreadsProvider = StreamProvider<List<ChatThread>>((ref) {
  final firebaseUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (firebaseUser == null) return Stream.value(const []);
  return ref.watch(firebaseRepositoryProvider).getMyChatThreads(firebaseUser.uid);
});

/// Detail metadata satu room chat `{itemId}_{requesterId}`.
/// Bernilai null bila percakapan belum pernah dimulai.
final chatThreadByIdProvider =
    StreamProvider.autoDispose.family<ChatThread?, String>((ref, chatId) {
  final firebaseUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (firebaseUser == null) return Stream.value(null);
  return ref.watch(firebaseRepositoryProvider).getChatThreadById(chatId);
});

/// Stream pesan realtime di dalam satu room chat.
final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, chatId) {
  final firebaseUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
  if (firebaseUser == null) return Stream.value(const []);
  return ref
      .watch(firebaseRepositoryProvider)
      .getChatMessages(chatId, currentUserId: firebaseUser.uid);
});

/// Total pesan belum dibaca di seluruh percakapan user aktif (badge nav bar).
final unreadCountProvider = Provider<int>((ref) {
  final uid = ref.watch(currentFirebaseUidProvider);
  if (uid == null) return 0;
  return ref.watch(chatThreadsProvider).maybeWhen(
        data: (threads) =>
            threads.fold<int>(0, (sum, t) => sum + t.unreadFor(uid)),
        orElse: () => 0,
      );
});
