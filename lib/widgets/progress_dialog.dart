import 'package:flutter/material.dart';

import '../services/user_messages.dart';
import '../theme/app_palette.dart';

/// Menjalankan [task] sambil menampilkan dialog progres yang tidak bisa
/// ditutup. Mencegah ketukan ganda dan memberi tahu pengguna bahwa aplikasi
/// sedang bekerja. Dialog selalu ditutup, baik [task] berhasil maupun gagal.
Future<T> runWithProgress<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() task,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(width: 18),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    navigator.pop();
  }
}

/// Jenis umpan balik. Menentukan warna dan ikon SnackBar.
enum SnackKind {
  /// Informasi netral / belum pasti (mis. perubahan masih menunggu koneksi).
  info,

  /// Aksi berhasil (hijau).
  success,

  /// Aksi gagal atau input salah (merah).
  error,
}

/// Pembungkus ScaffoldMessenger + palet tema, diambil SEBELUM `await`
/// (seperti `ScaffoldMessenger.of(context)`) supaya aman dipakai setelah
/// layar ditutup.
class AppMessenger {
  AppMessenger._(this._messenger, this._palette);

  factory AppMessenger.of(BuildContext context) =>
      AppMessenger._(ScaffoldMessenger.of(context), context.palette);

  final ScaffoldMessengerState _messenger;
  final AppPalette _palette;

  /// Warna latar & teks per jenis. Rasio kontras (WCAG) sudah ≥ 4,5:1:
  /// terang → hijau/putih 6,29, merah/putih 4,96; gelap → hijau/gelap 7,99,
  /// merah/gelap 6,43.
  (Color? background, Color foreground, IconData? icon) _style(
          SnackKind kind) =>
      switch (kind) {
        SnackKind.success => (
            _palette.primary,
            _palette.onPrimary,
            Icons.check_circle_outline
          ),
        SnackKind.error => (
            _palette.danger,
            _palette.onDanger,
            Icons.error_outline
          ),
        // Bawaan Material: abu gelap, kontras tinggi dengan teks terang.
        SnackKind.info => (null, Colors.white, Icons.info_outline),
      };

  /// Menampilkan SnackBar dan menggantikan yang sebelumnya agar pesan
  /// terbaru langsung terlihat. Pesan error tampil lebih lama (5 detik).
  void show(
    String message, {
    SnackKind kind = SnackKind.info,
    SnackBarAction? action,
  }) {
    final (background, foreground, icon) = _style(kind);
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: kind == SnackKind.error ? 5 : 4),
        action: action,
        content: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              // Ikon = penanda kedua selain warna (pengguna buta warna).
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: TextStyle(color: foreground)),
              ),
            ],
          ),
        ),
      ));
  }

  void success(String message, {SnackBarAction? action}) =>
      show(message, kind: SnackKind.success, action: action);

  void error(String message) => show(message, kind: SnackKind.error);

  /// Hasil aksi tulis: hijau bila server sudah mengonfirmasi, netral bila
  /// masih menunggu koneksi (tidak menjanjikan hal yang belum pasti).
  void result(WriteOutcome outcome, {required String done, String? queued}) {
    if (outcome == WriteOutcome.synced) {
      success(done);
    } else {
      info(queued ?? '$done $queuedSuffix');
    }
  }

  void info(String message, {SnackBarAction? action}) =>
      show(message, kind: SnackKind.info, action: action);
}

/// Pintasan lama: `isError: true` → merah, selain itu sesuai [kind].
void showAppSnackBar(
  AppMessenger messenger,
  String message, {
  SnackKind kind = SnackKind.info,
  bool isError = false,
}) =>
    messenger.show(message, kind: isError ? SnackKind.error : kind);
