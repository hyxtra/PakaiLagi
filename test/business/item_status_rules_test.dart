import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/business/item_status_rules.dart';

void main() {
  test('hanya status MVP yang valid', () {
    expect(ItemStatusRules.isValid('available'), isTrue);
    expect(ItemStatusRules.isValid('reserved'), isTrue);
    expect(ItemStatusRules.isValid('completed'), isTrue);
    expect(ItemStatusRules.isValid('claimed'), isFalse);
  });

  test('available dapat menjadi reserved saat pengajuan diterima', () {
    expect(ItemStatusRules.canTransition(from: 'available', to: 'reserved'),
        isTrue);
  });

  test('transisi status yang tidak sesuai ditolak', () {
    expect(ItemStatusRules.canTransition(from: 'available', to: 'completed'),
        isFalse);
    expect(ItemStatusRules.canTransition(from: 'completed', to: 'available'),
        isFalse);
  });
}
