import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/chat_message.dart';
import '../models/item.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/items_provider.dart';
import '../theme/app_palette.dart';
import '../widgets/photo_placeholder.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.itemId, required this.peerName});

  final String itemId;
  final String peerName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  static const _quickReplies = [
    'Masih tersedia?',
    'Bisa ambil hari ini?',
    'Terima kasih! 🙏',
    'Sesuai lokasi ya',
  ];

  @override
  void initState() {
    super.initState();
    // Inisialisasi thread setelah frame pertama (butuh akses provider item).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final item = ref.read(itemByIdProvider(widget.itemId));
      final user = ref.read(authProvider);
      final requesterIsMe = item == null || user == null ? true : item.ownerId != user.id;
      ref.read(chatProvider.notifier).ensureThread(
            itemId: widget.itemId,
            itemTitle: item?.title ?? 'Barang',
            requesterIsMe: requesterIsMe,
          );
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    ref.read(chatProvider.notifier).send(widget.itemId, t);
    _composer.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = ref.watch(itemByIdProvider(widget.itemId));
    final messages = ref.watch(chatProvider)[widget.itemId] ?? const <ChatMessage>[];

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: p.surfaceAlt,
              child: const Text('👤', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                  Text('Online', style: TextStyle(fontSize: 11.5, color: p.primary)),
                ],
              ),
            ),
          ],
        ),
        shape: Border(bottom: BorderSide(color: p.border)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                if (m.isItemCard) return _itemRefCard(item, m.fromMe);
                return _bubble(m);
              },
            ),
          ),
          _quickRepliesBar(),
          _composerBar(),
        ],
      ),
    );
  }

  Widget _itemRefCard(Item? item, bool fromMe) {
    final p = context.palette;
    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.primary.withValues(alpha: 0.5), width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BARANG YANG DIMINTA',
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: p.primary)),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 52,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item == null
                        ? Container(height: 52, color: p.surfaceAlt)
                        : PhotoPlaceholder(item: item, height: 52, radius: 10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item?.title ?? 'Barang',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: p.text)),
                      const SizedBox(height: 2),
                      Text(item?.category ?? '-',
                          style: TextStyle(fontSize: 12, color: p.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final p = context.palette;
    final mine = m.fromMe;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? p.bubbleMine : p.bubbleTheirs,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.text ?? '',
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: mine ? Colors.white : p.text)),
            const SizedBox(height: 3),
            Text(m.time,
                style: TextStyle(
                    fontSize: 10.5,
                    color: mine ? Colors.white70 : p.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _quickRepliesBar() {
    final p = context.palette;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _send(_quickReplies[i]),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            child: Text(_quickReplies[i],
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.text)),
          ),
        ),
      ),
    );
  }

  Widget _composerBar() {
    final p = context.palette;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                style: TextStyle(color: p.text),
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan…',
                  hintStyle: TextStyle(color: p.textMuted),
                  filled: true,
                  fillColor: p.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: p.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _send(_composer.text),
                child: const SizedBox(
                    width: 46, height: 46, child: Icon(Icons.send, color: Colors.white, size: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
