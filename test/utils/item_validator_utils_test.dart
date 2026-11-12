import 'package:flutter_test/flutter_test.dart';

// =============================================================================
// test/utils/item_validator_utils_test.dart
// Unit test via path alias `utils/item_validator.dart` (re-export P9).
//
// Membuktikan bahwa import dari `utils/` menghasilkan class yang identik
// dengan import langsung dari `validators/`.
// =============================================================================

// ignore: directives_ordering
import 'package:pakailagi/utils/item_validator.dart';

void main() {
  group('ItemValidator via utils/ alias (P9)', () {
    // Verifikasi bahwa re-export berfungsi — class yang sama, perilaku sama.

    test('validateTitle via utils/ path: null → error', () {
      expect(ItemValidator.validateTitle(null), 'Judul wajib diisi');
    });

    test('validateTitle via utils/ path: valid → null', () {
      expect(ItemValidator.validateTitle('Kursi lipat'), isNull);
    });

    test('validateCategory via utils/ path: null → error', () {
      expect(
          ItemValidator.validateCategory(null), 'Pilih kategori barang dulu ya');
    });

    test('validateDescription via utils/ path: pendek → error', () {
      expect(
          ItemValidator.validateDescription('ok'), 'Deskripsi minimal 5 karakter');
    });

    test('validatePickupMethods via utils/ path: kosong → error', () {
      expect(
        ItemValidator.validatePickupMethods({}),
        'Pilih minimal satu metode pengambilan',
      );
    });

    test('validateImage via utils/ path: null → error', () {
      expect(
        ItemValidator.validateImage(null),
        'Foto barang wajib ditambahkan untuk post',
      );
    });
  });
}

