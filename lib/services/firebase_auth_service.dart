import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// firebase_auth_service.dart
// Service layer untuk Firebase Authentication.
//
// TANGGUNG JAWAB:
//   - Daftar/masuk dengan email dan kata sandi
//   - Menautkan sesi anonim lama saat pendaftaran agar UID dan barangnya tetap
//   - Menyediakan UID Firebase untuk kepemilikan data Firestore
//
// Sesi anonim tetap didukung untuk data lama dan bisa ditautkan ke akun baru.
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

  /// Daftar akun email/password. Jika sesi anonim lama masih aktif, tautkan
  /// kredensial supaya UID dan barang yang sudah diposting tetap sama.
  Future<User> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    final current = _auth.currentUser ?? await _auth.authStateChanges().first;
    final user = current?.isAnonymous == true
        ? (await current!.linkWithCredential(credential)).user!
        : (await _auth.createUserWithEmailAndPassword(
                email: email.trim(), password: password))
            .user!;
    await user.updateDisplayName(name.trim());
    return user;
  }

  /// Masuk ke akun Firebase yang sudah terdaftar dengan email/password.
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Akun Firebase tidak ditemukan.');
    return user;
  }

  /// Menunggu Firebase memulihkan sesi yang tersimpan tanpa membuat sesi baru.
  Future<User?> restoreUser() async =>
      _auth.currentUser ?? await _auth.authStateChanges().first;

  /// Memastikan ada sesi Firebase sebelum mengakses Firestore.
  ///
  /// Menunggu event pertama [authStateChanges] agar sesi tersimpan sempat
  /// dipulihkan (di Web `currentUser` masih null sesaat setelah start).
  /// Tanpa penantian ini, aplikasi bisa membuat akun anonim baru dan
  /// kehilangan kepemilikan barang yang sudah diposting.
  Future<User> ensureSignedIn() async {
    final restored = _auth.currentUser ?? await _auth.authStateChanges().first;
    if (restored != null) return restored;
    final user = await signInAnonymously();
    if (user == null) throw Exception('Gagal terhubung ke akun Firebase.');
    return user;
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

/// UID akun Firebase aktif saat ini (null bila belum login).
final currentFirebaseUidProvider = Provider<String?>((ref) {
  return ref.watch(firebaseAuthStateProvider).valueOrNull?.uid;
});
