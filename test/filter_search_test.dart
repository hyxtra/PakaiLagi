import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/business/item_filters.dart';
import 'package:pakailagi/models/item.dart';
import 'package:pakailagi/models/item_model.dart';

void main() {
  final fixtures = List.generate(
    12,
    (i) => ItemModel(
      id: 'id-$i',
      title: i.isEven ? 'Meja belajar $i' : 'Buku cerita $i',
      category: i.isEven ? 'Furniture' : 'Buku',
      description: 'Layak digunakan',
      condition: ItemCondition.all[i % ItemCondition.all.length],
      status: i == 11 ? 'reserved' : 'available',
    ),
  );

  group('P11 kombinasi pencarian dan filter kategori/kondisi', () {
    for (var i = 0; i < 22; i++) {
      final category = i % 3 == 0 ? 'Semua' : (i.isEven ? 'Furniture' : 'Buku');
      final condition = i % 4 == 0
          ? 'Semua'
          : ItemCondition.all[i % ItemCondition.all.length];
      final query = i % 5 == 0 ? '' : (i.isEven ? 'meja' : 'BUKU');
      test('filter kombinasi kasus $i', () {
        final result = filterItems(
          items: fixtures,
          query: query,
          category: category,
          condition: condition,
        );
        expect(result.every((item) => item.status == 'available'), isTrue);
        if (query.trim().isNotEmpty) {
          expect(
              result.every((item) =>
                  item.title.toLowerCase().contains(query.toLowerCase())),
              isTrue);
        }
        if (category != 'Semua') {
          expect(result.every((item) => item.category == category), isTrue);
        }
        if (condition != 'Semua') {
          expect(result.every((item) => item.condition == condition), isTrue);
        }
      });
    }
  });
}
