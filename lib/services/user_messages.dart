import 'dart:async';

// firebase_auth juga mengekspor FirebaseException dari firebase_core.
import 'package:firebase_auth/firebase_auth.dart';

/// Hasil operasi tulis Firestore dari sudut pandang pengguna.
enum WriteOutcome {
  /// Server sudah mengonfirmasi perubahan.
  synced,

  /// Belum ada konfirmasi server dalam batas waktu. Dengan offline
  /// persistence, perubahan sudah diterapkan di cache perangkat dan
  /// diantrekan; Firestore mengirimnya otomatis saat koneksi kembali.
  queued,
}

/// Menunggu operasi tulis Firestore dengan batas waktu.
///
/// Future tulis Firestore baru selesai setelah server mengonfirmasi. Tanpa
/// batas waktu, saat offline tombol akan berputar terus dan pengguna tidak
/// tahu apa yang terjadi.
Future<WriteOutcome> awaitWrite(
  Future<void> write, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    await write.timeout(timeout);
    return WriteOutcome.synced;
  } on TimeoutException {
    return WriteOutcome.queued;
  }
}

/// Pesan tambahan bila server belum mengonfirmasi dalam batas waktu.
const queuedSuffix =
    'Koneksi sedang lambat atau terputus. Perubahan sedang diproses dan akan '
    'terkirim otomatis saat koneksi kembali.';

/// Mengubah exception menjadi pesan yang bisa dipahami pengguna.
String friendlyError(Object error, {required String fallback}) {
  if (error is FirebaseAuthException) {
    if (error.code == 'network-request-failed') {
      return 'Tidak ada koneksi internet. Periksa koneksi lalu coba lagi.';
    }
    return fallback;
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
        return 'Tidak ada koneksi internet. Periksa koneksi lalu coba lagi.';
      case 'permission-denied':
        return 'Akses ditolak server. Pastikan kamu berhak melakukan aksi ini.';
      case 'not-found':
        return 'Data tidak ditemukan. Mungkin sudah dihapus.';
      case 'deadline-exceeded':
        return 'Server terlalu lama merespons. Coba lagi sebentar lagi.';
      default:
        return fallback;
    }
  }
  if (error is TimeoutException) {
    return 'Proses terlalu lama. Periksa koneksi lalu coba lagi.';
  }
  // Exception('...') dari repository berisi pesan yang sudah ramah pengguna.
  if (error is Exception) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
  }
  return fallback;
}
