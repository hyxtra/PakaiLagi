import 'package:flutter/material.dart';

import '../models/item.dart' show ItemStatus;

/// Palet warna semantik PakaiLagi. Dipasang sebagai [ThemeExtension] agar
/// setiap screen bisa membaca warna yang sama untuk mode terang & gelap:
///   final p = Theme.of(context).extension<AppPalette>()!;
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.danger,
    required this.onDanger,
    required this.bubbleMine,
    required this.bubbleTheirs,
    required this.statusAvailable,
    required this.statusReserved,
    required this.statusCompleted,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color accent;

  /// Warna teks/ikon di atas [accent] (tombol oranye).
  final Color onAccent;
  final Color accentText;
  final Color danger;

  /// Warna teks/ikon di atas [danger] (tombol Hapus).
  final Color onDanger;
  final Color bubbleMine;
  final Color bubbleTheirs;

  /// Warna teks badge status di atas latar tint 14% dari warna itu sendiri.
  final Color statusAvailable;
  final Color statusReserved;
  final Color statusCompleted;

  // KONTRAS (WCAG 2.1 AA, minimal 4,5:1 untuk teks biasa). Angka di komentar
  // dihitung dengan rumus relative luminance WCAG.

  static const light = AppPalette(
    bg: Color(0xFFF6F7F4),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE4F0E8),
    border: Color(0xFFE2E7E1),
    text: Color(0xFF1E2621),
    textMuted: Color(0xFF5C6A60), // 5,3:1 di bg, 4,86:1 di surfaceAlt
    primary: Color(0xFF2F6B4F), // 5,85:1 di bg
    primarySoft: Color(0xFFE4F0E8),
    onPrimary: Color(0xFFFFFFFF), // 6,29:1 di primary
    accent: Color(0xFFE0A63C),
    onAccent: Color(0xFF1E2621), // 7,15:1 (putih hanya 2,17:1)
    accentText: Color(0xFF8A5A0E), // 5,02:1 di badge kategori
    danger: Color(0xFFC0492F), // 4,61:1 di bg
    onDanger: Color(0xFFFFFFFF), // 4,96:1
    bubbleMine: Color(0xFF2F6B4F),
    bubbleTheirs: Color(0xFFFFFFFF),
    statusAvailable: Color(0xFF2F6B4F), // 4,8:1 di tint
    statusReserved: Color(0xFF8A5A00), // 5,03:1 di tint
    statusCompleted: Color(0xFF525E56), // 5,19:1 di tint
  );

  static const dark = AppPalette(
    bg: Color(0xFF0F130E),
    surface: Color(0xFF191E17),
    surfaceAlt: Color(0x293E8F69), // hijau translusen
    border: Color(0xFF2C3329),
    text: Color(0xFFECF1EA),
    textMuted: Color(0xFF9BA89F), // 6,85:1 di surface
    primary: Color(0xFF5DBB8C), // 7,22:1 di surface
    primarySoft: Color(0x293E8F69),
    onPrimary: Color(0xFF0F130E), // 7,99:1 di primary
    accent: Color(0xFFE0A63C),
    onAccent: Color(0xFF1E2621), // 7,15:1
    accentText: Color(0xFFE6B860), // 8,02:1 di badge kategori
    danger: Color(0xFFE27A63), // 6,43:1 di bg
    onDanger: Color(0xFF0F130E), // 6,43:1 (putih hanya 2,92:1)
    bubbleMine: Color(0xFF2F6B4F), // teks putih 6,29:1
    bubbleTheirs: Color(0xFF232A21),
    statusAvailable: Color(0xFF5DBB8C), // 6,35:1 di tint
    statusReserved: Color(0xFFE0A63C), // 6,82:1 di tint
    statusCompleted: Color(0xFF9AA39C), // 5,86:1 di tint
  );

  /// Warna badge untuk status barang.
  Color statusColor(ItemStatus status) => switch (status) {
        ItemStatus.available => statusAvailable,
        ItemStatus.reserved => statusReserved,
        ItemStatus.completed => statusCompleted,
      };

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? primary,
    Color? primarySoft,
    Color? onPrimary,
    Color? accent,
    Color? onAccent,
    Color? accentText,
    Color? danger,
    Color? onDanger,
    Color? bubbleMine,
    Color? bubbleTheirs,
    Color? statusAvailable,
    Color? statusReserved,
    Color? statusCompleted,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentText: accentText ?? this.accentText,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      bubbleMine: bubbleMine ?? this.bubbleMine,
      bubbleTheirs: bubbleTheirs ?? this.bubbleTheirs,
      statusAvailable: statusAvailable ?? this.statusAvailable,
      statusReserved: statusReserved ?? this.statusReserved,
      statusCompleted: statusCompleted ?? this.statusCompleted,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      bubbleMine: Color.lerp(bubbleMine, other.bubbleMine, t)!,
      bubbleTheirs: Color.lerp(bubbleTheirs, other.bubbleTheirs, t)!,
      statusAvailable: Color.lerp(statusAvailable, other.statusAvailable, t)!,
      statusReserved: Color.lerp(statusReserved, other.statusReserved, t)!,
      statusCompleted: Color.lerp(statusCompleted, other.statusCompleted, t)!,
    );
  }
}

/// Shortcut ekstensi: `context.palette`
extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
