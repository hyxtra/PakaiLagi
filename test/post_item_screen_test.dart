import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pakailagi/models/item.dart';
import 'package:pakailagi/notifiers/item_notifier.dart';
import 'package:pakailagi/notifiers/item_state.dart';
import 'package:pakailagi/repositories/item_repository.dart';
import 'package:pakailagi/screens/post_item_screen.dart';
import 'package:pakailagi/theme/app_palette.dart';

// =============================================================================
// FILE 6: post_item_screen_test.dart
// Widget Test untuk memvalidasi kemunculan 6 kondisi UI pada PostItemScreen.
//
// Teknik testing:
// - Override [postItemNotifierProvider] langsung dengan state yang diinginkan,
//   sehingga test deterministik tanpa bergantung pada async timer.
// - Menggunakan [ProviderScope.overrides] agar test terisolasi.
// =============================================================================

/// Sampel kategori yang dipakai di beberapa test.
const _testCategories = [
  Category('Pakaian', '👕'),
  Category('Elektronik', '📱'),
  Category('Furniture', '🪑'),
];

/// Helper: membungkus PostItemScreen dengan MaterialApp + ProviderScope + Theme.
/// Override notifier provider langsung dengan state tertentu untuk determinisme.
Widget _buildTestAppWithState(PostItemState initialState) {
  final notifier = _FakePostItemNotifier(initialState);
  return ProviderScope(
    overrides: [
      postItemNotifierProvider.overrideWith((_) => notifier),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: const [AppPalette.light]),
      home: const PostItemScreen(),
    ),
  );
}

/// Fake notifier yang langsung set state tanpa async operations.
/// Semua method yang mengakses Ref atau Repository di-override agar
/// test bebas dari side-effect dan tidak membutuhkan mock Ref.
class _FakePostItemNotifier extends PostItemNotifier {
  _FakePostItemNotifier(PostItemState initial)
      : super(const _StubItemRepository(), const _FakeRef()) {
    state = initial;
  }

  /// Override loadCategories agar tidak melakukan fetch asli.
  @override
  Future<void> loadCategories() async {
    // no-op — state sudah di-set di constructor
  }

  /// Override submitItem agar tidak mengakses authProvider/itemsProvider.
  @override
  Future<bool> submitItem({
    required String title,
    required String category,
    required String description,
    required List<String> pickupMethods,
    required String address,
    String? imageUrl,
  }) async {
    // Simulasikan submit sukses tanpa side-effect
    return true;
  }
}

/// Stub repository dengan delay 0 — hanya memenuhi konstruktor notifier.
class _StubItemRepository extends ItemRepository {
  const _StubItemRepository()
      : super(
          fetchDelay: Duration.zero,
          simulateError: false,
          simulateEmpty: false,
        );
}

