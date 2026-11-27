import 'dart:async';

// firebase_auth juga mengekspor FirebaseException dari firebase_core.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_auth_service.dart';

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
  if (error is GoogleSignInCancelledException) {
    return 'Masuk dengan Google dibatalkan.';
  }
  if (error is GoogleSignInException) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Masuk dengan Google dibatalkan.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Konfigurasi Google Sign-In belum lengkap (aktifkan Google & daftar SHA-1 di Firebase Console).';
      case GoogleSignInExceptionCode.interrupted:
        return 'Proses masuk Google terganggu. Silakan coba lagi.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Layar pemilihan akun Google tidak tersedia di perangkat ini.';
      default:
        return fallback;
    }
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'network-request-failed':
        return 'Tidak ada koneksi internet. Periksa koneksi lalu coba lagi.';
      case 'email-already-in-use':
        return 'Email ini sudah terdaftar. Pilih Masuk atau gunakan email lain.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau kata sandi salah.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan. Hubungi pengelola aplikasi.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
      case 'operation-not-allowed':
        return 'Metode login ini belum diaktifkan di Firebase Console.';
      case 'credential-already-in-use':
        return 'Akun ini sudah terhubung ke pengguna lain. Coba masuk langsung dengan akun tersebut.';
      case 'account-exists-with-different-credential':
        return 'Email ini sudah terdaftar dengan metode masuk lain.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Jendela masuk Google ditutup sebelum selesai.';
      default:
        return fallback;
    }
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
