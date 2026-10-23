import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/validators/item_validator.dart';

void main() {
  test('judul wajib diisi', () {
    expect(ItemValidator.validateTitle('   '), 'Judul wajib diisi');
    expect(ItemValidator.validateTitle('Meja belajar'), isNull);
  });

  test('kategori wajib dipilih', () {
    expect(
        ItemValidator.validateCategory(null), 'Pilih kategori barang dulu ya');
    expect(ItemValidator.validateCategory('Furniture'), isNull);
  });

  test('deskripsi minimal lima karakter', () {
    expect(ItemValidator.validateDescription('baru'),
        'Deskripsi minimal 5 karakter');
    expect(ItemValidator.validateDescription('Masih layak'), isNull);
  });
}
