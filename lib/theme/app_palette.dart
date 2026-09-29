import 'package:flutter/material.dart';

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
    required this.accentText,
    required this.danger,
    required this.bubbleMine,
    required this.bubbleTheirs,
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
  final Color accentText;
  final Color danger;
  final Color bubbleMine;
  final Color bubbleTheirs;

  static const light = AppPalette(
    bg: Color(0xFFF6F7F4),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE4F0E8),
    border: Color(0xFFE2E7E1),
    text: Color(0xFF1E2621),
    textMuted: Color(0xFF6C7A70),
    primary: Color(0xFF2F6B4F),
    primarySoft: Color(0xFFE4F0E8),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFE0A63C),
    accentText: Color(0xFFC98A22),
    danger: Color(0xFFC0492F),
    bubbleMine: Color(0xFF2F6B4F),
    bubbleTheirs: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette(
    bg: Color(0xFF0F130E),
    surface: Color(0xFF191E17),
    surfaceAlt: Color(0x293E8F69), // hijau translusen
    border: Color(0xFF2C3329),
    text: Color(0xFFECF1EA),
    textMuted: Color(0xFF9BA89F),
    primary: Color(0xFF3E8F69),
    primarySoft: Color(0x293E8F69),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFE0A63C),
    accentText: Color(0xFFE6B860),
    danger: Color(0xFFE27A63),
    bubbleMine: Color(0xFF3E8F69),
    bubbleTheirs: Color(0xFF232A21),
  );

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
    Color? accentText,
    Color? danger,
    Color? bubbleMine,
    Color? bubbleTheirs,
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
      accentText: accentText ?? this.accentText,
      danger: danger ?? this.danger,
      bubbleMine: bubbleMine ?? this.bubbleMine,
      bubbleTheirs: bubbleTheirs ?? this.bubbleTheirs,
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
      accentText: Color.lerp(accentText, other.accentText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      bubbleMine: Color.lerp(bubbleMine, other.bubbleMine, t)!,
      bubbleTheirs: Color.lerp(bubbleTheirs, other.bubbleTheirs, t)!,
    );
  }
}

/// Shortcut ekstensi: `context.palette`
extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
