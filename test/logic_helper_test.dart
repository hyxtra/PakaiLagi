import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/business/distance_helper.dart';
import 'package:pakailagi/business/share_formatter.dart';
import 'package:pakailagi/models/item.dart';

void main() {
  group('P11 DistanceHelper', () {
    for (var i = 0; i < 12; i++) {
      test('jarak koordinat deterministik kasus $i', () {
        final offset = (i + 1) / 1000;
        final km = DistanceHelper.kilometers(
          startLatitude: -6.2,
          startLongitude: 106.8,
          endLatitude: -6.2 + offset,
          endLongitude: 106.8,
        );
        expect(km, greaterThan(0));
        expect(km, lessThan(20));
        expect(km.isFinite, isTrue);
      });
    }
    test('koordinat sama menghasilkan nol', () {
      expect(
        DistanceHelper.kilometers(
          startLatitude: 0,
          startLongitude: 0,
          endLatitude: 0,
          endLongitude: 0,
        ),
        0,
      );
    });
  });

  group('P11 ShareFormatter', () {
    final prices = [0, 1, 999, 1000, 12500, 50000, 100000];
    for (var i = 0; i < prices.length; i++) {
      test('format Rupiah ${prices[i]}', () {
        expect(ShareFormatter.formatRupiah(prices[i]), isNotEmpty);
        expect(ShareFormatter.formatRupiah(prices[i]), startsWith('Rp'));
      });
    }
    for (var i = 0; i < 7; i++) {
      test('ringkasan WhatsApp memuat data penting variasi $i', () {
        final type = i.isEven ? ListingType.gratis : ListingType.tebusMurah;
        final text = ShareFormatter.formatItemSummary(
          title: '  Kursi $i  ',
          category: 'Furniture',
          condition: ItemCondition.good,
          listingType: type,
          price: 25000,
          area: 'Kel. Melati, Jakarta',
          description: 'Masih kokoh',
        );
        expect(text, contains('Kursi $i'));
        expect(text, contains('Furniture'));
        expect(text, contains('Kel. Melati'));
        if (type == ListingType.gratis) expect(text, contains('Gratis'));
        if (type == ListingType.tebusMurah) {
          expect(text, contains('Rp25.000'));
        }
      });
    }
  });
}
