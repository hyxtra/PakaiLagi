import 'package:cloud_firestore/cloud_firestore.dart';

/// Konfigurasi cache lokal Firestore. Data cache memungkinkan aplikasi tetap
/// membaca hasil terakhir dan mengantrikan perubahan ketika koneksi terputus.
abstract final class FirestoreConfiguration {
  static const bool persistenceEnabled = true;

  static Future<void> configure() async {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: persistenceEnabled);
  }
}
