import 'package:flutter/material.dart';

import '../models/item.dart';
import '../theme/app_palette.dart';
import 'accessible_tap.dart';
import 'badges.dart';
import 'photo_placeholder.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  /// Batas pembesaran font (kali) di mana dua badge masih muat sebaris.
  static const double _maxScaleForSingleRow = 1.15;

  /// Badge kategori + status. Pada ukuran font normal keduanya sebaris
  /// (kategori melebar, status di kanan) seperti semula. Saat font HP
  /// diperbesar, badge status yang lebar menyisakan terlalu sedikit ruang
  /// untuk kategori (teruji: tersisa 18 dp dan melimpah), sehingga keduanya
  /// dipindah ke [Wrap] agar turun ke baris berikutnya bila perlu.
  Widget _badges(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (scale > _maxScaleForSingleRow) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          CategoryBadge(category: item.category),
          StatusBadge(status: item.status),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: CategoryBadge(category: item.category)),
        const SizedBox(width: 6),
        StatusBadge(status: item.status),
      ],
    );
  }

  /// Kalimat yang dibacakan pembaca layar untuk satu kartu barang.
  static String semanticLabel(Item item) =>
      '${item.title}. Kategori ${item.category}. '
      'Status ${item.status.label.toLowerCase()}. '
      'Pemberi ${item.ownerName}. Ketuk dua kali untuk membuka detail.';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AccessibleTap(
        onTap: onTap,
        label: semanticLabel(item),
        borderRadius: BorderRadius.circular(18),
        minSize: 0,
        child: Container(
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
              SizedBox(
                  width: 92, child: PhotoPlaceholder(item: item, height: 92)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _badges(context),
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
      ),
    );
  }
}
