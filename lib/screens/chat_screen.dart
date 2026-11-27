import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../business/share_formatter.dart';
import '../models/chat_message.dart';
import '../models/item.dart';
import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/cloud_item_provider.dart';
import '../providers/items_provider.dart';
import '../repositories/firebase_repository.dart';
import '../router/app_router.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_messages.dart';
import '../theme/app_palette.dart';
import '../widgets/accessible_tap.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/progress_dialog.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.itemId,
    required this.peerName,
    this.chatId,
    this.requesterId,
  });

  final String itemId;
  final String peerName;
  final String? chatId;
  final String? requesterId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  int _lastMessageCount = 0;
  bool _markReadQueued = false;

  static const _quickReplies = [
    'Masih tersedia?',
    'Bisa ambil hari ini?',
    'Lokasi tepatnya di mana ya?',
    'Terima kasih! 🙏',
  ];

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String? _resolveChatId(String? currentUid) {
    final explicit = widget.chatId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final reqId = widget.requesterId?.trim();
    if (reqId != null && reqId.isNotEmpty) {
      return FirebaseRepository.chatIdFor(widget.itemId, reqId);
    }
    if (currentUid != null && currentUid.isNotEmpty) {
      return FirebaseRepository.chatIdFor(widget.itemId, currentUid);
    }
    return null;
  }

  /// Mengambil ItemModel dari detail stream, atau fallback instan dari cache
  /// feed agar judul & foto sampul langsung tampil tanpa jeda kosong.
  ItemModel? _findCloudItem(WidgetRef ref) {
    final direct = ref.watch(cloudItemByIdProvider(widget.itemId)).valueOrNull;
    if (direct != null) return direct;
    final feed = ref.watch(cloudItemsStreamProvider).valueOrNull;
    if (feed != null) {
      for (final it in feed) {
        if (it.id == widget.itemId) return it;
      }
    }
    final mine = ref.watch(myCloudItemsStreamProvider).valueOrNull;
    if (mine != null) {
      for (final it in mine) {
        if (it.id == widget.itemId) return it;
      }
    }
    return null;
  }

  Item? _resolveItem(Item? localItem, ItemModel? cloudItem) {
    if (localItem != null) return localItem;
    if (cloudItem == null) return null;
    return Item(
      id: cloudItem.id,
      title: cloudItem.title,
      category: cloudItem.category,
      description: cloudItem.description,
      ownerId: cloudItem.donorId,
      ownerName: cloudItem.ownerName,
      ownerPhone: '',
      status: cloudItem.status == 'completed'
          ? ItemStatus.completed
          : cloudItem.status == 'reserved'
              ? ItemStatus.reserved
              : ItemStatus.available,
      swatch: const Color(0xFF2F6B4F),
      pickupMethods: cloudItem.availablePickupMethods,
      address: cloudItem.areaLabel,
      condition: cloudItem.condition,
      listingType: cloudItem.listingType,
      price: cloudItem.price,
      imageUrl: cloudItem.imageBase64.isEmpty
          ? null
          : 'base64:${cloudItem.imageBase64}',
    );
  }

  void _scheduleMarkRead(String chatId, ChatThread thread, String currentUid) {
    if (_markReadQueued || thread.unreadFor(currentUid) <= 0) return;
    _markReadQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markReadQueued = false;
      unawaited(ref
          .read(firebaseRepositoryProvider)
          .markChatAsRead(chatId: chatId, isOwner: thread.isOwner(currentUid))
          .then<void>((_) {}, onError: (Object _) {}));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(
    String rawText, {
    required String? chatId,
    required ChatThread? thread,
    required ItemModel? cloudItem,
    required String? currentUid,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;

    final messenger = AppMessenger.of(context);
    if (chatId == null || currentUid == null || currentUid.isEmpty) {
      showAppSnackBar(messenger, 'Sesi akun belum siap. Coba sesaat lagi.',
          isError: true);
      return;
    }

    final profile = ref.read(cloudProfileProvider).valueOrNull;
    final authUser = ref.read(authProvider);
    final myName = (profile?.name.trim().isNotEmpty == true)
        ? profile!.name.trim()
        : (authUser?.name.trim().isNotEmpty == true
            ? authUser!.name.trim()
            : 'Pengguna');

    final ownerId = thread?.ownerId ?? cloudItem?.donorId ?? '';
    final ownerName =
        thread?.ownerName ?? cloudItem?.ownerName ?? widget.peerName;
    final itemTitle = thread?.itemTitle ?? cloudItem?.title ?? 'Barang';

    final String requesterId;
    final String requesterName;
    if (thread != null) {
      requesterId = thread.requesterId;
      requesterName = thread.requesterName;
    } else if (widget.requesterId != null && widget.requesterId!.isNotEmpty) {
      requesterId = widget.requesterId!;
      requesterName = requesterId == currentUid ? myName : widget.peerName;
    } else {
      requesterId = currentUid;
      requesterName = myName;
    }

    if (ownerId.isEmpty || requesterId.isEmpty) {
      showAppSnackBar(
        messenger,
        'Data barang masih dimuat. Tunggu sebentar lalu coba lagi.',
        isError: true,
      );
      return;
    }
    if (ownerId == requesterId) {
      showAppSnackBar(
        messenger,
        'Tidak dapat mengirim pesan ke barang milik sendiri.',
        isError: true,
      );
      return;
    }

    setState(() => _sending = true);
    final previousDraft = _composer.text;
    if (rawText == _composer.text) {
      _composer.clear();
    }

    try {
      await awaitWrite(
        ref.read(firebaseRepositoryProvider).sendChatMessage(
              chatId: chatId,
              itemId: widget.itemId,
              itemTitle: itemTitle,
              ownerId: ownerId,
              ownerName: ownerName,
              requesterId: requesterId,
              requesterName: requesterName,
              text: text,
              knownThreadExists: thread != null,
            ),
        timeout: const Duration(seconds: 10),
      );
      _scrollToBottom();
    } catch (error) {
      if (mounted && _composer.text.isEmpty && previousDraft.isNotEmpty) {
        _composer.text = previousDraft;
      }
      showAppSnackBar(
        messenger,
        friendlyError(error, fallback: 'Gagal mengirim pesan. Coba lagi.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final currentUid = ref.watch(currentFirebaseUidProvider);
    final chatId = _resolveChatId(currentUid);

    final localItem = ref.watch(itemByIdProvider(widget.itemId));
    final cloudItemAsync = ref.watch(cloudItemByIdProvider(widget.itemId));
    final cloudItem = _findCloudItem(ref);
    final item = _resolveItem(localItem, cloudItem);

    final threadAsync = chatId == null
        ? const AsyncValue<ChatThread?>.loading()
        : ref.watch(chatThreadByIdProvider(chatId));
    final thread = threadAsync.valueOrNull;

    if (chatId != null && thread != null && currentUid != null) {
      _scheduleMarkRead(chatId, thread, currentUid);
    }

    // Hanya subscribe subkoleksi messages bila room chat sudah ada di Firestore.
    final messagesAsync = (chatId != null && thread != null)
        ? ref.watch(chatMessagesProvider(chatId))
        : const AsyncValue<List<ChatMessage>>.data([]);

    final messages = messagesAsync.valueOrNull ?? const <ChatMessage>[];
    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      if (messages.isNotEmpty) _scrollToBottom();
    }

    final displayPeerName = (thread != null && currentUid != null)
        ? thread.peerNameFor(currentUid)
        : widget.peerName;
    final displayTitle = item?.title ?? thread?.itemTitle ?? 'Barang';
    final isOwner = currentUid != null &&
        ((cloudItem != null && cloudItem.donorId == currentUid) ||
            (thread != null && thread.ownerId == currentUid));

    // Item 0 di daftar chat adalah kartu konteks barang ala Shopee; setelah itu
    // diikuti daftar pesan (atau petunjuk mulai obrolan bila belum ada pesan).
    final itemCount = 1 + (messages.isEmpty ? 1 : messages.length);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop()),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: p.surfaceAlt,
              child: Text(
                displayPeerName.isNotEmpty
                    ? displayPeerName.trim()[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: p.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(displayPeerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w800)),
                  Text(displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: p.textMuted)),
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
            child: threadAsync.isLoading && thread == null
                ? Center(child: CircularProgressIndicator(color: p.primary))
                : (threadAsync.hasError || messagesAsync.hasError)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                friendlyError(
                                  threadAsync.error ??
                                      messagesAsync.error ??
                                      Exception(),
                                  fallback: 'Gagal memuat pesan.',
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: p.textMuted),
                              ),
                              if (chatId != null) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ref.invalidate(
                                        chatThreadByIdProvider(chatId));
                                    ref.invalidate(
                                        chatMessagesProvider(chatId));
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Coba lagi'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: itemCount,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return _shopeeItemContextCard(
                              item: item,
                              fallbackTitle: displayTitle,
                              isLoadingItem:
                                  item == null && cloudItemAsync.isLoading,
                              isOwner: isOwner,
                            );
                          }
                          if (messages.isEmpty) {
                            return _emptyConversationHint(displayPeerName, p);
                          }
                          return _bubble(messages[i - 1], displayPeerName);
                        },
                      ),
          ),
          _quickRepliesBar(
            chatId: chatId,
            thread: thread,
            cloudItem: cloudItem,
            currentUid: currentUid,
          ),
          _composerBar(
            chatId: chatId,
            thread: thread,
            cloudItem: cloudItem,
            currentUid: currentUid,
          ),
        ],
      ),
    );
  }

  /// Kartu konteks barang bergaya Shopee ("Kamu menanyakan barang ini") yang
  /// langsung tampil di dalam percakapan beserta foto sampul, harga, & status.
  Widget _shopeeItemContextCard({
    required Item? item,
    required String fallbackTitle,
    required bool isLoadingItem,
    required bool isOwner,
  }) {
    final p = context.palette;
    final headerText =
        isOwner ? 'Peminta menanyakan barang ini' : 'Kamu menanyakan barang ini';
    final priceText = item == null
        ? 'Memuat detail barang…'
        : ShareFormatter.priceLabel(
            listingType: item.listingType,
            price: item.price,
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Expanded(
                child: Text(
                  headerText,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
              ),
              if (item != null)
                GestureDetector(
                  onTap: () => context.push(AppRoutes.itemDetail(widget.itemId)),
                  child: Text(
                    'Lihat Barang ›',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Kotak abu/hangat berisi foto sampul + judul + harga + status (mirip Shopee)
          InkWell(
            onTap: item == null
                ? null
                : () => context.push(AppRoutes.itemDetail(widget.itemId)),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item != null
                          ? PhotoPlaceholder(item: item, height: 64, radius: 10)
                          : Container(
                              color: p.surfaceAlt,
                              alignment: Alignment.center,
                              child: isLoadingItem
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: p.primary),
                                    )
                                  : Icon(Icons.inventory_2_outlined,
                                      size: 24, color: p.textMuted),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item?.title ?? fallbackTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item != null
                              ? '$priceText • ${item.condition}'
                              : priceText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: p.textMuted),
                        ),
                        if (item != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.status.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: p.statusColor(item.status),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (item != null) ...[
            const SizedBox(height: 10),
            _metaRow('Kategori', item.category, p),
            if (item.address.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              _metaRow('Lokasi Area', item.address, p),
            ],
          ],
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value, AppPalette p) => Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ),
        ],
      );

  Widget _emptyConversationHint(String peerName, AppPalette p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Belum ada pesan dengan $peerName',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: p.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Ketuk balasan cepat di bawah atau tulis pesanmu untuk memulai obrolan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ],
        ),
      );

  Widget _bubble(ChatMessage m, String peerName) {
    final p = context.palette;
    final mine = m.fromMe;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label: '${mine ? 'Kamu' : peerName}, pukul ${m.time}: ${m.text ?? ''}',
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: const BoxConstraints(maxWidth: 270),
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
                      color: mine
                          ? Colors.white.withValues(alpha: 0.85)
                          : p.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickRepliesBar({
    required String? chatId,
    required ChatThread? thread,
    required ItemModel? cloudItem,
    required String? currentUid,
  }) {
    final p = context.palette;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => AccessibleTap(
          onTap: () => _send(
            _quickReplies[i],
            chatId: chatId,
            thread: thread,
            cloudItem: cloudItem,
            currentUid: currentUid,
          ),
          label: 'Kirim balasan cepat: ${_quickReplies[i]}',
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            child: Text(_quickReplies[i],
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: p.text)),
          ),
        ),
      ),
    );
  }

  Widget _composerBar({
    required String? chatId,
    required ChatThread? thread,
    required ItemModel? cloudItem,
    required String? currentUid,
  }) {
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
                onSubmitted: (v) => _send(
                  v,
                  chatId: chatId,
                  thread: thread,
                  cloudItem: cloudItem,
                  currentUid: currentUid,
                ),
                onEditingComplete: () {},
                decoration: InputDecoration(
                  hintText: 'Tulis pesan…',
                  hintStyle: TextStyle(color: p.textMuted),
                  filled: true,
                  fillColor: p.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Kirim pesan',
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                label: 'Kirim pesan',
                excludeSemantics: true,
                onTap: () => _send(
                  _composer.text,
                  chatId: chatId,
                  thread: thread,
                  cloudItem: cloudItem,
                  currentUid: currentUid,
                ),
                child: Material(
                  color: p.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending
                        ? null
                        : () => _send(
                              _composer.text,
                              chatId: chatId,
                              thread: thread,
                              cloudItem: cloudItem,
                              currentUid: currentUid,
                            ),
                    child: SizedBox(
                        width: 48,
                        height: 48,
                        child: _sending
                            ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: p.onPrimary),
                              )
                            : Icon(Icons.send, color: p.onPrimary, size: 20)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
