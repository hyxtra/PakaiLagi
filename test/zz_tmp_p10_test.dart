// FILE SEMENTARA: verifikasi logika data P10. Dihapus setelah dijalankan.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/business/image_base64.dart';
import 'package:pakailagi/business/item_status_rules.dart';
import 'package:pakailagi/data/pickup_methods.dart';
import 'package:pakailagi/models/item_model.dart';

void main() {
  group('ImageBase64: batas ukuran', () {
    test('encodedLength sama dengan panjang base64Encode sebenarnya', () {
      for (final n in [0, 1, 2, 3, 4, 5, 100, 1023, 1024, 65535, 675000]) {
        final bytes = Uint8List(n);
        expect(ImageBase64.encodedLength(n), base64Encode(bytes).length,
            reason: 'n=$n');
      }
    });

    test('batas tepat di sekitar 900000 karakter', () {
      // 675000 byte -> 900000 karakter (TIDAK lolos, aturan: < 900000)
      expect(ImageBase64.encodedLength(675000), 900000);
      expect(ImageBase64.fitsFirestoreLimit(675000), isFalse);
      // 674997 byte -> 899996 karakter (lolos)
      expect(ImageBase64.encodedLength(674997), 899996);
      expect(ImageBase64.fitsFirestoreLimit(674997), isTrue);
      expect(ImageBase64.fitsFirestoreLimit(200 * 1024), isTrue);
      expect(ImageBase64.fitsFirestoreLimit(2 * 1024 * 1024), isFalse);
    });
  });

  group('ItemModel.pickupMethods', () {
    Map<String, dynamic> base() => {'title': 't', 'category': 'c'};

    test('barang lama (tanpa field) menawarkan semua metode', () {
      final m = ItemModel.fromMap(base(), id: 'a');
      expect(m.pickupMethods, isEmpty);
      expect(m.availablePickupMethods, kPickupMethodNames);
    });

    test('hanya metode yang dipilih pemberi yang tersedia', () {
      final m = ItemModel.fromMap(
          {...base(), 'pickupMethods': ['Bertemu (COD)']},
          id: 'a');
      expect(m.availablePickupMethods, ['Bertemu (COD)']);
    });

    test('nama tak dikenal (termasuk Ambil Sendiri) dibuang', () {
      final m = ItemModel.fromMap({
        ...base(),
        'pickupMethods': ['Ambil Sendiri', 'Antar ke Alamat', 'Antar ke Alamat']
      }, id: 'a');
      expect(m.availablePickupMethods, ['Antar ke Alamat']);
    });

    test('semua tak dikenal / tipe salah -> dianggap barang lama', () {
      expect(
          ItemModel.fromMap({...base(), 'pickupMethods': ['Kurir']}, id: 'a')
              .availablePickupMethods,
          kPickupMethodNames);
      expect(
          ItemModel.fromMap({...base(), 'pickupMethods': 'Bertemu (COD)'},
                  id: 'a')
              .availablePickupMethods,
          kPickupMethodNames);
      expect(
          ItemModel.fromMap({...base(), 'pickupMethods': [1, null, 2]},
                  id: 'a')
              .availablePickupMethods,
          kPickupMethodNames);
    });
  });

  group('ItemStatusRules', () {
    test('selesai hanya dari reserved', () {
      expect(
          ItemStatusRules.canTransition(
              from: ItemStatusRules.reserved, to: ItemStatusRules.completed),
          isTrue);
      expect(
          ItemStatusRules.canTransition(
              from: ItemStatusRules.available, to: ItemStatusRules.completed),
          isFalse);
      expect(
          ItemStatusRules.canTransition(
              from: ItemStatusRules.completed, to: ItemStatusRules.available),
          isFalse);
    });
  });
}
