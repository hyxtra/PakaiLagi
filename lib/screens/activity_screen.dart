import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/item.dart';
import '../providers/items_provider.dart';
import '../providers/requests_provider.dart';
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
    final myItems = ref.watch(myItemsProvider);
    final outgoing = ref.watch(myOutgoingRequestsProvider);
    final allItems = ref.watch(itemsProvider);

    // POV peminta: barang yang sedang saya ajukan.
    final requestedItems = outgoing
        .map((r) => allItems.where((it) => it.id == r.itemId))
        .expand((e) => e)
        .toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('Aktivitas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
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
                ? _list(
                    requestedItems,
                    'Belum ada pengajuan yang menunggu persetujuan.',
                    showManage: false,
                  )
                : _list(
                    myItems,
                    'Kamu belum memposting barang.',
                    showManage: true,
                  ),
          ),
        ],
      ),
    );
  }

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
              textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 14)),
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
            ItemCard(item: item, onTap: () => context.push(AppRoutes.itemDetail(item.id))),
            if (showManage && item.status != ItemStatus.completed)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.manageRequest(item.id)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.primary,
                      side: BorderSide(color: p.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Kelola Pengajuan',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
