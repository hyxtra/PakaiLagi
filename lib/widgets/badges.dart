import 'package:flutter/material.dart';

import '../models/item.dart';
import '../theme/app_palette.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    // Warna dari palet tema agar kontras teks ≥ 4,5:1 di mode terang & gelap.
    final color = context.palette.statusColor(status);
    return Semantics(
      label: 'Status ${status.label.toLowerCase()}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 12, color: color),
            const SizedBox(width: 4),
            // Flexible + ellipsis: pada font HP sangat besar teks terpotong
            // rapi, tidak melimpah keluar badge.
            Flexible(
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      // Emoji tidak dibacakan; cukup nama kategori.
      label: 'Kategori $category',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: p.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(categoryEmoji(category), style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                category,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: p.accentText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
