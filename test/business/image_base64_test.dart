import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pakailagi/business/image_base64.dart';

void main() {
  test('encode gambar menghasilkan Base64 mentah yang tidak kosong', () {
    final result = ImageBase64.encode(Uint8List.fromList([1, 2, 3]));
    expect(result, isNotEmpty);
    expect(result, isNot(startsWith('data:image/')));
  });

  test('decode mengembalikan byte gambar asli', () {
    final bytes = Uint8List.fromList([7, 8, 9]);
    expect(ImageBase64.decodeOrNull(ImageBase64.encode(bytes)), bytes);
  });

  test('Base64 kosong atau rusak menghasilkan null', () {
    expect(ImageBase64.decodeOrNull(''), isNull);
    expect(ImageBase64.decodeOrNull('@@invalid@@'), isNull);
  });
}
