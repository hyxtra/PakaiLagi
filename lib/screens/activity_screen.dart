import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/item.dart';
import '../models/item_model.dart';
import '../providers/cloud_item_provider.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../widgets/item_card.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final myCloudItems = ref.watch(myCloudItemsStreamProvider);
    final outgoingRequestIds = ref.watch(myOutgoingCloudRequestItemIdsProvider);
    final cloudItems = ref.watch(cloudItemsStreamProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('Aktivitas',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _tabButton('Menunggu Persetujuan', 0),
                _tabButton('Barang Saya', 1),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Expanded(
            child: _tab == 0
                ? _outgoingCloudItems(outgoingRequestIds, cloudItems)
                : _myCloudItems(myCloudItems),
          ),
        ],
      ),
    );
  }

  Widget _outgoingCloudItems(
    AsyncValue<List<String>> requestIds,
    AsyncValue<List<ItemModel>> cloudItems,
  ) {
    final p = context.palette;
    if (requestIds.isLoading || cloudItems.isLoading) {
      return Center(child: CircularProgressIndicator(color: p.primary));
    }
    if (requestIds.hasError || cloudItems.hasError) {
      return Center(
        child: Text('Gagal memuat pengajuan kamu.',
            style: TextStyle(color: p.textMuted)),
      );
    }
    final ids = requestIds.valueOrNull?.toSet() ?? const <String>{};
    final requestedItems = (cloudItems.valueOrNull ?? const <ItemModel>[])
        .where((item) => ids.contains(item.id))
        .map(_cloudToItem)
        .toList();
    return _list(
        requestedItems, 'Belum ada pengajuan yang menunggu persetujuan.',
        showManage: false);
  }

  Widget _myCloudItems(AsyncValue<List<ItemModel>> state) {
    final p = context.palette;
    return state.when(
      loading: () => Center(child: CircularProgressIndicator(color: p.primary)),
      error: (_, __) => Center(
        child: Text('Gagal memuat barang kamu.',
            style: TextStyle(color: p.textMuted)),
      ),
      data: (items) => _list(
        items.map(_cloudToItem).toList(),
        'Kamu belum memposting barang.',
        showManage: true,
      ),
    );
  }

  Item _cloudToItem(ItemModel data) => Item(
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
            data.imageBase64.isEmpty ? null : 'base64:${data.imageBase64}',
      );

  Widget _tabButton(String label, int index) {
    final p = context.palette;
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
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
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: active ? p.primary : p.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(List<Item> items, String emptyText, {required bool showManage}) {
    final p = context.palette;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyText,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, fontSize: 14)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Column(
          children: [
            ItemCard(
                item: item,
                onTap: () => context.push(AppRoutes.itemDetail(item.id))),
            if (showManage && item.status != ItemStatus.completed)
              _manageButton(item),
          ],
        );
      },
    );
  }

  Widget _manageButton(Item item) {
    final p = context.palette;
    final requests = ref.watch(cloudRequestsForItemProvider(item.id));
    final pending = requests.valueOrNull
            ?.where((request) => request.status == 'pending')
            .length ??
        0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.manageRequest(item.id)),
          style: OutlinedButton.styleFrom(
            foregroundColor: p.primary,
            side: BorderSide(color: p.primary),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.groups_outlined, size: 18),
          label: Text(
            pending == 0
                ? 'Kelola Pengajuan'
                : 'Kelola Pengajuan ($pending baru)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
