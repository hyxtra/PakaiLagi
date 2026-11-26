import 'package:flutter/material.dart';

import '../business/share_formatter.dart';
import '../models/item.dart';
import '../theme/app_palette.dart';
import 'accessible_tap.dart';
import 'badges.dart';
import 'photo_placeholder.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  /// Kalimat yang dibacakan pembaca layar untuk satu kartu barang.
  static String semanticLabel(Item item) =>
      '${item.title}. Kategori ${item.category}. '
      'Kondisi ${item.condition}. '
      '${ShareFormatter.priceLabel(listingType: item.listingType, price: item.price)}. '
      'Status ${item.status.label.toLowerCase()}. '
      'Pemberi ${item.ownerName}. Ketuk dua kali untuk membuka detail.';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AccessibleTap(
        onTap: onTap,
        label: semanticLabel(item),
        borderRadius: BorderRadius.circular(14),
        minSize: 0,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.4,
                child: PhotoPlaceholder(item: item, height: 220, radius: 0),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final category = Text(
                          item.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: p.textMuted,
                              fontWeight: FontWeight.w600),
                        );
                        if (constraints.maxWidth < 150) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              category,
                              Align(
                                alignment: Alignment.centerRight,
                                child: StatusBadge(status: item.status),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: category),
                            const SizedBox(width: 8),
                            StatusBadge(status: item.status),
                          ],
                        );
                      },
                    ),
                    if (item.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(item.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: p.textMuted)),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: p.text),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ShareFormatter.priceLabel(
                                listingType: item.listingType,
                                price: item.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: p.primary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(item.condition,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style:
                                  TextStyle(fontSize: 11, color: p.textMuted)),
                        ),
                      ],
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
