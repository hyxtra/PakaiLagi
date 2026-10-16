# Pertemuan 5 — Local Data & Persistence PakaiLagi

Dokumen ini berisi panduan implementasi, lokasi kode, dan skenario demonstrasi fitur **Local Data & Persistence** untuk reviewer pada proyek PakaiLagi.

## 1. Ringkasan Implementasi Fitur

- **Fitur Vertikal:** Berbagi dan hibah barang bekas layak pakai (*Item Donation & Sharing*).
- **Alur Vertikal (UI → data):** `PostItemScreen` → `CloudItemNotifier` (Riverpod) → `FirebaseRepository` → Cloud Firestore dengan Offline Persistence dan encoding Base64.
- **Penyimpanan Lokal:** Menggunakan **Cloud Firestore Offline Persistence**. Firebase SDK menyimpan cache dokumen dan string foto Base64 pada penyimpanan lokal perangkat (IndexedDB di Web dan penyimpanan lokal SDK di Mobile), serta mengantrikan perubahan ketika perangkat offline untuk disinkronkan saat koneksi tersedia.
- **Sumber data:** Data produksi barang, profil, dan pengajuan memakai Firebase Authentication serta Cloud Firestore; proyek tidak memakai SQLite atau `sqflite`.
- **Status Pengujian:** Lulus **11/11 automated tests** (`11 tests passed!`) dan `dart analyze lib test` tidak menemukan isu.

## 2. Posisi Kode untuk Reviewer

| Kriteria | File | Keterangan |
|---|---|---|
| Local Storage Engine | [`../lib/services/firestore_configuration.dart`](../lib/services/firestore_configuration.dart), [`../lib/repositories/firebase_repository.dart`](../lib/repositories/firebase_repository.dart) | `FirestoreConfiguration.configure()` mengaktifkan `Settings(persistenceEnabled: true)` sebelum aplikasi berjalan. Repository mengelola operasi Firestore dan encoding Base64. |
| Data Model | [`../lib/models/item_model.dart`](../lib/models/item_model.dart) | `ItemModel.fromFirestore()` memetakan ID dengan `doc.id`, mem-parsing field secara aman, serta menyediakan `imageBytes` untuk gambar Base64. |
| CRUD: Create | [`../lib/screens/post_item_screen.dart`](../lib/screens/post_item_screen.dart), [`../lib/providers/cloud_item_provider.dart`](../lib/providers/cloud_item_provider.dart), [`../lib/repositories/firebase_repository.dart`](../lib/repositories/firebase_repository.dart) | `addItemToCloud()` mengubah byte foto menjadi Base64, mengambil UID Firebase aktif sebagai `donorId`, lalu menambah dokumen pada koleksi `items`. |
| CRUD: Read | [`../lib/screens/home_screen.dart`](../lib/screens/home_screen.dart), [`../lib/screens/public_feed_screen.dart`](../lib/screens/public_feed_screen.dart), [`../lib/screens/item_detail_screen.dart`](../lib/screens/item_detail_screen.dart), [`../lib/providers/cloud_item_provider.dart`](../lib/providers/cloud_item_provider.dart) | Stream Firestore menampilkan katalog, Barang Saya, dan detail berdasarkan Firestore document ID (`doc.id`). Gambar Base64 memiliki fallback aman. |
| CRUD: Update | [`../lib/screens/activity_screen.dart`](../lib/screens/activity_screen.dart), [`../lib/screens/manage_request_screen.dart`](../lib/screens/manage_request_screen.dart), [`../lib/repositories/firebase_repository.dart`](../lib/repositories/firebase_repository.dart) | Pemilik membuka **Barang Saya → Kelola Pengajuan**, lalu menerima pengajuan. Batch Firestore mengubah status pengajuan dan item menjadi `reserved`. Repository juga menyediakan `updateItemStatus()`. |
| CRUD: Delete | [`../lib/screens/item_detail_screen.dart`](../lib/screens/item_detail_screen.dart), [`../lib/repositories/firebase_repository.dart`](../lib/repositories/firebase_repository.dart) | Hanya pemilik Firebase yang melihat tombol **Hapus Barang**. Setelah konfirmasi, `deleteItem(itemId)` menghapus dokumen dari `items`. |
| Persistence Test | [`../test/item_local_crud_test.dart`](../test/item_local_crud_test.dart) | Unit test kontrak data untuk CREATE, READ dengan `doc.id`, UPDATE, DELETE, parsing Base64, dan konfigurasi persistence. |

