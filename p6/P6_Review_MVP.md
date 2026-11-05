# Pertemuan 6 — Review MVP dan Unit Test PakaiLagi

Dokumen ini merangkum MVP PakaiLagi, aturan bisnis yang diuji, serta panduan review untuk dosen.

> **Pembaruan P7:** MVP ditambah alamat pengambilan dengan pinpoint GPS, privasi lokasi (publik hanya kelurahan & kota), tombol Google Maps di Detail, dan Firestore Security Rules. Penjelasan lengkap fitur lanjutan ada di [`../p7/P7_Review_MVP_Lengkap.md`](../p7/P7_Review_MVP_Lengkap.md).

## 1. Definisi MVP

PakaiLagi adalah platform berbagi barang layak pakai. MVP saat ini mendukung:

- mengatur alamat pengambilan di Profil dengan pinpoint peta berbasis GPS,
- mem-posting barang dengan foto,
- melihat feed dan detail barang,
- mengajukan pengambilan,
- mengelola pengajuan dan memperbarui status barang menjadi `reserved`,
- membuka lokasi penjemputan di Google Maps,
- menghapus barang milik sendiri.

Data cloud disimpan di Cloud Firestore. Offline Persistence Firestore menyimpan cache data yang telah dibuka dan mengantrekan perubahan saat perangkat offline. Firebase Anonymous Auth hanya dipakai sebagai mekanisme teknis untuk memberi UID pada pemilik barang dan peminta; MVP ini belum mencakup akun lengkap dengan login email/password. Proyek tidak menggunakan SQLite atau `sqflite`.

## 2. User Stories dan Acceptance Criteria

### US 1 — Post Barang

Sebagai pemberi, saya dapat mem-posting barang dengan foto.

- Form tersedia di [`../lib/screens/post_item_screen.dart`](../lib/screens/post_item_screen.dart).
- Judul, kategori, deskripsi, metode pengambilan, dan foto wajib diisi sebelum posting.
- Alamat pengambilan di profil (alamat lengkap, kelurahan, kota) wajib sudah lengkap. Jika belum, posting ditolak dan muncul tombol "Atur di Profil".
- Foto dikompres (`maxWidth: 600`, `imageQuality: 70`) lalu dikonversi ke Base64 mentah, tanpa header `data:image/...`.
- Dokumen publik `items/{id}` menyimpan `title`, `category`, `description`, `imageBase64`, `donorId`, `ownerName`, `kelurahan`, `kota`, status `available`, dan `createdAt`.
- Alamat lengkap dan koordinat disimpan terpisah di `items/{id}/private/location` dalam batch yang sama.
- Setelah berhasil, aplikasi menampilkan pesan "Barang berhasil diposting!".

### US 2 — Menampilkan Feed dan Detail

Sebagai pengguna, saya dapat melihat feed dan detail barang.

- Provider pada [`../lib/providers/cloud_item_provider.dart`](../lib/providers/cloud_item_provider.dart) membaca stream Firestore secara real-time.
- Detail menggunakan Firestore document ID (`doc.id`) melalui [`../lib/screens/item_detail_screen.dart`](../lib/screens/item_detail_screen.dart).
- Gambar Base64 kosong atau rusak memiliki fallback aman.
- Bagian "Lokasi Pengambilan" hanya menampilkan kelurahan & kota kepada pengguna umum.

### US 3 — Mengajukan Pengambilan Barang

Sebagai peminta, saya dapat mengirim pengajuan untuk barang milik pengguna lain.

- Peminta memilih metode pengambilan pada halaman detail barang.
- Sistem menolak pengajuan untuk barang milik sendiri dan barang yang sudah tidak `available`.
- Dokumen pengajuan tersimpan di `pickupRequests/{itemId}_{requesterId}` dengan status awal `pending`. ID ini mencegah satu pengguna mengajukan barang yang sama dua kali ("Kamu sudah mengajukan barang ini.").
- Pengajuan dan notifikasi untuk pemberi ditulis dalam satu batch.

### US 4 — Memperbarui Status melalui Pengajuan

Sebagai pemilik, saya dapat menerima atau menolak pengajuan pengambilan barang.

- Pemilik membuka **Aktivitas → Barang Saya → Kelola Pengajuan**.
- Saat pemilik menerima pengajuan, status request menjadi `accepted` dan status item menjadi `reserved` dalam satu batch Firestore. Rules menolak penerimaan bila barang sudah tidak `available`, sehingga dua pengajuan tidak bisa sama-sama diterima.
- Saat pemilik menolak pengajuan, status request menjadi `rejected`.
- Peminta menerima notifikasi ketika pengajuannya diterima atau ditolak.

### US 5 — Menghapus Barang Milik Sendiri

Sebagai pemilik, saya dapat menghapus barang milik sendiri.

