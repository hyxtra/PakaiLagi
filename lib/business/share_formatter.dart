import '../models/item.dart';

/// Formatter murni untuk ringkasan barang yang bisa ditempel ke WhatsApp.
abstract final class ShareFormatter {
  static String priceLabel({
    required String listingType,
    required int price,
  }) {
    if (listingType != ListingType.tebusMurah) return 'Gratis';
    return 'Tebus murah • ${formatRupiah(price)}';
  }

  static String formatRupiah(int amount) {
    final digits = amount.abs().toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = end - 3 < 0 ? 0 : end - 3;
      groups.insert(0, digits.substring(start, end));
    }
    return 'Rp${amount < 0 ? '-' : ''}${groups.join('.')}';
  }

  static String formatItemSummary({
    required String title,
    required String category,
    required String condition,
    required String listingType,
    required int price,
    required String area,
    required String description,
  }) {
    final lines = <String>[
      '♻️ PakaiLagi — Barang siap diberi hidup kedua',
      title.trim(),
      'Kategori: ${category.trim()}',
      'Kondisi: ${condition.trim()}',
      'Penawaran: ${priceLabel(listingType: listingType, price: price)}',
      if (area.trim().isNotEmpty) 'Area pengambilan: ${area.trim()}',
      if (description.trim().isNotEmpty) 'Deskripsi: ${description.trim()}',
    ];
    return lines.join('\n');
  }
}
