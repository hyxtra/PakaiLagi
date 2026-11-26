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
    bg: Color(0xFFF4EDE4),
    surface: Color(0xFFFDFCFA),
    surfaceAlt: Color(0xFFF0E4D4),
    border: Color(0xFFDFD9CF),
    text: Color(0xFF1C1310),
    textMuted: Color(0xFF70635F),
    primary: Color(0xFF2D1E18),
    primarySoft: Color(0xFFF0E4D4),
    onPrimary: Color(0xFFFDFCFA),
    accent: Color(0xFFD48D31),
    onAccent: Color(0xFF2D1E18),
    accentText: Color(0xFF2D1E18),
    danger: Color(0xFF9D3D2D),
    onDanger: Color(0xFFFFFFFF), // 4,96:1
    bubbleMine: Color(0xFF2D1E18),
    bubbleTheirs: Color(0xFFFDFCFA),
    statusAvailable: Color(0xFF2D1E18),
    statusReserved: Color(0xFF8A4B20),
    statusCompleted: Color(0xFF70635F),
  );

  static const dark = AppPalette(
    bg: Color(0xFF17110F),
    surface: Color(0xFF211916),
    surfaceAlt: Color(0xFF33251F),
    border: Color(0xFF493830),
    text: Color(0xFFF4EDE4),
    textMuted: Color(0xFFC1B2A8),
    primary: Color(0xFFE0C4AF),
    primarySoft: Color(0xFF33251F),
    onPrimary: Color(0xFF211916),
    accent: Color(0xFFD48D31),
    onAccent: Color(0xFF2D1E18),
    accentText: Color(0xFFF0C27D),
    danger: Color(0xFFE7836D),
    onDanger: Color(0xFF211916),
    bubbleMine: Color(0xFF604333),
    bubbleTheirs: Color(0xFF2B211D),
    statusAvailable: Color(0xFFF0C27D),
    statusReserved: Color(0xFFF0C27D),
    statusCompleted: Color(0xFFC1B2A8),
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