- Tombol hapus hanya muncul bila `donorId` sama dengan Firebase UID aktif.
- Aplikasi meminta konfirmasi sebelum menghapus.
- `deleteItem(itemId)` menghapus dokumen `items/{id}` beserta `items/{id}/private/location` dalam satu batch.
- Setelah berhasil, aplikasi menampilkan SnackBar dan kembali dari halaman detail.

### US 6 — Alamat Pengambilan dengan Pinpoint GPS

Sebagai pemberi, saya dapat mendaftarkan alamat pengambilan dengan cepat dan presisi.

- Form ada di **Profil → Alamat Pengambilan** ([`../lib/screens/profile_screen.dart`](../lib/screens/profile_screen.dart)).
- Tombol **"Pinpoint Lokasi di Peta (GPS)"** membuka [`../lib/screens/location_picker_screen.dart`](../lib/screens/location_picker_screen.dart), yang langsung mencari GPS dengan akurasi terbaik dan menampilkan lingkaran akurasi.
- Pengguna menggeser peta sampai pin tepat di titik penjemputan; alamat terbaca otomatis dari titik itu (Android/iOS).
- **"Pilih Titik Ini"** mengisi alamat lengkap, kelurahan, dan kota; pengguna melengkapi nomor rumah/RT/RW lalu menekan Simpan.
- Alamat lengkap, kelurahan, dan kota wajib diisi. Koordinat bersifat opsional dan bisa diubah atau dihapus.
- GPS mati, izin ditolak, batas waktu 15 detik, dan alamat tidak terbaca masing-masing memiliki pesan yang jelas; titik tetap bisa dipilih manual.

### US 7 — Privasi Lokasi dan Google Maps

Sebagai pemberi, saya ingin alamat rumah saya tidak terlihat oleh semua orang. Sebagai peminta yang diterima, saya ingin bisa menuju lokasi penjemputan.

- Pengguna umum hanya melihat "Kel. X, Kota Y" dan tombol **"Lihat Area di Google Maps"**.
- Pemilik dan peminta yang pengajuannya diterima melihat alamat lengkap, peta mini dengan pin, dan tombol **"Buka Titik di Google Maps"** yang membuka koordinat persis.
- Pembatasan ini ditegakkan oleh [`../firestore.rules`](../firestore.rules), bukan hanya oleh UI.

## 3. Unit Test

| Test | Kaitan dengan MVP |
|---|---|
| [`../test/models/item_model_test.dart`](../test/models/item_model_test.dart) | US 2: parsing `ItemModel`, `doc.id`, Timestamp, dan fallback null. |
| [`../test/validators/item_validator_test.dart`](../test/validators/item_validator_test.dart) | US 1: validasi judul, kategori, dan deskripsi. |
| [`../test/business/item_status_rules_test.dart`](../test/business/item_status_rules_test.dart) | US 3–4: status valid dan transisi `available` → `reserved`. |
| [`../test/business/image_base64_test.dart`](../test/business/image_base64_test.dart) | US 1: Base64 mentah valid, decoding, serta fallback data rusak. |
| [`../test/authorization/item_ownership_test.dart`](../test/authorization/item_ownership_test.dart) | US 5: hak update/delete hanya untuk UID pemilik item. |
| [`../test/item_local_crud_test.dart`](../test/item_local_crud_test.dart) | Kontrak data CRUD dan konfigurasi persistence. |
| [`../test/post_item_screen_test.dart`](../test/post_item_screen_test.dart) | US 1: enam kondisi UI form Posting (loading, data, kosong, error, validasi, submit). |

Jalankan dari akar proyek:

```powershell
flutter analyze
flutter test
```

Hasil verifikasi terakhir:

```text
flutter analyze  -> No issues found!
flutter test     -> All tests passed! (25 tests)
```

Unit test tidak mengakses Firebase produksi. US 6 dan US 7 bergantung pada GPS perangkat dan rules di server, sehingga diuji manual sesuai langkah demo di P7. Pengujian otomatis rules sebaiknya memakai Firebase Emulator Suite.

## 4. Keamanan

Pengecekan kepemilikan di UI hanya membantu pengalaman pengguna. Pengaman utama adalah [`../firestore.rules`](../firestore.rules), yang mengatur:

| Koleksi | Aturan utama |
|---|---|
| `profiles/{uid}` | Hanya pemilik akun yang boleh membaca dan menulis. |
| `items/{itemId}` | Semua pengguna yang login boleh membaca. Hanya `donorId` yang boleh mengubah (field `status` saja) atau menghapus. Field `address`, `latitude`, `longitude` ditolak. |
| `items/{itemId}/private/location` | Hanya pemilik barang dan peminta yang pengajuannya `accepted`. |
| `pickupRequests/{itemId}_{uid}` | Dibuat oleh peminta untuk barang orang lain yang masih `available`; diputuskan hanya oleh pemilik. |
| `notifications/{id}` | Hanya penerima yang boleh membaca dan menandai sudah dibaca. |

Rules dan index notifikasi diterapkan dengan:

```powershell
firebase deploy --only firestore
```