## 3. Skema Data Lokal dan Storage

Koleksi utama adalah `items`. `id` tidak disimpan sebagai field pada dokumen: aplikasi mengambilnya dari Firestore document ID (`doc.id`). Field `createdAt` disimpan sebagai `Timestamp` melalui `FieldValue.serverTimestamp()`.

```json
{
  "documentId": "doc_id_firestore_a1b2c3d4",
  "title": "Kamus Bahasa Inggris Oxford",
  "category": "Buku",
  "description": "Kamus bekas kuliah, kondisi masih layak pakai.",
  "status": "available",
  "donorId": "uid_firebase_anonymous_xyz123",
  "ownerName": "Pius Petra",
  "imageBase64": "/9j/4AAQSkZJRgABAQAAAQABAAD...",
  "createdAt": "Firestore Timestamp"
}
```

Catatan: `imageBase64` adalah string Base64 mentah, tanpa prefix `data:image/...`. Selain `items`, aplikasi memakai `profiles/{uid}` untuk profil dan `pickupRequests/{requestId}` untuk pengajuan pengambilan.

## 4. Panduan Skenario Demo untuk Reviewer

### A. Menjalankan Aplikasi

Jalankan dari akar proyek:

```powershell
flutter pub get
flutter run
```

Untuk Web Chrome:

```powershell
flutter run -d chrome
```

### B. Alur Demo Interaktif: CRUD dan Persistence

1. **Create**
   - Masuk ke tab **Posting**.
   - Pilih foto, isi judul, kategori, dan deskripsi, kemudian tekan **Publish**.
   - Aplikasi mengubah foto menjadi Base64 dan menyimpannya bersama `donorId` pada Firestore.

2. **Read**
   - Buka **Beranda** atau katalog online untuk melihat item dari real-time stream Firestore.
   - Tekan kartu barang untuk membuka Detail Barang. Detail mengambil dokumen menggunakan ID route yang sama dengan `doc.id`.

3. **Update**
   - Gunakan akun/pengguna lain untuk mengajukan pengambilan barang.
   - Sebagai pemilik, buka **Aktivitas → Barang Saya → Kelola Pengajuan** lalu tekan **Terima**.
   - Status item pada Firestore berubah dari `available` menjadi `reserved`.

4. **Persistence Test (Kunci P5)**
   - Saat online, buka katalog atau detail barang terlebih dahulu agar Firestore memiliki data cache.
   - Putuskan koneksi internet atau aktifkan Airplane Mode.
   - Buka kembali katalog/detail yang sudah pernah dimuat. Data dan gambar Base64 terakhir yang tersimpan di cache harus tetap tersedia.
   - Perubahan yang dibuat saat offline akan diantrikan oleh Firestore lalu disinkronkan setelah koneksi kembali. Hasil dapat bergantung pada aturan Firestore yang mengizinkan write.

5. **Delete**
   - Buka detail barang milik sendiri.
   - Tekan **Hapus Barang**, konfirmasi dialog, lalu periksa bahwa kartu barang hilang dari **Barang Saya** dan Firestore.

### C. Pembuktian Eksekusi Test Suite

Jalankan:

```powershell
flutter test
```

Cuplikan hasil terakhir:

```text
00:03 +11: All tests passed!
```

Untuk pengecekan statis:

```powershell
dart analyze lib test
```

Hasil terakhir: `No issues found!`.

## 5. Batasan Pengujian

`item_local_crud_test.dart` adalah unit test kontrak data berbasis memori sehingga aman dan tidak menulis data Firebase produksi. Pengujian integrasi Firestore sungguhan sebaiknya menggunakan Firebase Emulator Suite atau proyek Firebase khusus testing.
