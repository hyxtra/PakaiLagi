import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/business/item_ownership.dart';

void main() {
  test('pemilik item boleh melakukan update atau delete', () {
    expect(
      ItemOwnership.canModify(donorId: 'uid-petra', currentUserId: 'uid-petra'),
      isTrue,
    );
  });

  test('pengguna lain tidak boleh mengubah item', () {
    expect(
      ItemOwnership.canModify(donorId: 'uid-petra', currentUserId: 'uid-lain'),
      isFalse,
    );
  });

  test('UID kosong atau null tidak mendapat akses', () {
    expect(ItemOwnership.canModify(donorId: '', currentUserId: 'uid-petra'),
        isFalse);
    expect(ItemOwnership.canModify(donorId: 'uid-petra', currentUserId: null),
        isFalse);
  });
}
