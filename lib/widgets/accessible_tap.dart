import 'package:flutter/material.dart';

/// Pengganti `GestureDetector` untuk kontrol kustom (chip, tab, kartu).
///
/// - Pembaca layar (TalkBack/VoiceOver) mengenalinya sebagai tombol,
///   termasuk status terpilih/tidak dan aktif/nonaktif.
/// - Ada efek ripple saat ditekan sebagai umpan balik visual. Ripple
///   digambar DI ATAS [child], sehingga tetap terlihat walaupun child punya
///   warna latar sendiri.
/// - [minSize] memperbesar area sentuh (default 48 dp, pedoman Android &
///   Material) tanpa mengubah ukuran tampilan [child].
class AccessibleTap extends StatelessWidget {
  const AccessibleTap({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
    this.tooltip,
    this.selected,
    this.radio = false,
    this.borderRadius,
    this.minSize = 48,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Label pembaca layar. Jika diisi, teks di dalam [child] tidak dibacakan
  /// (menghindari pembacaan ganda). Jika null, teks [child] yang dibacakan.
  final String? label;
  final String? tooltip;

  /// Status terpilih (chip/tab). Null bila kontrol tidak punya status.
  final bool? selected;

  /// True untuk pilihan tunggal dalam satu grup (seperti radio button).
  final bool radio;
  final BorderRadius? borderRadius;

  /// Ukuran minimum area sentuh. 0 untuk kontrol lebar (kartu, tab).
  final double minSize;

  @override
  Widget build(BuildContext context) {
    Widget tappable = Stack(
      children: [
        child,
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              // Semantik diatur oleh widget Semantics di luar.
              excludeFromSemantics: true,
            ),
          ),
        ),
      ],
    );

    if (minSize > 0) {
      // Ketukan di margin (di luar tampilan child, masih di dalam area
      // minimum) tetap diteruskan ke onTap.
      tappable = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
          child: Center(widthFactor: 1, heightFactor: 1, child: tappable),
        ),
      );
    }

    final hasLabel = label != null;
    final Widget semantics = Semantics(
      button: !radio,
      enabled: onTap != null,
      selected: radio ? null : selected,
      checked: radio ? (selected ?? false) : null,
      inMutuallyExclusiveGroup: radio ? true : null,
      label: label,
      onTap: onTap,
      excludeSemantics: hasLabel,
      child: tappable,
    );
    // Tanpa label: gabungkan teks di dalam child menjadi satu node tombol.
    Widget result = hasLabel ? semantics : MergeSemantics(child: semantics);

    if (tooltip != null) {
      result =
          Tooltip(message: tooltip!, excludeFromSemantics: true, child: result);
    }
    return result;
  }
}
