import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../models/item.dart';
import 'auth_provider.dart';

/// Sumber tunggal daftar barang. Dipakai bersama oleh Home, Detail, Activity,
/// dan Post (barang baru benar-benar ditambahkan ke sini).
class ItemsNotifier extends StateNotifier<List<Item>> {
  ItemsNotifier() : super(List.of(seedItems));

  void addItem({
    required String title,
    required String category,
    required String description,
    required List<String> pickupMethods,
    required String address,
    required String ownerId,
    required String ownerName,
    required String ownerPhone,
    String? imageUrl,
  }) {
    final item = Item(
      id: 'i_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: category,
      description: description,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      status: ItemStatus.available,
      swatch: _randomSwatch(),
      pickupMethods: pickupMethods,
      address: address,
      imageUrl: imageUrl,
    );
    state = [item, ...state];
  }

  void setStatus(String itemId, ItemStatus status) {
    state = [
      for (final it in state) it.id == itemId ? it.copyWith(status: status) : it,
    ];
  }

  static Color _randomSwatch() {
    const swatches = [
      Color(0xFFCBA976),
      Color(0xFF8FB59B),
      Color(0xFF6E86A8),
      Color(0xFF9AA9B4),
      Color(0xFFD8B0A0),
      Color(0xFFB6C2AC),
    ];
    return swatches[DateTime.now().microsecond % swatches.length];
  }
}

final itemsProvider =
    StateNotifierProvider<ItemsNotifier, List<Item>>((ref) => ItemsNotifier());

/// Cari satu barang berdasarkan id.
final itemByIdProvider = Provider.family<Item?, String>((ref, id) {
  final items = ref.watch(itemsProvider);
  for (final it in items) {
    if (it.id == id) return it;
  }
  return null;
});

/// Barang milik user yang login (POV pemberi).
final myItemsProvider = Provider<List<Item>>((ref) {
  final user = ref.watch(authProvider);
  final items = ref.watch(itemsProvider);
  if (user == null) return const [];
  return items.where((it) => it.ownerId == user.id).toList();
});
