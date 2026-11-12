import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

// =============================================================================
// form_field_widget.dart
// Reusable widget untuk field teks dan pesan error di form PakaiLagi.
//
// TUJUAN (P9 — DRY / Separation of Concerns):
//   Menghilangkan duplikasi `_textField()` dan `_errorText()` yang sebelumnya
//   hanya ada di dalam `PostItemScreen`. Widget ini dapat dipakai di layar
//   mana pun yang membutuhkan input teks bergaya sama.
//
// WIDGET YANG TERSEDIA:
//   - [AppErrorText]   : teks merah kecil untuk pesan validasi
//   - [AppTextField]   : TextField bertemakan AppPalette + AppErrorText
//   - [AppLabeledField]: label + AppTextField dalam satu node semantik
// =============================================================================

// ---------------------------------------------------------------------------
// AppErrorText
// ---------------------------------------------------------------------------

/// Teks pesan validasi merah yang otomatis diumumkan oleh pembaca layar
/// (`liveRegion: true`) saat muncul.
class AppErrorText extends StatelessWidget {
  const AppErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<AppPalette>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2, bottom: 4),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: TextStyle(fontSize: 12, color: p.danger),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppTextField
// ---------------------------------------------------------------------------

/// TextField bertemakan AppPalette — border merah saat ada error, hijau/primer
/// saat fokus, dan warna surface yang disesuaikan status enabled/disabled.
///
/// Jika [error] tidak null, [AppErrorText] ditampilkan otomatis di bawah field.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.error,
    this.maxLines = 1,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final String? error;
  final int maxLines;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<AppPalette>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          enabled: enabled,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          textCapitalization: textCapitalization,
          // Ruang ekstra di bawah field yang difokuskan agar pesan error
          // di bawahnya tetap terlihat di atas keyboard.
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          style: TextStyle(color: p.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: p.textMuted),
            filled: true,
            fillColor: enabled ? p.surface : p.surface.withValues(alpha: 0.6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: error != null ? p.danger : p.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: error != null ? p.danger : p.primary,
                width: 1.6,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: p.border),
            ),
          ),
        ),
        if (error != null) AppErrorText(error!),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AppLabeledField
// ---------------------------------------------------------------------------

/// Label + [AppTextField] yang digabung menjadi satu node aksesibilitas
/// (`MergeSemantics`), sehingga TalkBack membacakan label dan error bersama
/// teks contoh (hint) tanpa memisah-misah komponen.
class AppLabeledField extends StatelessWidget {
  const AppLabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.sectionKey,
    this.focusNode,
    this.error,
    this.maxLines = 1,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final Key? sectionKey;
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final String? error;
  final int maxLines;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<AppPalette>()!;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            key: sectionKey,
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Semantics(
              header: true,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ),
          ),
          AppTextField(
            controller: controller,
            hint: hint,
            focusNode: focusNode,
            error: error,
            maxLines: maxLines,
            enabled: enabled,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            textCapitalization: textCapitalization,
          ),
        ],
      ),
    );
  }
}

