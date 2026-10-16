import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/item.dart';

/// Foto barang: menampilkan [Image.network] jika [Item.imageUrl] ada,
/// dengan shimmer loading dan fallback ke gradient+emoji.
/// Jika [Item.imageUrl] null (barang baru tanpa foto), langsung gradient+emoji.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({
    super.key,
    required this.item,
    this.height = 92,
    this.radius = 14,
    this.large = false,
  });

  final Item item;
  final double height;
  final double radius;
  final bool large;

  @override
  Widget build(BuildContext context) {
    // Item Firestore menyimpan foto sebagai Base64. Tangani sebelum URL/path
    // agar string Base64 tidak diteruskan ke Image.network.
    if (item.imageUrl != null && item.imageUrl!.startsWith('base64:')) {
      try {
        final bytes = base64Decode(item.imageUrl!.substring('base64:'.length));
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Image.memory(bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _gradientFallback()),
          ),
        );
      } on FormatException {
        return _gradientFallback();
      }
    }

    // Jika ada local file path (dari image_picker)
    if (item.imageUrl != null && item.imageUrl!.startsWith('/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Image.file(
            File(item.imageUrl!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _gradientFallback(),
          ),
        ),
      );
    }

    // Jika ada network URL
    if (item.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Image.network(
            item.imageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _shimmerLoading();
            },
            errorBuilder: (_, __, ___) => _gradientFallback(),
          ),
        ),
      );
    }

    // Tidak ada foto: gradient + emoji
    return _gradientFallback();
  }

  Widget _shimmerLoading() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.grey.shade200,
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _gradientFallback() {
    final base = item.swatch;
    final darker = Color.fromARGB(
      255,
      ((base.r * 255).round() - 36).clamp(0, 255),
      ((base.g * 255).round() - 36).clamp(0, 255),
      ((base.b * 255).round() - 36).clamp(0, 255),
    );
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, darker],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        categoryEmoji(item.category),
        style: TextStyle(fontSize: large ? 64 : 32),
      ),
    );
  }
}
