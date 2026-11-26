import 'dart:convert';
import 'dart:typed_data';

/// Helper murni untuk format gambar Base64 mentah yang dipakai Firestore.
abstract final class ImageBase64 {
  /// Batas panjang string Base64 yang diterima `firestore.rules`
  /// (`imageBase64.size() < 900000`). Sisa dari 1 MiB per dokumen dipakai
  /// field lain (judul, deskripsi, dst.).
  static const int maxEncodedLength = 900000;

  /// Anggaran per foto saat sebuah dokumen berisi galeri maksimal lima foto.
  /// 5 × 175 KB Base64 = 875 KB, menyisakan ruang bagi field dokumen.
  static const int maxPhotoCount = 5;
  static const int maxPhotoEncodedLength = 175000;
  static const int maxGalleryEncodedLength = 875000;

  static String encode(Uint8List bytes) => base64Encode(bytes);

  /// Panjang string Base64 untuk [byteLength] byte: 4 karakter per 3 byte,
  /// dibulatkan ke atas (termasuk padding `=`).
  static int encodedLength(int byteLength) => 4 * ((byteLength + 2) ~/ 3);

  /// Apakah foto sebesar [byteLength] byte masih muat dalam batas dokumen.
  static bool fitsFirestoreLimit(int byteLength) =>
      encodedLength(byteLength) < maxEncodedLength;

  static Uint8List? decodeOrNull(String value) {
    if (value.isEmpty) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }
}
