import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/validators/item_validator.dart';

// =============================================================================
// test/validators/item_validator_test.dart
// Unit test untuk ItemValidator — mencakup 5 aturan validasi:
//   1. validateTitle       (judul barang)
//   2. validateCategory    (kategori)
//   3. validateDescription (deskripsi)
//   4. validatePickupMethods (metode pengambilan) ← BARU P9
//   5. validateImage       (foto barang)           ← BARU P9
//
// Semua test murni (pure function) — tidak butuh Flutter widget atau Firebase.
// =============================================================================

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. validateTitle
  // ─────────────────────────────────────────────────────────────────────────
  group('validateTitle', () {
    test('null → error wajib diisi', () {
      expect(ItemValidator.validateTitle(null), 'Judul wajib diisi');
    });

    test('string kosong → error wajib diisi', () {
      expect(ItemValidator.validateTitle(''), 'Judul wajib diisi');
    });

    test('hanya spasi → error wajib diisi', () {
      expect(ItemValidator.validateTitle('   '), 'Judul wajib diisi');
    });

    test('judul valid → null (lolos)', () {
      expect(ItemValidator.validateTitle('Meja belajar'), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. validateCategory
  // ─────────────────────────────────────────────────────────────────────────
  group('validateCategory', () {
    test('null → error pilih kategori', () {
      expect(
          ItemValidator.validateCategory(null), 'Pilih kategori barang dulu ya');
    });

    test('string kosong → error pilih kategori', () {
      expect(
          ItemValidator.validateCategory(''), 'Pilih kategori barang dulu ya');
    });

    test('kategori valid → null (lolos)', () {
      expect(ItemValidator.validateCategory('Furniture'), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. validateDescription
  // ─────────────────────────────────────────────────────────────────────────
  group('validateDescription', () {
    test('null → error minimal 5 karakter', () {
      expect(
          ItemValidator.validateDescription(null), 'Deskripsi minimal 5 karakter');
    });

    test('kurang dari 5 karakter → error minimal 5 karakter', () {
      expect(
          ItemValidator.validateDescription('baru'), 'Deskripsi minimal 5 karakter');
    });

    test('tepat 4 karakter (trim) → error', () {
      expect(
          ItemValidator.validateDescription('  ab  '), 'Deskripsi minimal 5 karakter');
    });

    test('tepat 5 karakter (trim) → null (lolos)', () {
      expect(ItemValidator.validateDescription('layak'), isNull);
    });

    test('deskripsi panjang → null (lolos)', () {
      expect(ItemValidator.validateDescription('Masih layak pakai'), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. validatePickupMethods  ← BARU P9
  // ─────────────────────────────────────────────────────────────────────────
  group('validatePickupMethods', () {
    test('set kosong → error pilih minimal satu', () {
      expect(
        ItemValidator.validatePickupMethods({}),
        'Pilih minimal satu metode pengambilan',
      );
    });

    test('satu metode dipilih → null (lolos)', () {
      expect(
        ItemValidator.validatePickupMethods({'Bertemu (COD)'}),
        isNull,
      );
    });

    test('beberapa metode dipilih → null (lolos)', () {
      expect(
        ItemValidator.validatePickupMethods({'Bertemu (COD)', 'Antar ke Alamat'}),
        isNull,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. validateImage  ← BARU P9
  // ─────────────────────────────────────────────────────────────────────────
  group('validateImage', () {
    test('null → error foto wajib ada', () {
      expect(
        ItemValidator.validateImage(null),
        'Foto barang wajib ditambahkan untuk post',
      );
    });

    test('string kosong → error foto wajib ada', () {
      expect(
        ItemValidator.validateImage(''),
        'Foto barang wajib ditambahkan untuk post',
      );
    });

    test('hanya spasi → error foto wajib ada', () {
      expect(
        ItemValidator.validateImage('   '),
        'Foto barang wajib ditambahkan untuk post',
      );
    });

    test('path valid → null (lolos)', () {
      expect(
        ItemValidator.validateImage('/storage/emulated/0/foto.jpg'),
        isNull,
      );
    });
  });
}
