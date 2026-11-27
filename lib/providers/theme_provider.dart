import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Kunci penyimpanan preferensi tema di SharedPreferences.
const _kDarkMode = 'dark_mode';

/// Provider SharedPreferences. Di-override di main.dart setelah instance
/// dibuat agar tersedia sebelum widget tree dibangun.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('SharedPreferences belum diinisialisasi'),
);

/// Notifier yang menyimpan & memuat preferensi tema gelap/terang.
/// State disimpan ke SharedPreferences sehingga tetap konsisten
/// setelah app di-restart.
class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier(this._prefs) : super(_prefs.getBool(_kDarkMode) ?? false);

  final SharedPreferences _prefs;

  void toggle() => _set(!state);
  void set(bool value) => _set(value);

  void _set(bool value) {
    state = value;
    _prefs.setBool(_kDarkMode, value);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return ThemeModeNotifier(prefs);
});
