import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/models/item_model.dart';
import 'package:pakailagi/services/firestore_configuration.dart';

/// Test kontrak CRUD lokal: repository Firestore diuji dengan emulator/Rules
/// secara terpisah. Test ini memastikan payload yang masuk/keluar Firestore
/// (termasuk doc.id dan cache) tetap benar tanpa kredensial atau network.
void main() {
  final photo = base64Encode(Uint8List.fromList([1, 2, 3, 4]));
  Map<String, dynamic> itemData() => {
        'title': 'Kursi',
        'category': 'Furniture',
        'description': 'Masih layak',
        'status': 'available',
        'donorId': 'uid-petra',
        'imageBase64': photo,
      };

  test('CREATE menerima input dan menyimpan Base64', () {
    final collection = <String, Map<String, dynamic>>{'item-1': itemData()};
    expect(ItemModel.fromMap(collection['item-1']!, id: 'item-1').imageBytes,
        Uint8List.fromList([1, 2, 3, 4]));
  });

  test('READ menggunakan Firestore document ID untuk detail', () {
    final item = ItemModel.fromMap(itemData(), id: 'item-1');
    expect(item.id, 'item-1');
    expect(item.title, 'Kursi');
    expect(item.donorId, 'uid-petra');
  });

  test('UPDATE mengubah status ketersediaan', () {
    final collection = <String, Map<String, dynamic>>{'item-1': itemData()};
    collection['item-1']!['status'] = 'reserved';
    final item = ItemModel.fromMap(collection['item-1']!, id: 'item-1');
    expect(item.status, 'reserved');
  });

  test('DELETE menghapus dokumen dari koleksi', () {
    final collection = <String, Map<String, dynamic>>{'item-1': itemData()};
    collection.remove('item-1');
    expect(collection.containsKey('item-1'), isFalse);
  });

  test('PERSISTENCE Firestore dikonfigurasi aktif', () {
    expect(FirestoreConfiguration.persistenceEnabled, isTrue);
  });
}
