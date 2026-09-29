import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true = mode gelap aktif.
class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(false);
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, bool>((ref) => ThemeModeNotifier());
