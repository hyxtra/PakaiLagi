// FILE SEMENTARA: verifikasi Beranda P10 (overflow + mode pinned/scroll).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pakailagi/models/item_model.dart';
import 'package:pakailagi/providers/cloud_item_provider.dart';
import 'package:pakailagi/providers/notification_provider.dart';
import 'package:pakailagi/screens/home_screen.dart';
import 'package:pakailagi/theme/app_palette.dart';

final _items = [
  for (var i = 0; i < 6; i++)
    ItemModel(
      id: 'i$i',
      title: 'Barang nomor $i dengan judul yang cukup panjang untuk dua baris',
      category: i.isEven ? 'Furniture' : 'Peralatan Rumah Tangga',
      description: 'd',
      ownerName: 'Petra Vireta',
      donorId: 'u$i',
    ),
];

Widget app(double scale, bool empty) => ProviderScope(
      overrides: [
        cloudItemsStreamProvider.overrideWith(
            (ref) => Stream.value(empty ? <ItemModel>[] : _items)),
        unreadCloudNotificationsCountProvider.overrideWith((ref) => 0),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppPalette.light]),
        builder: (c, child) => MediaQuery(
          data:
              MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        // Bilah navigasi bawah 72 dp, seperti ScaffoldWithNavBar di aplikasi.
        home: const Scaffold(
          body: HomeScreen(),
          bottomNavigationBar: SizedBox(height: 72),
        ),
      ),
    );

void main() {
  test('homeShouldPinHeader: HP biasa pinned, layar pendek scroll', () {
    // HP 360x800 font normal: tinggi tersedia ~ 800-24-72
    expect(homeShouldPinHeader(availableHeight: 700, textScale: 1.0), isTrue);
    // HP 320x568 font normal
    expect(homeShouldPinHeader(availableHeight: 472, textScale: 1.0), isTrue);
    // HP landscape 360 tinggi
    expect(homeShouldPinHeader(availableHeight: 264, textScale: 1.0), isFalse);
    // 320x568 font 2x
    expect(homeShouldPinHeader(availableHeight: 472, textScale: 2.0), isFalse);
  });

  for (final (name, w, h, dpr, scale, empty) in [
    ('portrait 360x800 1.0x', 1080.0, 2400.0, 3.0, 1.0, false),
    ('portrait 360x800 1.6x', 1080.0, 2400.0, 3.0, 1.6, false),
    ('portrait 360x800 2.0x', 1080.0, 2400.0, 3.0, 2.0, false),
    ('kecil 320x568 1.0x', 960.0, 1704.0, 3.0, 1.0, false),
    ('kecil 320x568 1.6x', 960.0, 1704.0, 3.0, 1.6, false),
    ('kecil 320x568 2.0x', 960.0, 1704.0, 3.0, 2.0, false),
    ('kecil 320x568 2.0x KOSONG', 960.0, 1704.0, 3.0, 2.0, true),
    ('landscape 800x360 1.0x', 2400.0, 1080.0, 3.0, 1.0, false),
    ('landscape 800x360 1.6x', 2400.0, 1080.0, 3.0, 1.6, false),
    ('landscape 800x360 2.0x', 2400.0, 1080.0, 3.0, 2.0, false),
    ('landscape 800x360 2.0x KOSONG', 2400.0, 1080.0, 3.0, 2.0, true),
    ('landscape 800x360 1.0x KOSONG', 2400.0, 1080.0, 3.0, 1.0, true),
    ('tablet 768x1024 1.6x', 1536.0, 2048.0, 2.0, 1.6, false),
    ('tablet 768x1024 2.0x', 1536.0, 2048.0, 2.0, 2.0, false),
    ('desktop 1280x800 1.0x', 1280.0, 800.0, 1.0, 1.0, false),
  ]) {
    testWidgets('Beranda $name', (t) async {
      t.view.physicalSize = Size(w, h);
      t.view.devicePixelRatio = dpr;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(scale, empty));
      await t.pumpAndSettle();
      final errors = <Object>[];
      Object? e;
      while ((e = t.takeException()) != null) {
        errors.add(e!);
      }
      // Mode: header tersemat bila SingleChildScrollView penyusun Beranda tak ada.
      final scrollMode = find
          .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(SingleChildScrollView))
          .evaluate()
          .isNotEmpty;
      // ignore: avoid_print
      print('[HASIL] $name -> ${errors.isEmpty ? "AMAN" : "OVERFLOW(${errors.length})"} '
          'mode=${scrollMode ? "scroll-semua" : "pinned"}');
      if (!empty) {
        // Isi daftar bisa dijangkau: kartu pertama ada di pohon widget.
        expect(find.textContaining('Barang nomor 0'), findsWidgets);
      }
      expect(errors, isEmpty, reason: 'overflow pada $name');
    });
  }
}
