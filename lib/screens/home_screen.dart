import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/item.dart';
import '../providers/auth_provider.dart';
import '../providers/items_provider.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../widgets/item_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  String _cat = 'Semua';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = ref.watch(authProvider);
    final items = ref.watch(itemsProvider);

    final filtered = items.where((it) {
      if (it.status != ItemStatus.available) return false;
      final matchQuery = it.title.toLowerCase().contains(_query.toLowerCase());
      final matchCat = _cat == 'Semua' || it.category == _cat;
      return matchQuery && matchCat;
    }).toList();

    final cats = ['Semua', ...kCategories.map((c) => c.name)];

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Halo, ${user?.firstName ?? 'Teman'} 👋',
                          style: TextStyle(fontSize: 13.5, color: p.textMuted)),
                      const SizedBox(height: 2),
                      Text('Barang siap diberi hidup kedua',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.text, height: 1.25)),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.notifications_none, size: 20, color: p.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: p.text),
              decoration: InputDecoration(
                hintText: 'Cari barang, mis. meja belajar…',
                hintStyle: TextStyle(color: p.textMuted),
                prefixIcon: Icon(Icons.search, color: p.textMuted, size: 18),
                filled: true,
                fillColor: p.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Category chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final active = cats[i] == _cat;
                return GestureDetector(
                  onTap: () => setState(() => _cat = cats[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? p.primary : p.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: active ? p.primary : p.border),
                    ),
                    child: Text(
                      cats[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? p.onPrimary : p.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📦', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('Belum ada barang yang cocok.',
                            style: TextStyle(color: p.textMuted, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => ItemCard(
                      item: filtered[i],
                      onTap: () => context.push(AppRoutes.itemDetail(filtered[i].id)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
