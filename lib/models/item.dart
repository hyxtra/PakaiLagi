import 'package:flutter/material.dart';

enum ItemStatus { available, reserved, completed }

extension ItemStatusX on ItemStatus {
  String get label => switch (this) {
        ItemStatus.available => 'TERSEDIA',
        ItemStatus.reserved => 'DISETUJUI',
        ItemStatus.completed => 'SELESAI',
      };

  Color get color => switch (this) {
        ItemStatus.available => const Color(0xFF2F6B4F),
        ItemStatus.reserved => const Color(0xFFE0A63C),
        ItemStatus.completed => const Color(0xFF9AA39C),
      };
}

@immutable
class Item {
  const Item({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.status,
    required this.swatch,
    required this.pickupMethods,
    required this.address,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final ItemStatus status;
  final Color swatch;
  final List<String> pickupMethods;
  final String address;
  final String? imageUrl;

  Item copyWith({ItemStatus? status, String? imageUrl}) {
    return Item(
      id: id,
      title: title,
      category: category,
      description: description,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      status: status ?? this.status,
      swatch: swatch,
      pickupMethods: pickupMethods,
      address: address,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// Kategori barang beserta emoji-nya.
class Category {
  const Category(this.name, this.emoji);
  final String name;
  final String emoji;
}

const kCategories = <Category>[
  Category('Pakaian', '👕'),
  Category('Buku', '📚'),
  Category('Furniture', '🪑'),
  Category('Elektronik', '📱'),
  Category('Peralatan Rumah Tangga', '🍳'),
  Category('Mainan', '🧸'),
  Category('Perlengkapan Bayi & Anak', '🍼'),
  Category('Perlengkapan Sekolah', '🎒'),
  Category('Perlengkapan Kantor', '💼'),
];

String categoryEmoji(String name) {
  for (final c in kCategories) {
    if (c.name == name) return c.emoji;
  }
  return '📦';
}
