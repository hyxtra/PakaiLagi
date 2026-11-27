import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../business/item_status_rules.dart';
import '../models/cloud_pickup_request.dart';
import '../models/item.dart';
import '../models/item_model.dart';
import '../providers/cloud_item_provider.dart';
import '../repositories/firebase_repository.dart';
import '../router/app_router.dart';
import '../services/user_messages.dart';
import '../theme/app_palette.dart';
import '../widgets/accessible_tap.dart';
import '../widgets/badges.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/transaction_progress.dart';

enum _HistoryFilter { all, completed, rejected }

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  int _tab = 0;
  _HistoryFilter _historyFilter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final myCloudItems = ref.watch(myCloudItemsStreamProvider);
    final outgoingRequests = ref.watch(myOutgoingCloudRequestsProvider);
    final incomingRequests = ref.watch(myIncomingCloudRequestsProvider);
    final cloudItems = ref.watch(cloudItemsStreamProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Semantics(
              header: true,
              child: Text('Aktivitas',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: p.text)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _tabButton('Pengajuan', 0),
                _tabButton('Barang Saya', 1),
                _tabButton('Riwayat', 2),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Expanded(
            child: switch (_tab) {
              0 => _outgoingProgressTab(outgoingRequests, cloudItems),
              1 => _myActiveItemsTab(myCloudItems, incomingRequests),
              _ => _historyTab(
                  outgoingRequests: outgoingRequests,
                  myCloudItems: myCloudItems,
                  incomingRequests: incomingRequests,
                  cloudItems: cloudItems,
                ),
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: PENGAJUAN SAYA (Menunggu persetujuan & sedang serah terima)
  // ---------------------------------------------------------------------------

  Widget _outgoingProgressTab(
    AsyncValue<List<CloudPickupRequest>> requestsState,
    AsyncValue<List<ItemModel>> cloudItemsState,
  ) {
    final p = context.palette;
    if (requestsState.isLoading || cloudItemsState.isLoading) {
      return Center(
          child: CircularProgressIndicator(
              color: p.primary, semanticsLabel: 'Memuat pengajuan kamu'));
    }
    if (requestsState.hasError || cloudItemsState.hasError) {
      return _errorRetry(
        'Gagal memuat pengajuan kamu.',
        () {
          ref.invalidate(myOutgoingCloudRequestsProvider);
          ref.invalidate(cloudItemsStreamProvider);
        },
      );
    }

    final itemById = {
      for (final it in cloudItemsState.valueOrNull ?? const <ItemModel>[])
        it.id: it,
    };
    final requests = requestsState.valueOrNull ?? const <CloudPickupRequest>[];

    // Pengajuan aktif = pending, atau accepted selama item belum completed.
    final activeRequests = requests.where((req) {
      final item = itemById[req.itemId];
      if (req.status == 'pending') return true;
      if (req.status == 'accepted' &&
          item != null &&
          item.status != ItemStatusRules.completed) {
        return true;
      }
      return false;
    }).toList();

    if (activeRequests.isEmpty) {
      return _emptyState(
        icon: Icons.local_shipping_outlined,
        title: 'Belum ada pengajuan aktif',
        subtitle:
            'Ajukan barang dari Beranda, atau cek transaksi yang sudah selesai/ditolak di tab Riwayat.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: activeRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        final req = activeRequests[i];
        final model = itemById[req.itemId];
        return _RequesterTransactionCard(
          request: req,
          itemModel: model,
          onOpenTimeline: () => _showTimelineSheet(
            context,
            title: model?.title ?? 'Detail Progress',
            steps: buildTransactionStepsWithDates(
              itemStatus: model == null
                  ? ItemStatus.available
                  : _parseStatus(model.status),
              request: req,
              isOwner: false,
              itemCreatedAt: model?.createdAt,
              completedAt: model?.updatedAt,
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: BARANG SAYA (Tersedia & Sedang Diserahkan)
  // ---------------------------------------------------------------------------

  Widget _myActiveItemsTab(
    AsyncValue<List<ItemModel>> myItemsState,
    AsyncValue<List<CloudPickupRequest>> incomingState,
  ) {
    final p = context.palette;
    if (myItemsState.isLoading) {
      return Center(
          child: CircularProgressIndicator(
              color: p.primary, semanticsLabel: 'Memuat barang kamu'));
    }
    if (myItemsState.hasError) {
      return _errorRetry(
        'Gagal memuat barang kamu.',
        () => ref.invalidate(myCloudItemsStreamProvider),
      );
    }

    final allItems = myItemsState.valueOrNull ?? const <ItemModel>[];
    final activeItems = allItems
        .where((it) => it.status != ItemStatusRules.completed)
        .toList();

    if (activeItems.isEmpty) {
      return _emptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Tidak ada barang aktif',
        subtitle:
            'Barang yang kamu bagikan muncul di sini, dan barang yang sudah selesai tersimpan di tab Riwayat.',
      );
    }

    final incoming = incomingState.valueOrNull ?? const <CloudPickupRequest>[];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: activeItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        final model = activeItems[i];
        final reqsForItem =
            incoming.where((r) => r.itemId == model.id).toList();
        final pendingCount =
            reqsForItem.where((r) => r.status == 'pending').length;
        CloudPickupRequest? acceptedReq;
        for (final r in reqsForItem) {
          if (r.status == 'accepted') {
            acceptedReq = r;
            break;
          }
        }
        return _DonorTransactionCard(
          itemModel: model,
          pendingCount: pendingCount,
          acceptedRequest: acceptedReq,
          onComplete: model.status == ItemStatusRules.reserved
              ? () => _confirmComplete(context, model, acceptedReq)
              : null,
          onOpenTimeline: () => _showTimelineSheet(
            context,
            title: model.title,
            steps: buildTransactionStepsWithDates(
              itemStatus: _parseStatus(model.status),
              request: acceptedReq,
              isOwner: true,
              itemCreatedAt: model.createdAt,
              completedAt: model.updatedAt,
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: RIWAYAT (Transaksi selesai & pengajuan ditolak)
  // ---------------------------------------------------------------------------

  Widget _historyTab({
    required AsyncValue<List<CloudPickupRequest>> outgoingRequests,
    required AsyncValue<List<ItemModel>> myCloudItems,
    required AsyncValue<List<CloudPickupRequest>> incomingRequests,
    required AsyncValue<List<ItemModel>> cloudItems,
  }) {
    final p = context.palette;
    if (outgoingRequests.isLoading ||
        myCloudItems.isLoading ||
        cloudItems.isLoading) {
      return Center(
          child: CircularProgressIndicator(
              color: p.primary, semanticsLabel: 'Memuat riwayat transaksi'));
    }
    if (outgoingRequests.hasError ||
        myCloudItems.hasError ||
        cloudItems.hasError) {
      return _errorRetry(
        'Gagal memuat riwayat transaksi.',
        () {
          ref.invalidate(myOutgoingCloudRequestsProvider);
          ref.invalidate(myCloudItemsStreamProvider);
          ref.invalidate(cloudItemsStreamProvider);
        },
      );
    }

    final itemById = {
      for (final it in cloudItems.valueOrNull ?? const <ItemModel>[]) it.id: it,
    };
    final incoming =
        incomingRequests.valueOrNull ?? const <CloudPickupRequest>[];
    final entries = <_HistoryEntry>[];

    // 1) Riwayat sebagai Peminta (selesai atau ditolak atau barang dihapus)
    for (final req in outgoingRequests.valueOrNull ?? const <CloudPickupRequest>[]) {
      final model = itemById[req.itemId];
      final isRejected = req.status == 'rejected';
      final isCompleted =
          req.status == 'accepted' && model?.status == ItemStatusRules.completed;
      final isOrphanedNonPending =
          model == null && req.status != 'pending';

      if (!isRejected && !isCompleted && !isOrphanedNonPending) continue;

      final sortAt =
          model?.updatedAt ?? req.decidedAt ?? req.createdAt;
      entries.add(_HistoryEntry(
        isOwner: false,
        isRejected: isRejected,
        itemModel: model,
        request: req,
        sortAt: sortAt,
      ));
    }

    // 2) Riwayat sebagai Pemberi (barang berstatus completed)
    for (final model in myCloudItems.valueOrNull ?? const <ItemModel>[]) {
      if (model.status != ItemStatusRules.completed) continue;
      CloudPickupRequest? acceptedReq;
      for (final r in incoming) {
        if (r.itemId == model.id && r.status == 'accepted') {
          acceptedReq = r;
          break;
        }
      }
      entries.add(_HistoryEntry(
        isOwner: true,
        isRejected: false,
        itemModel: model,
        request: acceptedReq,
        sortAt: model.updatedAt ?? acceptedReq?.decidedAt ?? model.createdAt,
      ));
    }

    entries.sort((a, b) {
      final ta = a.sortAt;
      final tb = b.sortAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    final filtered = switch (_historyFilter) {
      _HistoryFilter.all => entries,
      _HistoryFilter.completed => entries.where((e) => !e.isRejected).toList(),
      _HistoryFilter.rejected => entries.where((e) => e.isRejected).toList(),
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _filterChip('Semua', _HistoryFilter.all),
              const SizedBox(width: 8),
              _filterChip('Selesai', _HistoryFilter.completed),
              const SizedBox(width: 8),
              _filterChip('Ditolak', _HistoryFilter.rejected),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState(
                  icon: Icons.history_rounded,
                  title: 'Belum ada riwayat transaksi',
                  subtitle:
                      'Transaksi yang sudah selesai atau ditolak akan tercatat rapi di sini.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final e = filtered[i];
                    if (e.isOwner) {
                      return _DonorTransactionCard(
                        itemModel: e.itemModel!,
                        pendingCount: 0,
                        acceptedRequest: e.request,
                        isHistory: true,
                        onOpenTimeline: () => _showTimelineSheet(
                          context,
                          title: e.itemModel!.title,
                          steps: buildTransactionStepsWithDates(
                            itemStatus: _parseStatus(e.itemModel!.status),
                            request: e.request,
                            isOwner: true,
                            itemCreatedAt: e.itemModel!.createdAt,
                            completedAt: e.itemModel!.updatedAt,
                          ),
                        ),
                      );
                    }
                    return _RequesterTransactionCard(
                      request: e.request!,
                      itemModel: e.itemModel,
                      isHistory: true,
                      onOpenTimeline: () => _showTimelineSheet(
                        context,
                        title: e.itemModel?.title ?? 'Detail Progress',
                        steps: buildTransactionStepsWithDates(
                          itemStatus: e.itemModel == null
                              ? ItemStatus.available
                              : _parseStatus(e.itemModel!.status),
                          request: e.request,
                          isOwner: false,
                          itemCreatedAt: e.itemModel?.createdAt,
                          completedAt: e.itemModel?.updatedAt,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, _HistoryFilter value) {
    final p = context.palette;
    final selected = _historyFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _historyFilter = value),
      selectedColor: p.primary,
      backgroundColor: p.surface,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: selected ? p.onPrimary : p.text,
      ),
      side: BorderSide(color: selected ? p.primary : p.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIONS & HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _confirmComplete(
    BuildContext context,
    ItemModel model,
    CloudPickupRequest? acceptedReq,
  ) async {
    final p = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Serah Terima Selesai?'),
        content: Text(
          'Tandai "${model.title}" sudah diserahkan kepada '
          '${acceptedReq?.requesterName ?? 'penerima'}. '
          'Status berubah menjadi Selesai dan masuk ke Riwayat.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: p.primary),
              child: const Text('Tandai Selesai')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = AppMessenger.of(context);
    try {
      final outcome = await runWithProgress(
        context,
        message: 'Menandai selesai…',
        task: () => awaitWrite(
          ref.read(firebaseRepositoryProvider).updateItemStatus(
                model.id,
                ItemStatusRules.completed,
                from: ItemStatusRules.reserved,
                acceptedRequesterId: acceptedReq?.requesterId,
                itemTitle: model.title,
                ownerName: model.ownerName,
              ),
        ),
      );
      messenger.result(
        outcome,
        done: 'Serah terima selesai. Tersimpan di Riwayat!',
        queued: 'Status selesai tersimpan di perangkat. $queuedSuffix',
      );
    } catch (error) {
      showAppSnackBar(
        messenger,
        friendlyError(error, fallback: 'Gagal menandai selesai. Coba lagi.'),
        isError: true,
      );
    }
  }

  void _showTimelineSheet(
    BuildContext context, {
    required String title,
    required List<TransactionStep> steps,
  }) {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 14),
              TransactionProgressTimeline(steps: steps),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final p = context.palette;
    final active = _tab == index;
    return Expanded(
      child: AccessibleTap(
        onTap: () => setState(() => _tab = index),
        label: 'Tab $label',
        selected: active,
        radio: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? p.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? p.primary : p.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: p.textMuted),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _errorRetry(String message, VoidCallback onRetry) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.isOwner,
    required this.isRejected,
    required this.itemModel,
    required this.request,
    required this.sortAt,
  });

  final bool isOwner;
  final bool isRejected;
  final ItemModel? itemModel;
  final CloudPickupRequest? request;
  final DateTime? sortAt;
}

class _RequesterTransactionCard extends StatelessWidget {
  const _RequesterTransactionCard({
    required this.request,
    required this.itemModel,
    required this.onOpenTimeline,
    this.isHistory = false,
  });

  final CloudPickupRequest request;
  final ItemModel? itemModel;
  final VoidCallback onOpenTimeline;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = itemModel == null ? null : _cloudToItem(itemModel!);
    final itemStatus = item?.status ?? ItemStatus.available;
    final steps = buildTransactionStepsWithDates(
      itemStatus: itemStatus,
      request: request,
      isOwner: false,
      itemCreatedAt: itemModel?.createdAt,
      completedAt: itemModel?.updatedAt,
    );

    final (String badgeText, Color badgeColor) = switch (request.status) {
      'rejected' => ('DITOLAK', p.danger),
      'accepted' when itemStatus == ItemStatus.completed =>
        ('SELESAI', p.statusCompleted),
      'accepted' => ('DISETUJUI', p.accentText),
      _ => ('MENUNGGU', p.primary),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header role + status badge
          Row(
            children: [
              const _RoleChip(label: 'Pengajuan Saya'),
              const Spacer(),
              _StatusPill(label: badgeText, color: badgeColor),
            ],
          ),
          const SizedBox(height: 10),
          // Item summary row
          InkWell(
            onTap: itemModel == null
                ? null
                : () => context.push(AppRoutes.itemDetail(itemModel!.id)),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: item == null
                      ? Container(
                          decoration: BoxDecoration(
                            color: p.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.inventory_2_outlined,
                              color: p.textMuted),
                        )
                      : PhotoPlaceholder(item: item, height: 60, radius: 10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemModel?.title ?? 'Barang telah dihapus',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Pemberi: ${itemModel?.ownerName ?? '-'} • ${request.method}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                if (itemModel != null)
                  Icon(Icons.chevron_right, color: p.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // E-commerce progress tracker
          TransactionProgressBar(steps: steps),
          const SizedBox(height: 12),
          // Quick action row
          Row(
            children: [
              if (itemModel != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.chat(
                      itemModel!.id,
                      itemModel!.ownerName,
                      requesterId: request.requesterId,
                    )),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.primary,
                      side: BorderSide(color: p.border),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 17),
                    label: const Text('Chat',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.itemDetail(itemModel!.id)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: request.status == 'accepted' && !isHistory
                          ? p.primary
                          : p.surfaceAlt,
                      foregroundColor: request.status == 'accepted' && !isHistory
                          ? p.onPrimary
                          : p.text,
                      elevation: 0,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(
                      request.status == 'accepted' && !isHistory
                          ? Icons.location_on_outlined
                          : Icons.visibility_outlined,
                      size: 17,
                    ),
                    label: Text(
                      request.status == 'accepted' && !isHistory
                          ? 'Lokasi'
                          : 'Detail',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Lihat timeline progress',
                onPressed: onOpenTimeline,
                style: IconButton.styleFrom(
                  backgroundColor: p.surfaceAlt,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(Icons.timeline_rounded, color: p.primary, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonorTransactionCard extends StatelessWidget {
  const _DonorTransactionCard({
    required this.itemModel,
    required this.pendingCount,
    required this.acceptedRequest,
    required this.onOpenTimeline,
    this.onComplete,
    this.isHistory = false,
  });

  final ItemModel itemModel;
  final int pendingCount;
  final CloudPickupRequest? acceptedRequest;
  final VoidCallback onOpenTimeline;
  final VoidCallback? onComplete;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = _cloudToItem(itemModel);
    final steps = buildTransactionStepsWithDates(
      itemStatus: item.status,
      request: acceptedRequest,
      isOwner: true,
      itemCreatedAt: itemModel.createdAt,
      completedAt: itemModel.updatedAt,
    );

    return Container(
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
              const _RoleChip(label: 'Barang Saya'),
              const Spacer(),
              StatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => context.push(AppRoutes.itemDetail(item.id)),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: PhotoPlaceholder(item: item, height: 60, radius: 10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        acceptedRequest != null
                            ? 'Penerima: ${acceptedRequest!.requesterName} • ${acceptedRequest!.method}'
                            : (pendingCount > 0
                                ? '$pendingCount pengajuan menunggu persetujuan'
                                : item.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: p.textMuted),
              ],
            ),
          ),
          // Tampilkan progress tracker ketika sudah ada penerima / selesai.
          if (item.status != ItemStatus.available) ...[
            const SizedBox(height: 12),
            TransactionProgressBar(steps: steps),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (item.status == ItemStatus.available)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.manageRequest(item.id)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.primary,
                      side: BorderSide(color: p.primary),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: Text(
                      pendingCount == 0
                          ? 'Kelola Pengajuan'
                          : 'Kelola ($pendingCount baru)',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else ...[
                if (acceptedRequest != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.chat(
                        item.id,
                        acceptedRequest!.requesterName,
                        requesterId: acceptedRequest!.requesterId,
                      )),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.primary,
                        side: BorderSide(color: p.border),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 17),
                      label: const Text('Chat Peminta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onComplete != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: p.onPrimary,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.task_alt, size: 17),
                      label: const Text('Selesai',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  )
                else if (isHistory)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.itemDetail(item.id)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.surfaceAlt,
                        foregroundColor: p.text,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 17),
                      label: const Text('Lihat Detail',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Lihat timeline progress',
                  onPressed: onOpenTimeline,
                  style: IconButton.styleFrom(
                    backgroundColor: p.surfaceAlt,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon:
                      Icon(Icons.timeline_rounded, color: p.primary, size: 20),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: p.textMuted,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

ItemStatus _parseStatus(String status) => switch (status) {
      'completed' => ItemStatus.completed,
      'reserved' => ItemStatus.reserved,
      _ => ItemStatus.available,
    };

Item _cloudToItem(ItemModel data) => Item(
      id: data.id,
      title: data.title,
      category: data.category,
      description: data.description,
      ownerId: data.donorId,
      ownerName: data.ownerName,
      ownerPhone: '',
      status: _parseStatus(data.status),
      swatch: const Color(0xFF2F6B4F),
      pickupMethods: data.availablePickupMethods,
      address: data.areaLabel,
      condition: data.condition,
      listingType: data.listingType,
      price: data.price,
      imageUrl:
          data.imageBase64.isEmpty ? null : 'base64:${data.imageBase64}',
    );
