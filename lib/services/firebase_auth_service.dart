import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// firebase_auth_service.dart
// Service layer untuk autentikasi Firebase — 100% Cloud-only.
//
// TANGGUNG JAWAB:
//   - Login anonim (signInAnonymously) → mendapatkan uid unik
//   - Sign out dari Firebase
//   - Menyediakan uid untuk operasi Firestore (donorId)
//
// MENGAPA ANONYMOUS AUTH?
//   Pada tahap development/testing, kita hanya butuh uid unik untuk menandai
//   siapa pemilik barang (donorId). Anonymous auth adalah cara tercepat tanpa
//   perlu form registrasi email/password.
//
// DIPAKAI OLEH: FirebaseRepository (untuk donorId saat publishItem)
// =============================================================================

class FirebaseAuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  // ---------------------------------------------------------------------------
  // LOGIN ANONIM
  // ---------------------------------------------------------------------------

  /// Login anonim. Firebase akan membuat akun baru jika belum pernah login,
  /// atau me-restore session yang sudah ada.
  /// Return: [User] yang berhasil login, atau null jika gagal.
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception('Gagal login anonim: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // SIGN OUT
  // ---------------------------------------------------------------------------

  /// Logout dari Firebase.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // GETTER
  // ---------------------------------------------------------------------------

  /// User Firebase yang sedang aktif. Null jika belum login.
  User? get currentUser => _auth.currentUser;

  /// UID user yang sedang aktif. Null jika belum login.
  String? get currentUid => _auth.currentUser?.uid;

  /// Stream perubahan status autentikasi (login/logout).
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

// =============================================================================
// PROVIDER DEFINITIONS
// =============================================================================

/// Provider untuk FirebaseAuth instance.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider untuk FirebaseAuthService.
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return FirebaseAuthService(auth);
});

/// Stream provider: memantau perubahan status auth secara reaktif.
/// UI bisa `ref.watch(firebaseAuthStateProvider)` untuk mendapat
/// AsyncValue<User?> yang otomatis rebuild saat login/logout.
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return authService.authStateChanges;
});
