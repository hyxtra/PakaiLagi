import '../models/item_model.dart';

/// Filter feed untuk pencarian, kategori, dan kondisi.
/// Mengosongkan query memang menampilkan semua barang dan mereset chip pilihan
/// agar hasil tidak tertinggal oleh filter sebelumnya.
List<ItemModel> filterItems({
  required Iterable<ItemModel> items,
  String query = '',
  String category = 'Semua',
  String condition = 'Semua',
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return items.where((item) {
    if (item.status != 'available') return false;
    final matchesQuery = normalizedQuery.isEmpty ||
        item.title.toLowerCase().contains(normalizedQuery);
    final matchesCategory = category == 'Semua' || item.category == category;
    final matchesCondition =
        condition == 'Semua' || item.condition == condition;
    return matchesQuery && matchesCategory && matchesCondition;
  }).toList(growable: false);
}
