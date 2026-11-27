import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/data/pickup_methods.dart';
import 'package:pakailagi/models/item.dart';
import 'package:pakailagi/models/item_model.dart';

void main() {
  group('P11 ItemModel serialization', () {
    for (var i = 0; i < 30; i++) {
      final condition = ItemCondition.all[i % ItemCondition.all.length];
      final listingType =
          i.isEven ? ListingType.gratis : ListingType.tebusMurah;
      final price = listingType == ListingType.gratis ? 0 : i * 1800;
      final source = ItemModel(
        id: 'item-$i',
        title: 'Barang $i',
        category: i.isEven ? 'Buku' : 'Furniture',
        description: 'Kondisi baik nomor $i',
        kelurahan: 'Melati',
        kota: 'Jakarta',
        pickupMethods: [kPickupMethodNames[i % kPickupMethodNames.length]],
        imageBase64: 'cover-$i',
        additionalImages: const ['detail-1', 'detail-2'],
        condition: condition,
        listingType: listingType,
        price: price,
        donorId: 'pemilik-$i',
        ownerName: 'Petra',
        status: 'available',
        createdAt: DateTime.utc(2025, 1, 1).add(Duration(days: i)),
      );
      test('toMap/fromMap round-trip variasi $i', () {
        final restored = ItemModel.fromMap(source.toMap(), id: source.id);
        expect(restored.title, source.title);
        expect(restored.category, source.category);
        expect(restored.description, source.description);
        expect(restored.pickupMethods, source.pickupMethods);
        expect(restored.allImageBase64, source.allImageBase64);
        expect(restored.condition, condition);
        expect(restored.listingType, listingType);
        expect(restored.price, price);
        expect(restored.createdAt, source.createdAt);
      });
    }
    test('timestamp null dan field baru lama memakai default aman', () {
      final restored = ItemModel.fromMap(const {'createdAt': null}, id: 'old');
      expect(restored.createdAt, isNull);
      expect(restored.condition, ItemCondition.good);
      expect(restored.listingType, ListingType.gratis);
      expect(restored.price, 0);
    });
    test('field kondisi dan listing tidak dikenal fallback aman', () {
      final restored = ItemModel.fromMap(const {
        'condition': 'rusak',
        'listingType': 'auction',
        'price': 70000,
      }, id: 'legacy');
      expect(restored.condition, ItemCondition.good);
      expect(restored.listingType, ListingType.gratis);
      expect(restored.price, 70000);
    });
  });
}
