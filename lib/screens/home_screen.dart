import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/item.dart';
import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cloud_item_provider.dart';
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

  /// Konversi data Firestore Map → Item model agar bisa pakai ItemCard.
  Item _cloudMapToItem(ItemModel data) {
    return Item(
      id: data.id,
      title: data.title,
      category: data.category,
      description: data.description,
      ownerId: data.donorId,
      ownerName: data.ownerName,
      ownerPhone: '',
      status: ItemStatus.available,
      swatch: const Color(0xFF2F6B4F),
      pickupMethods: const ['Ambil Sendiri'],
      address: '',
      // Simpan Base64 string sebagai imageUrl, akan di-handle khusus
      imageUrl:
          data.imageBase64.isNotEmpty ? 'base64:${data.imageBase64}' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = ref.watch(authProvider);
    final localItems = ref.watch(itemsProvider);

    // Ambil data dari Firestore (cloud)
    final cloudAsync = ref.watch(cloudItemsStreamProvider);
    final cloudItems = cloudAsync.when(
      data: (list) => list.map(_cloudMapToItem).toList(),
      loading: () => <Item>[],
      error: (_, __) => <Item>[],
    );

    // Gabung: cloud items di atas, lalu local items
    final allItems = [...cloudItems, ...localItems];

    final filtered = allItems.where((it) {
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
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: p.text,
                              height: 1.25)),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.notifications_none,
                      size: 20, color: p.primary),
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
                    itemBuilder: (_, i) => _buildItemCard(filtered[i], p),
                  ),
          ),
        ],
      ),
    );
  }

  /// Build card yang bisa menampilkan foto Base64 dari cloud
  /// atau foto biasa dari data lokal.
  Widget _buildItemCard(Item item, AppPalette p) {
    // Jika imageUrl dimulai "base64:", render Image.memory
    final isBase64 =
        item.imageUrl != null && item.imageUrl!.startsWith('base64:');

    if (isBase64) {
      final b64 = item.imageUrl!.substring(7); // hapus prefix "base64:"
      return GestureDetector(
        onTap: () => context.push(AppRoutes.itemDetail(item.id)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: Image.memory(
                    base64Decode(b64),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2F6B4F),
                      alignment: Alignment.center,
                      child: Text(categoryEmoji(item.category),
                          style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${categoryEmoji(item.category)} ${item.category}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2F6B4F)),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color:
                                const Color(0xFF2F6B4F).withValues(alpha: 0.1),
                          ),
                          child: const Text(
                            '◎ TERSEDIA',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F6B4F)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: p.text),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 13, color: p.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.ownerName,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 12.5, color: p.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Item lokal — pakai ItemCard biasa
    return ItemCard(
      item: item,
      onTap: () => context.push(AppRoutes.itemDetail(item.id)),
    );
  }
}
