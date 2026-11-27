import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

// =============================================================================
// firebase_auth_service.dart
// Service layer untuk Firebase Authentication.
//
// TANGGUNG JAWAB:
//   - Masuk dengan akun Google asli (Google Sign-In / Credential Manager)
//   - Daftar/masuk dengan email & kata sandi + verifikasi email resmi Firebase
//   - Menautkan sesi anonim lama saat pendaftaran/login agar UID tetap
//   - Menyediakan UID Firebase untuk kepemilikan data Firestore
//
// DIPAKAI OLEH: FirebaseRepository (untuk donorId saat publishItem)
// =============================================================================

/// Dilempar saat pengguna menutup/membatalkan pop-up masuk Google.
class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}

class FirebaseAuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;
  Future<void>? _googleInitFuture;

  static bool isAccountVerified(User user) {
    if (user.emailVerified) return true;
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitFuture ??= GoogleSignIn.instance.initialize();
  }

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
  // LOGIN GOOGLE ASLI
  // ---------------------------------------------------------------------------

  Future<User> _linkAnonymousOrSignIn({
    required User? current,
    required Future<UserCredential> Function(User anonUser) link,
    required Future<UserCredential> Function() signIn,
  }) async {
    final UserCredential result;
    if (current?.isAnonymous == true) {
      UserCredential? linked;
      try {
        linked = await link(current!);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use') rethrow;
      }
      result = linked ?? await signIn();
    } else {
      result = await signIn();
    }
    final user = result.user;
    if (user == null) throw Exception('Akun Google tidak ditemukan.');
    return user;
  }

  /// Masuk dengan akun Google asli dan tautkan ke Firebase Auth.
  Future<User> signInWithGoogle() async {
    final current = _auth.currentUser ?? await _auth.authStateChanges().first;

    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      return _linkAnonymousOrSignIn(
        current: current,
        link: (anon) => anon.linkWithPopup(provider),
        signIn: () => _auth.signInWithPopup(provider),
      );
    }

    await _ensureGoogleInitialized();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleSignInCancelledException();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Token Google tidak tersedia. Pastikan Google Sign-In dan SHA-1 '
        'sudah terdaftar di Firebase Console.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _linkAnonymousOrSignIn(
      current: current,
      link: (anon) => anon.linkWithCredential(credential),
      signIn: () => _auth.signInWithCredential(credential),
    );
  }

  // ---------------------------------------------------------------------------
  // EMAIL & KATA SANDI + VERIFIKASI EMAIL
  // ---------------------------------------------------------------------------

  /// Daftar akun email/password lalu kirim email verifikasi resmi Firebase.
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
    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
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

  /// Mengirim ulang email verifikasi untuk pengguna yang belum terverifikasi.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Memuat ulang status pengguna dari server Firebase (mis. setelah klik link).
  Future<User?> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    return _auth.currentUser;
  }

  /// Pengguna email yang sedang menunggu verifikasi (belum boleh masuk Beranda).
  User? get pendingUnverifiedUser {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || isAccountVerified(user)) {
      return null;
    }
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

  /// Logout dari Firebase dan sesi Google Sign-In (jika aktif).
  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb && _googleInitFuture != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Abaikan jika Google Sign-In belum pernah dipakai pada sesi ini.
      }
    }
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
