# Pertemuan 6 - Review MVP dan Unit Test PakaiLagi

Dokumen ini merangkum MVP PakaiLagi, aturan bisnis yang diuji, serta panduan review untuk dosen.

## 1. Definisi MVP

PakaiLagi adalah platform berbagi barang layak pakai. MVP saat ini mendukung post barang, melihat feed dan detail, mengajukan pengambilan, mengelola pengajuan, memperbarui status menjadi `reserved`, dan menghapus barang milik sendiri.

Data cloud disimpan di Cloud Firestore. Offline Persistence Firestore menyimpan cache data yang telah dibuka dan mengantrikan perubahan saat perangkat offline. Firebase Anonymous Auth hanya dipakai sebagai mekanisme teknis untuk memberi UID pada pemilik barang dan peminta; MVP ini belum mencakup fitur akun lengkap seperti login email/password atau registrasi. Proyek tidak menggunakan SQLite atau `sqflite`.

## 2. User Stories dan Acceptance Criteria

### US 1 - Post Barang

Sebagai pemberi, saya dapat mem-post barang dengan foto.

- Form tersedia di [`../lib/screens/post_item_screen.dart`](../lib/screens/post_item_screen.dart).
- Judul, kategori, deskripsi, dan foto wajib diisi sebelum post.
- Foto dikonversi ke Base64 mentah, tanpa header `data:image/...`.
- Dokumen `items` menyimpan `title`, `category`, `description`, `imageBase64`, `donorId`, `ownerName`, status `available`, dan `createdAt`.
- Setelah berhasil, aplikasi menampilkan pesan "Barang berhasil diposting!".

### US 2 - Menampilkan Feed dan Detail

Sebagai pengguna, saya dapat melihat feed dan detail barang.

- Provider pada [`../lib/providers/cloud_item_provider.dart`](../lib/providers/cloud_item_provider.dart) membaca stream Firestore secara real-time.
- Detail menggunakan Firestore document ID (`doc.id`) melalui [`../lib/screens/item_detail_screen.dart`](../lib/screens/item_detail_screen.dart).
- Gambar Base64 kosong atau rusak memiliki fallback aman.

### US 3 - Mengajukan Pengambilan Barang

Sebagai peminta, saya dapat mengirim pengajuan untuk barang milik pengguna lain.

- Peminta memilih metode pengambilan pada halaman detail barang.
- Sistem menolak pengajuan untuk barang milik sendiri.
- Dokumen pengajuan tersimpan pada koleksi `pickupRequests` dengan status awal `pending`.
- Pemberi menerima notifikasi aktivitas tentang pengajuan baru.

### US 4 - Memperbarui Status melalui Pengajuan

Sebagai pemilik, saya dapat menerima atau menolak pengajuan pengambilan barang.

- Pemilik membuka **Aktivitas -> Barang Saya -> Kelola Pengajuan**.
- Saat pemilik menerima pengajuan, status request menjadi `accepted` dan status item menjadi `reserved` dalam batch Firestore.
- Saat pemilik menolak pengajuan, status request menjadi `rejected`.
- Peminta menerima notifikasi aktivitas ketika pengajuannya diterima atau ditolak.

### US 5 - Menghapus Barang Milik Sendiri

Sebagai pemilik, saya dapat menghapus barang milik sendiri.

- Tombol hapus hanya muncul bila `donorId` sama dengan Firebase UID aktif.
- Aplikasi meminta konfirmasi sebelum delete.
- `deleteItem(itemId)` menghapus dokumen dari koleksi `items`.
- Setelah berhasil, aplikasi menampilkan SnackBar dan kembali dari halaman detail.

## 3. Unit Test P6

| Test | Kaitan dengan MVP |
|---|---|
| [`../test/models/item_model_test.dart`](../test/models/item_model_test.dart) | US 2: parsing `ItemModel`, `doc.id`, Timestamp, dan fallback null. |
| [`../test/validators/item_validator_test.dart`](../test/validators/item_validator_test.dart) | US 1: validasi judul, kategori, dan deskripsi form. |
| [`../test/business/item_status_rules_test.dart`](../test/business/item_status_rules_test.dart) | US 3-4: status valid dan transisi `available` ke `reserved` saat pengajuan diterima. |
| [`../test/business/image_base64_test.dart`](../test/business/image_base64_test.dart) | US 1: Base64 mentah valid, decoding, serta fallback data rusak. |
| [`../test/authorization/item_ownership_test.dart`](../test/authorization/item_ownership_test.dart) | US 5: hak update/delete hanya untuk UID pemilik item. |

Jalankan dari akar proyek:

```powershell
dart analyze lib test
flutter test
```

Hasil verifikasi terakhir:

```text
dart analyze lib test  -> No issues found!
flutter test           -> All tests passed! (25 tests)
```

Unit test tidak mengakses Firebase produksi. Pengujian integrasi Firestore sungguhan sebaiknya memakai Firebase Emulator Suite atau proyek Firebase khusus testing.

## 4. Catatan Keamanan

Pengecekan ownership di UI membantu pengalaman pengguna, tetapi bukan mekanisme keamanan utama. Firestore Security Rules perlu membatasi update/delete item dengan aturan setara:

```text
request.auth.uid == resource.data.donorId
```
