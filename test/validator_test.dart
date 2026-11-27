import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/models/item.dart';
import 'package:pakailagi/validators/item_validator.dart';

void main() {
  group('P11 ItemValidator', () {
    final titles = <(String?, bool)>[
      (null, false),
      ('', false),
      ('   ', false),
      ('  meja  ', true),
      ('a', true),
      ('barang bekas', true),
    ];
    for (var i = 0; i < titles.length; i++) {
      final (value, valid) = titles[i];
      test('judul kasus ${i + 1}: $value', () {
        expect(ItemValidator.validateTitle(value) == null, valid);
      });
    }
    for (final whitespace in [' ', ' \n\t', '  \r\n ', '\t  ', '     ']) {
      test('judul whitespace tidak lolos: ${whitespace.length}', () {
        expect(ItemValidator.validateTitle(whitespace), isNotNull);
      });
    }

    final descriptions = <(String?, bool)>[
      (null, false),
      ('', false),
      ('   ', false),
      ('abcd', false),
      (' abcd ', false),
      ('abcde', true),
      ('  abcde  ', true),
      ('deskripsi panjang', true),
    ];
    for (var i = 0; i < descriptions.length; i++) {
      final (value, valid) = descriptions[i];
      test('deskripsi kasus ${i + 1}', () {
        expect(ItemValidator.validateDescription(value) == null, valid);
      });
    }

    final categories = <String?>[null, '', ' ', 'Buku', 'Furniture', 'Pakaian'];
    for (var i = 0; i < categories.length; i++) {
      final value = categories[i];
      test('kategori kasus ${i + 1}', () {
        expect(ItemValidator.validateCategory(value) == null,
            value != null && value.trim().isNotEmpty);
      });
    }

    final prices = <(int?, bool)>[
      (null, false),
      (-1, false),
      (0, true),
      (50000, true),
      (50001, false),
    ];
    for (var i = 0; i < prices.length; i++) {
      final (price, valid) = prices[i];
      test('harga tebus murah kasus ${i + 1}', () {
        expect(
          ItemValidator.validateListingPrice(
                listingType: ListingType.tebusMurah,
                price: price,
              ) ==
              null,
          valid,
        );
      });
    }

    for (final type in [
      ListingType.gratis,
      ListingType.tebusMurah,
      'invalid'
    ]) {
      test('jenis penawaran $type', () {
        expect(ItemValidator.validateListingType(type) == null,
            type == ListingType.gratis || type == ListingType.tebusMurah);
      });
    }

    for (final price in [null, -100, 0, 50000, 50001]) {
      test('harga gratis mengabaikan nominal $price', () {
        expect(
          ItemValidator.validateListingPrice(
            listingType: ListingType.gratis,
            price: price,
          ),
          isNull,
        );
      });
    }
  });
}
