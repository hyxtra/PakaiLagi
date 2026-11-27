import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../repositories/firebase_repository.dart';
import '../services/firebase_auth_service.dart';

/// Hasil proses masuk/daftar berbasis email.
enum AuthFlowResult {
  signedIn,
  needsEmailVerification,
}

/// Menyimpan profil aplikasi untuk sesi Firebase Auth yang sedang aktif.
/// Identitas pemilik data selalu Firebase UID, bukan email atau nama tampilan.
class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier({
    required FirebaseAuthService authService,
    required FirebaseRepository repository,
  })  : _authService = authService,
        _repository = repository,
        super(null) {
    _restoreSession();
  }

  /// Notifier tanpa Firebase untuk widget tests yang tidak menguji autentikasi.
  AuthNotifier.forTest()
      : _authService = null,
        _repository = null,
        super(null);

  final FirebaseAuthService? _authService;
  final FirebaseRepository? _repository;

  /// Email dari sesi Firebase yang menunggu verifikasi (jika ada).
  String? get pendingVerificationEmail =>
      _authService?.pendingUnverifiedUser?.email;

  Future<void> _restoreSession() async {
    try {
      final firebaseUser = await _authService!.restoreUser();
      if (firebaseUser == null || firebaseUser.isAnonymous) return;
      if (!FirebaseAuthService.isAccountVerified(firebaseUser)) return;
      state = await _loadProfile(firebaseUser);
    } catch (_) {
      // Layar masuk tetap dapat digunakan saat profil belum dapat dibaca.
    }
  }

  /// Masuk menggunakan akun Google asli dan sinkronkan profil ke Firestore.
  Future<void> signInWithGoogle() async {
    final firebaseUser = await _authService!.signInWithGoogle();
    final existing = await _repository!.getMyProfileOnce(firebaseUser.uid);
    final googleEmail = firebaseUser.email?.trim() ?? '';
    final fallbackName = _prettify(googleEmail.split('@').first);
    final googleName = (firebaseUser.displayName?.trim().isNotEmpty == true)
        ? firebaseUser.displayName!.trim()
        : (fallbackName.isNotEmpty ? fallbackName : 'Pengguna');

    final profile = existing == null
        ? AppUser(
            id: firebaseUser.uid,
            name: googleName,
            email: googleEmail,
            phone: '',
            address: '',
          )
        : existing.copyWith(
            name: (existing.name.trim().isEmpty || existing.name == 'Pengguna')
                ? googleName
                : existing.name,
            email: existing.email.trim().isEmpty ? googleEmail : existing.email,
          );

    if (existing == null ||
        existing.name != profile.name ||
        existing.email != profile.email) {
      await _repository.saveMyProfile(
        name: profile.name,
        email: profile.email,
        phone: profile.phone,
        address: profile.address,
        kelurahan: profile.kelurahan,
        kota: profile.kota,
        latitude: profile.latitude,
        longitude: profile.longitude,
      );
    }
    state = profile;
  }

  Future<AuthFlowResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final firebaseUser = await _authService!.registerWithEmail(
      name: name,
      email: email,
      password: password,
    );
    // Jika UID ini sebelumnya anonim, profil dan barang lamanya tetap dipakai.
    final existing = await _repository!.getMyProfileOnce(firebaseUser.uid);
    final profile = existing?.copyWith(
          name: name.trim(),
          email: firebaseUser.email ?? email.trim(),
        ) ??
        AppUser(
          id: firebaseUser.uid,
          name: name.trim(),
          email: firebaseUser.email ?? email.trim(),
          phone: '',
          address: '',
        );
    await _repository.saveMyProfile(
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      address: profile.address,
      kelurahan: profile.kelurahan,
      kota: profile.kota,
      latitude: profile.latitude,
      longitude: profile.longitude,
    );
    if (!FirebaseAuthService.isAccountVerified(firebaseUser)) {
      state = null;
      return AuthFlowResult.needsEmailVerification;
    }
    state = profile;
    return AuthFlowResult.signedIn;
  }

  Future<AuthFlowResult> signIn({
    required String email,
    required String password,
  }) async {
    final firebaseUser = await _authService!.signInWithEmail(
      email: email,
      password: password,
    );
    if (!FirebaseAuthService.isAccountVerified(firebaseUser)) {
      try {
        await _authService.sendEmailVerification();
      } on FirebaseAuthException {
        // Tetap arahkan ke panel verifikasi meski rate-limit kirim ulang aktif.
      }
      state = null;
      return AuthFlowResult.needsEmailVerification;
    }
    state = await _loadProfile(firebaseUser);
    return AuthFlowResult.signedIn;
  }

  /// Memeriksa ke server Firebase apakah pengguna sudah mengklik tautan
  /// verifikasi email. Mengembalikan true jika sudah terverifikasi dan masuk.
  Future<bool> completeEmailVerification() async {
    final refreshed = await _authService!.reloadCurrentUser();
    if (refreshed == null || !FirebaseAuthService.isAccountVerified(refreshed)) {
      return false;
    }
    state = await _loadProfile(refreshed);
    return true;
  }

  /// Mengirim ulang email verifikasi.
  Future<void> resendVerificationEmail() async {
    await _authService!.sendEmailVerification();
  }

  /// Membatalkan sesi yang belum diverifikasi agar pengguna bisa ganti akun.
  Future<void> cancelPendingVerification() async {
    await signOut();
  }

  Future<AppUser> _loadProfile(User firebaseUser) async {
    final saved = await _repository!.getMyProfileOnce(firebaseUser.uid);
    if (saved != null) return saved;
    final email = firebaseUser.email ?? '';
    final localName = email.split('@').first;
    final display = firebaseUser.displayName?.trim();
    return AppUser(
      id: firebaseUser.uid,
      name: (display != null && display.isNotEmpty)
          ? display
          : _prettify(localName),
      email: email,
      phone: '',
      address: '',
    );
  }

  Future<void> signOut() async {
    await _authService!.signOut();
    state = null;
  }

  void updateUser({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? kelurahan,
    String? kota,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(
      name: name,
      email: email,
      phone: phone,
      address: address,
      kelurahan: kelurahan,
      kota: kota,
      latitude: latitude,
      longitude: longitude,
      clearCoordinates: clearCoordinates,
    );
  }

  static String _prettify(String raw) => raw
      .replaceAll(RegExp(r'[._-]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .map((word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier(
    authService: ref.watch(firebaseAuthServiceProvider),
    repository: ref.watch(firebaseRepositoryProvider),
  );
});

/// Convenience: apakah sudah login dan memuat profil.
final isLoggedInProvider =
    Provider<bool>((ref) => ref.watch(authProvider) != null);