/// Fake Ref yang tidak melakukan apapun — aman karena submitItem di-override
/// sehingga Ref tidak pernah diakses secara nyata.
class _FakeRef implements Ref {
  const _FakeRef();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // TEST KONDISI 1: Initial Loading
  // Spinner/loading indicator saat data awal sedang dimuat.
  // ═══════════════════════════════════════════════════════════════════════════
  testWidgets('Kondisi 1: Menampilkan loading indicator saat memuat kategori',
      (tester) async {
    await tester.pumpWidget(
      _buildTestAppWithState(const PostItemLoading()),
    );

    // Verifikasi: CircularProgressIndicator tampil
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Verifikasi: teks loading tampil
    expect(find.text('Memuat data kategori...'), findsOneWidget);
    // Verifikasi: form BELUM tampil
    expect(find.text('Judul Barang'), findsNothing);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST KONDISI 2: Data Berhasil Dimuat
  // Form input ditampilkan dengan normal setelah kategori berhasil dimuat.
  // ═══════════════════════════════════════════════════════════════════════════
  testWidgets(
      'Kondisi 2: Menampilkan form lengkap setelah data berhasil dimuat',
      (tester) async {
    await tester.pumpWidget(
      _buildTestAppWithState(
        const PostItemLoaded(categories: _testCategories),
      ),
    );

    // Verifikasi: label & konten yang terlihat di atas viewport
    expect(find.text('Judul Barang'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.textContaining('Pakaian'), findsOneWidget);
    expect(find.textContaining('Elektronik'), findsOneWidget);
    // Verifikasi: loading sudah hilang
    expect(find.text('Memuat data kategori...'), findsNothing);

    // Scroll ke bawah untuk verifikasi field yang ada di bawah viewport
    final listView = find.byType(ListView);
    await tester.dragUntilVisible(
      find.text('Metode Pengambilan'),
      listView,
      const Offset(0, -300),
    );
    expect(find.text('Deskripsi'), findsOneWidget);
    expect(find.text('Metode Pengambilan'), findsOneWidget);
    expect(find.textContaining('Ambil Sendiri'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Alamat Penjemputan'),
      listView,
      const Offset(0, -300),
    );
    expect(find.text('Alamat Penjemputan'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Kirim'),
      listView,
      const Offset(0, -300),
    );
    // Verifikasi: tombol submit tampil
    expect(find.text('Kirim'), findsOneWidget);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST KONDISI 3: Empty State
  // Tampilan khusus jika data kategori ternyata kosong dari repository.
  // ═══════════════════════════════════════════════════════════════════════════
  testWidgets('Kondisi 3: Menampilkan empty state jika kategori kosong',
      (tester) async {
    await tester.pumpWidget(
      _buildTestAppWithState(const PostItemEmpty()),
    );

    // Verifikasi: pesan empty state tampil
    expect(find.text('Belum Ada Kategori'), findsOneWidget);
    expect(find.textContaining('belum tersedia'), findsOneWidget);
    // Verifikasi: tombol muat ulang ada
    expect(find.text('Muat Ulang'), findsOneWidget);
    // Verifikasi: form TIDAK tampil
    expect(find.text('Judul Barang'), findsNothing);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST KONDISI 4: Error State + Tombol Retry
  // Tampilan pesan error dan tombol "Coba Lagi" jika gagal fetch data.
  // ═══════════════════════════════════════════════════════════════════════════
  testWidgets('Kondisi 4: Menampilkan error state dengan tombol retry',
      (tester) async {
    await tester.pumpWidget(
      _buildTestAppWithState(
        const PostItemError(
            'Gagal memuat data kategori. Periksa koneksi internet.'),
      ),
    );

    // Verifikasi: judul error tampil
    expect(find.text('Terjadi Kesalahan'), findsOneWidget);
    // Verifikasi: pesan error tampil
    expect(find.textContaining('Gagal memuat data kategori'), findsOneWidget);
    // Verifikasi: tombol "Coba Lagi" tampil
    expect(find.text('Coba Lagi'), findsOneWidget);
    // Verifikasi: icon error tampil
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    // Verifikasi: form TIDAK tampil
    expect(find.text('Kirim'), findsNothing);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST KONDISI 5: Validasi Input Form
  // Pesan error merah di bawah field jika form dikirim kosong.
  // Mencakup semua field wajib: Judul, Kategori, Deskripsi, dan Metode.
  // ═══════════════════════════════════════════════════════════════════════════
  testWidgets('Kondisi 5: Menampilkan pesan validasi merah saat field kosong',
      (tester) async {
    await tester.pumpWidget(
      _buildTestAppWithState(
        const PostItemLoaded(categories: _testCategories),
      ),
    );

    // Scroll ke bawah sampai tombol "Kirim" terlihat lalu tap
    final listView = find.byType(ListView);
    await tester.dragUntilVisible(
      find.text('Kirim'),
      listView,
      const Offset(0, -200),
    );
    await tester.tap(find.text('Kirim'));
    await tester.pump();

    // Verifikasi pesan error di atas (scroll balik ke atas)
    await tester.dragUntilVisible(
      find.text('Judul wajib diisi'),
      listView,
      const Offset(0, 300),
    );
    // Verifikasi: pesan error validasi tampil untuk semua field wajib
    expect(find.text('Judul wajib diisi'), findsOneWidget);
    expect(find.text('Pilih kategori barang dulu ya'), findsOneWidget);
    expect(find.text('Deskripsi wajib diisi'), findsOneWidget);
    // Scroll ke bawah lagi untuk verifikasi error metode
    await tester.dragUntilVisible(
      find.text('Pilih minimal satu metode pengambilan'),
      listView,
      const Offset(0, -300),
    );
    expect(find.text('Pilih minimal satu metode pengambilan'), findsOneWidget);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST KONDISI 6: Loading Saat Submit
  // Saat sedang submit, tombol berubah menjadi loading indicator dan disabled.
  // ═══════════════════════════════════════════════════════════════════════════
  testWidgets('Kondisi 6: Tombol berubah jadi loading saat submit',
      (tester) async {
    // Langsung set state ke isSubmitting=true (simulasi proses submit)
    await tester.pumpWidget(
      _buildTestAppWithState(
        const PostItemLoaded(
          categories: _testCategories,
          isSubmitting: true, // ← langsung dalam kondisi submit
        ),
      ),
    );

    // Scroll ke bawah agar tombol terlihat
    final listView = find.byType(ListView);
    await tester.dragUntilVisible(
      find.byType(ElevatedButton),
      listView,
      const Offset(0, -200),
    );

    // Verifikasi: CircularProgressIndicator muncul DI DALAM tombol
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Verifikasi: teks "Kirim" sudah TIDAK tampil (diganti spinner)
    expect(find.text('Kirim'), findsNothing);
    // Verifikasi: tombol ElevatedButton ada tapi onPressed null (disabled)
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
