import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';

/// Menyimpan riwayat chat per barang (key = itemId) selama sesi berjalan.
class ChatNotifier extends StateNotifier<Map<String, List<ChatMessage>>> {
  ChatNotifier() : super({});

  /// Inisialisasi thread bila belum ada. [requesterIsMe] menentukan sisi
  /// pengirim kartu barang + pesan pembuka.
  void ensureThread({
    required String itemId,
    required String itemTitle,
    required bool requesterIsMe,
  }) {
    if (state.containsKey(itemId)) return;
    state = {
      ...state,
      itemId: [
        ChatMessage(fromMe: requesterIsMe, isItemCard: true, time: '09:40'),
        ChatMessage(
          fromMe: requesterIsMe,
          text: 'Halo, saya ingin meminta barang ini: $itemTitle. Apakah masih tersedia? 🙏',
          time: '09:41',
        ),
        ChatMessage(
          fromMe: !requesterIsMe,
          text: 'Halo! Masih ada kok. Silakan ajukan pengambilannya ya 🙂',
          time: '09:43',
        ),
      ],
    };
  }

  void send(String itemId, String text) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final thread = List<ChatMessage>.of(state[itemId] ?? const []);
    thread.add(ChatMessage(fromMe: true, text: text, time: time));
    state = {...state, itemId: thread};
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, Map<String, List<ChatMessage>>>(
        (ref) => ChatNotifier());
