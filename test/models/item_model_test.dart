import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/models/item_model.dart';

void main() {
  test('fromMap memetakan data dan document ID secara eksplisit', () {
    final createdAt = Timestamp.fromDate(DateTime.utc(2026, 10, 21));
    final item = ItemModel.fromMap({
      'title': 'Buku Flutter',
      'category': 'Buku',
      'description': 'Buku kondisi baik',
      'status': 'available',
      'donorId': 'uid-petra',
      'ownerName': 'Petra',
      'imageBase64': 'AQID',
      'createdAt': createdAt,
    }, id: 'firestore-doc-1');

    expect(item.id, 'firestore-doc-1');
    expect(item.title, 'Buku Flutter');
    expect(item.donorId, 'uid-petra');
    expect(item.createdAt, createdAt.toDate());
  });

  test('fromMap memberi fallback aman untuk data null atau kosong', () {
    final item = ItemModel.fromMap(const {
      'title': null,
      'category': null,
      'description': null,
      'status': null,
      'donorId': null,
      'imageBase64': null,
      'createdAt': 'bukan timestamp',
    }, id: 'doc-empty');

    expect(item.id, 'doc-empty');
    expect(item.title, isEmpty);
    expect(item.category, isEmpty);
    expect(item.status, 'available');
    expect(item.donorId, isEmpty);
    expect(item.imageBytes, isNull);
    expect(item.createdAt, isNull);
  });
}
