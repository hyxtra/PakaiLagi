// FILE SEMENTARA: bukti guard double-submit, errorBuilder, metode terkirim.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:pakailagi/models/app_user.dart';
import 'package:pakailagi/models/item.dart';
import 'package:pakailagi/notifiers/item_notifier.dart';
import 'package:pakailagi/notifiers/item_state.dart';
import 'package:pakailagi/providers/auth_provider.dart';
import 'package:pakailagi/providers/cloud_item_provider.dart';
import 'package:pakailagi/repositories/item_repository.dart';
import 'package:pakailagi/screens/post_item_screen.dart';
import 'package:pakailagi/theme/app_palette.dart';

class _FakeNotifier extends PostItemNotifier {
  _FakeNotifier(PostItemState s) : super(const ItemRepository(), _R()) {
    state = s;
  }
  @override
  Future<void> loadCategories() async {}
}

class _R implements Ref {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

/// Menghitung pemanggilan publishItem dan menahannya sampai dilepas.
class _CountingNotifier extends StateNotifier<PublishState>
    implements CloudItemNotifier {
  _CountingNotifier() : super(const PublishIdle());
  int calls = 0;
  List<String>? lastMethods;
  final gate = Completer<WriteOutcome?>();

  @override
  Future<WriteOutcome?> publishItem({
    required String title,
    required String category,
    required String description,
    required Uint8List imageBytes,
    required String ownerName,
    required AppUser pickupAddress,
    required List<String> pickupMethods,
  }) {
    calls++;
    lastMethods = pickupMethods;
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _FakePicker extends ImagePickerPlatform {
  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async =>
      [
        XFile.fromData(Uint8List.fromList([1, 2, 3]),
            path: '/data/cache/hilang/foto.jpg'),
      ];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    // Berkas tidak ada di disk -> menyerupai cache yang sudah dibersihkan.
    return XFile.fromData(Uint8List.fromList([1, 2, 3]),
        path: '/data/cache/hilang/foto.jpg');
  }
}

const _profile = AppUser(
  id: 'u1',
  name: 'Petra Vireta',
  email: 'p@x.com',
  phone: '081',
  address: 'Jl. Kenanga No. 10',
  kelurahan: 'Melati',
  kota: 'Jakarta Selatan',
);

void main() {
  testWidgets('Post dua kali berturut-turut hanya mengirim satu kali',
      (t) async {
    ImagePickerPlatform.instance = _FakePicker();
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final counting = _CountingNotifier();
    await t.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => AuthNotifier.forTest()),
        postItemNotifierProvider.overrideWith((_) => _FakeNotifier(
            const PostItemLoaded(categories: [Category('Pakaian', '👕')]))),
        cloudItemNotifierProvider.overrideWith((ref) => counting),
        cloudProfileProvider.overrideWith((ref) => Stream.value(_profile)),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppPalette.light]),
        home: const PostItemScreen(),
      ),
    ));
    await t.pumpAndSettle();

    // 1) Pilih foto (berkas sementara tidak ada) -> pratinjau pengganti.
    await t.tap(find.text('Tambah Foto'), warnIfMissed: false);
    await t.pumpAndSettle();
    await t.tap(find.text('Pilih dari Galeri'));
    await t.pumpAndSettle();
    // Image.file membaca berkas lewat I/O asli; beri waktu di luar jam palsu.
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(
        find.text('Foto tidak dapat ditampilkan. Ketuk untuk memilih ulang.'),
        findsOneWidget,
        reason: 'errorBuilder pratinjau foto harus tampil, bukan layar error');
    expect(t.takeException(), isNull);

    // 2) Isi form.
    Finder byHint(String s) => find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText ?? '').startsWith(s));
    await t.enterText(byHint('Mis. Meja'), 'Meja belajar');
    await t.tap(find.textContaining('Pakaian'));
    await t.pump();
    await t.dragUntilVisible(find.text('Deskripsi'),
        find.byType(ListView).first, const Offset(0, -200));
    await t.enterText(byHint('Ceritakan'), 'Masih bagus dan kokoh');
    await t.dragUntilVisible(find.textContaining('Bertemu (COD)'),
        find.byType(ListView).first, const Offset(0, -200));
    await t.tap(find.textContaining('Bertemu (COD)'));
    await t.pump();
    await t.dragUntilVisible(
        find.text('Post'), find.byType(ListView).first, const Offset(0, -200));
    await t.pump();

    // 3) Dua ketukan beruntun TANPA frame di antaranya (tombol belum sempat
    //    dinonaktifkan oleh rebuild).
    await t.tap(find.text('Post'));
    await t.tap(find.text('Post'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    // ignore: avoid_print
    print('[HASIL] publishItem dipanggil ${counting.calls}x, '
        'metode=${counting.lastMethods}');
    expect(counting.calls, 1, reason: 'double-submit membuat dokumen ganda');
    expect(counting.lastMethods, ['Bertemu (COD)'],
        reason: 'hanya metode yang dipilih pemberi yang dikirim');
    expect(find.text('Memposting barang…'), findsOneWidget,
        reason: 'tombol harus menunjukkan proses');

    // 4) Selesai -> form di-reset, SnackBar hijau, tombol aktif kembali.
    counting.gate.complete(WriteOutcome.synced);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    // ignore: avoid_print
    print(
        '[HASIL] SnackBar ditemukan: ${find.byType(SnackBar).evaluate().length}, teks sukses: ${find.text('Barang berhasil diposting!').evaluate().length}');
    expect(find.text('Barang berhasil diposting!'), findsOneWidget);
    final bar = t.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, AppPalette.light.primary);
    // Gulir ke atas agar field Judul kembali dibangun, lalu periksa isinya.
    await t.dragUntilVisible(find.text('Foto Barang'),
        find.byType(ListView).first, const Offset(0, 300));
    final title = t.widget<TextField>(byHint('Mis. Meja'));
    expect(title.controller!.text, isEmpty, reason: 'form harus direset');
    expect(find.text('Tambah Foto'), findsWidgets,
        reason: 'foto terpilih harus dikosongkan');
    // ignore: avoid_print
    print('[HASIL] setelah sukses: form kosong, SnackBar hijau tampil');
  });
}
