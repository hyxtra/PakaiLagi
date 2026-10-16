import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';

/// State auth sederhana: null = belum login.
///
/// Sengaja dibungkus [StateNotifier] agar implementasi mock ini bisa diganti
/// ke Supabase Auth (atau backend lain) tanpa mengubah screen — cukup ganti
/// isi method [signIn]/[signOut] menjadi panggilan async ke backend.
class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  void signIn({required String name, required String email}) {
    final resolvedName = name.trim().isNotEmpty
        ? name.trim()
        : _prettify(email.trim().split('@').first);
    state = AppUser(
      id: 'user_${email.trim().hashCode}',
      name: resolvedName,
      email: email.trim(),
      phone: '',
      address: '',
    );
  }

  void signOut() => state = null;

  void updateUser(
      {String? name, String? email, String? phone, String? address}) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(
        name: name, email: email, phone: phone, address: address);
  }

  static String _prettify(String raw) {
    return raw
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AppUser?>((ref) => AuthNotifier());

/// Convenience: apakah sudah login.
final isLoggedInProvider =
    Provider<bool>((ref) => ref.watch(authProvider) != null);
