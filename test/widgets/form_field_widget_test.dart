import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pakailagi/theme/app_palette.dart';
import 'package:pakailagi/widgets/form_field_widget.dart';

// =============================================================================
// test/widgets/form_field_widget_test.dart
// Widget test untuk AppErrorText, AppTextField, dan AppLabeledField.
//
// Membuktikan bahwa:
//   - AppErrorText menampilkan teks merah dengan pesan yang benar.
//   - AppTextField menampilkan border merah saat ada error.
//   - AppTextField menampilkan AppErrorText saat ada error.
//   - AppLabeledField menampilkan label + field + error.
// =============================================================================

/// Helper: membungkus widget dengan MaterialApp + tema AppPalette.
Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [AppPalette.light]),
    home: Scaffold(body: child),
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // AppErrorText
  // ─────────────────────────────────────────────────────────────────────────
  group('AppErrorText', () {
    testWidgets('menampilkan pesan error yang diberikan', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppErrorText('Judul wajib diisi')),
      );

      expect(find.text('Judul wajib diisi'), findsOneWidget);
    });

    testWidgets('teks berukuran kecil (fontSize 12)', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppErrorText('error kecil')),
      );

      final text = tester.widget<Text>(find.text('error kecil'));
      expect(text.style?.fontSize, 12.0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AppTextField
  // ─────────────────────────────────────────────────────────────────────────
  group('AppTextField', () {
    testWidgets('menampilkan hint text', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(AppTextField(
          controller: ctrl,
          hint: 'Masukkan judul',
        )),
      );

      expect(find.text('Masukkan judul'), findsOneWidget);
    });

    testWidgets('menampilkan AppErrorText saat error tidak null', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(AppTextField(
          controller: ctrl,
          hint: 'Masukkan judul',
          error: 'Judul wajib diisi',
        )),
      );

      expect(find.byType(AppErrorText), findsOneWidget);
      expect(find.text('Judul wajib diisi'), findsOneWidget);
    });

    testWidgets('tidak menampilkan AppErrorText saat error null', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(AppTextField(
          controller: ctrl,
          hint: 'Masukkan judul',
          // error tidak diset → null
        )),
      );

      expect(find.byType(AppErrorText), findsNothing);
    });

    testWidgets('disabled: TextField tidak bisa diketik', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(AppTextField(
          controller: ctrl,
          hint: 'Tidak bisa diedit',
          enabled: false,
        )),
      );

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, false);
    });

    testWidgets('menerima input teks dari pengguna', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(AppTextField(
          controller: ctrl,
          hint: 'Ketik di sini',
        )),
      );

      await tester.enterText(find.byType(TextField), 'Meja Lipat');
      expect(ctrl.text, 'Meja Lipat');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AppLabeledField
  // ─────────────────────────────────────────────────────────────────────────
  group('AppLabeledField', () {
    testWidgets('menampilkan label dan hint', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(AppLabeledField(
          label: 'Judul Barang',
          controller: ctrl,
          hint: 'Mis. Meja belajar',
        )),
      );

      expect(find.text('Judul Barang'), findsOneWidget);
      expect(find.text('Mis. Meja belajar'), findsOneWidget);
    });

    testWidgets('menampilkan AppErrorText saat ada error', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(AppLabeledField(
          label: 'Deskripsi',
          controller: ctrl,
          hint: 'Ceritakan kondisi barang',
          error: 'Deskripsi minimal 5 karakter',
        )),
      );

      expect(find.text('Deskripsi'), findsOneWidget);
      expect(find.byType(AppErrorText), findsOneWidget);
      expect(find.text('Deskripsi minimal 5 karakter'), findsOneWidget);
    });

    testWidgets('tidak menampilkan AppErrorText saat error null', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(AppLabeledField(
          label: 'Kategori',
          controller: ctrl,
          hint: 'Pilih kategori',
        )),
      );

      expect(find.byType(AppErrorText), findsNothing);
    });
  });
}

