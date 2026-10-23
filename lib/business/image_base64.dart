import 'dart:convert';
import 'dart:typed_data';

/// Helper murni untuk format gambar Base64 mentah yang dipakai Firestore.
abstract final class ImageBase64 {
  static String encode(Uint8List bytes) => base64Encode(bytes);

  static Uint8List? decodeOrNull(String value) {
    if (value.isEmpty) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }
}
