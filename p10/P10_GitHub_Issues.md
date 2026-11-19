# Draf GitHub Issues P10 — PakaiLagi

Setiap bagian di bawah siap disalin sebagai satu GitHub Issue. Nomor issue belum diketahui sampai issue dibuat; ganti `#nomor` pada contoh commit dengan nomor issue GitHub yang sebenarnya.

## 1. Izin jaringan tidak eksplisit pada Android release

**Judul:** `[BUG] Firestore tidak dapat terhubung pada APK Android release`

**Deskripsi Masalah**

APK release harus mendeklarasikan izin jaringan pada manifest utama. Tanpa izin yang jelas, akses Firestore dan layanan Firebase lain dapat gagal di perangkat fisik.

**Langkah Reproduksi**

1. Build dan pasang APK release pada perangkat Android.
2. Buka Beranda atau coba posting barang.
3. Periksa apakah konten Firestore gagal dimuat atau operasi jaringan gagal.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: aplikasi release dapat mengakses internet dan status koneksi.
- Aktual sebelum perbaikan: izin jaringan tidak tercantum eksplisit pada manifest utama.

**Solusi Perbaikan**

Tambahkan `INTERNET` dan `ACCESS_NETWORK_STATE` ke `android/app/src/main/AndroidManifest.xml`. **Status: diterapkan; verifikasi perangkat masih diperlukan.**

**Contoh commit:** `git commit -m "fix(android): declare release network permissions; Fixes #nomor"`

## 2. Google Maps tidak terdeteksi oleh Android 11+

**Judul:** `[BUG] Tambahkan package visibility untuk tautan Google Maps di Android 11+`

**Deskripsi Masalah**

Pembatasan package visibility Android 11+ dapat menghalangi `url_launcher` menemukan aplikasi yang mampu membuka tautan Maps.

**Langkah Reproduksi**

1. Pasang APK release di Android 11 atau yang lebih baru.
2. Buka detail barang yang memiliki koordinat lokasi.
3. Ketuk tombol **Buka Titik di Google Maps**.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: tautan `https` dapat dibuka dengan aplikasi/browser Maps yang tersedia.
- Aktual sebelum perbaikan: tidak ada deklarasi query VIEW untuk skema Maps pada manifest utama.

**Solusi Perbaikan**

Tambahkan `<queries>` dengan intent VIEW terpisah untuk skema `https` dan `geo` di dalam elemen `<manifest>`. Skema dipisah ke dua intent karena satu intent hanya memiliki satu skema data. **Status: diterapkan; verifikasi perangkat masih diperlukan.**

**Contoh commit:** `git commit -m "fix(android): declare Maps package visibility; Fixes #nomor"`

## 3. GPS mati menyebabkan kegagalan saat meminta lokasi

**Judul:** `[BUG] Tangani layanan GPS yang mati sebelum meminta posisi`

**Deskripsi Masalah**

Permintaan posisi saat layanan lokasi perangkat mati dapat melempar exception dan menghentikan alur pemilihan lokasi.

**Langkah Reproduksi**

1. Matikan layanan lokasi/GPS di perangkat.
2. Buka Profil lalu pilih pinpoint lokasi.
3. Amati hasil saat aplikasi mencoba mendapatkan posisi saat ini.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: aplikasi memberi peringatan yang jelas dan tetap membolehkan pengguna memilih titik secara manual.
- Aktual sebelum perbaikan: permintaan lokasi dapat gagal tanpa penanganan yang sesuai.

**Solusi Perbaikan**

Periksa `Geolocator.isLocationServiceEnabled()` sebelum `getCurrentPosition()`, lempar `LocationFailure` yang jelas, dan tampilkan pesannya melalui SnackBar. **Status: diterapkan di `LocationService` dan layar pemilih lokasi.**

**Contoh commit:** `git commit -m "fix(location): handle disabled GPS service; Fixes #nomor"`

## 4. Reverse geocoding gagal saat offline atau sinyal lemah

**Judul:** `[BUG] Pertahankan koordinat saat reverse geocoding gagal`

**Deskripsi Masalah**

Layanan geocoding dapat timeout, gagal terhubung, atau tidak mengembalikan placemark. Kegagalan ini tidak boleh menghapus titik yang sudah dipilih.

**Langkah Reproduksi**

1. Matikan data seluler/Wi-Fi atau gunakan koneksi sangat lemah.
2. Pilih titik melalui peta atau GPS.
3. Simpan lokasi profil.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: koordinat tetap tersimpan; alamat menampilkan `Koordinat: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}` bila alamat tidak bisa ditemukan.
- Aktual sebelum perbaikan: reverse geocoding gagal dan pemanggil menerima `null`, sehingga alamat otomatis tidak tersedia.

**Solusi Perbaikan**

Bungkus `placemarkFromCoordinates()` dengan penanganan kegagalan terpisah dan kembalikan label fallback koordinat. Pemilihan titik tetap membawa latitude dan longitude; pengguna tetap dapat melengkapi kelurahan/kota secara manual untuk kebutuhan label publik. **Status: diterapkan.**

**Contoh commit:** `git commit -m "fix(location): retain coordinates when geocoding fails; Fixes #nomor"`

## 5. Foto kamera resolusi tinggi membebani memori

**Judul:** `[BUG] Kompres foto pilihan sebelum diproses dan dikirim`

**Deskripsi Masalah**

Foto kamera beresolusi besar menghabiskan memori saat dibaca dan dikodekan menjadi Base64, sehingga proses posting bisa lambat atau kehabisan memori.

**Langkah Reproduksi**

1. Ambil foto beresolusi tinggi menggunakan kamera perangkat.
2. Pilih foto tersebut pada form Posting Barang.
3. Kirim form pada perangkat dengan memori terbatas.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: foto diperkecil dan dikompresi sebelum diproses aplikasi.
- Aktual sebelum perbaikan: batas dimensi/kualitas belum mengikuti konfigurasi P10.

**Solusi Perbaikan**

Gunakan `maxWidth: 1024`, `maxHeight: 1024`, dan `imageQuality: 75` pada `ImagePicker.pickImage()`. Pertahankan validasi ukuran payload sebelum kirim. **Status: diterapkan; ukuran hasil bergantung pada isi foto dan validasi payload tetap berlaku.**

**Contoh commit:** `git commit -m "fix(upload): compress picked photos; Fixes #nomor"`

## 6. Ketukan ganda menggandakan posting Firestore

**Judul:** `[BUG] Cegah submit posting barang lebih dari sekali`

**Deskripsi Masalah**

Ketukan cepat berulang dapat masuk sebelum state loading provider terpasang dan membuat lebih dari satu dokumen barang.

**Langkah Reproduksi**

1. Isi form posting yang valid.
2. Ketuk tombol posting dua kali dengan cepat.
3. Periksa daftar barang di Firestore.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: hanya satu operasi publikasi dan satu dokumen dibuat.
- Aktual sebelum perbaikan: dua operasi dapat dimulai sebelum tombol dinonaktifkan.

**Solusi Perbaikan**

Gunakan guard lokal di baris awal handler (`if (_submitting) return;`), aktifkan flag sebelum operasi async pertama, dan nonaktifkan tombol selama proses berjalan. **Status: diterapkan.**

**Contoh commit:** `git commit -m "fix(post): guard against duplicate submission; Fixes #nomor"`

## 7. Alamat panjang meluap pada kartu atau detail

**Judul:** `[BUG] Batasi teks alamat panjang agar tidak overflow`

**Deskripsi Masalah**

Alamat hasil geocoding yang panjang dapat melebar keluar dari `Row` atau kartu pada layar sempit dan ukuran teks besar.

**Langkah Reproduksi**

1. Gunakan profil dengan alamat panjang.
2. Buka Detail Barang pada perangkat berlayar sempit atau aktifkan ukuran font besar.
3. Periksa baris alamat pada bagian lokasi pengambilan.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: alamat tetap berada di batas layout, maksimal dua baris, dan sisanya memakai elipsis.
- Aktual sebelum perbaikan: teks alamat tanpa batas baris berpotensi menyebabkan `RenderFlex overflow`.

**Solusi Perbaikan**

Tempatkan teks alamat dalam `Expanded`/`Flexible` di dalam `Row`, serta gunakan `maxLines: 2` dan `TextOverflow.ellipsis`. Beranda/Katalog tidak menampilkan alamat lengkap; layout alamat berada di detail. **Status: diterapkan.**

**Contoh commit:** `git commit -m "fix(ui): constrain long pickup address text; Fixes #nomor"`

## 8. Data lokasi lama atau parsial menyebabkan aksi Maps tidak aman

**Judul:** `[BUG] Tampilkan aksi titik Maps hanya saat koordinat lengkap tersedia`

**Deskripsi Masalah**

Dokumen lama atau data lokasi parsial dapat tidak memiliki latitude atau longitude. Aksi yang menganggap keduanya tersedia berisiko mengirim koordinat null.

**Langkah Reproduksi**

1. Buka barang yang dokumen lokasinya tidak memiliki salah satu atau kedua koordinat.
2. Buka halaman detail barang.
3. Periksa dan coba aksi Google Maps.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: tombol dan preview titik Maps hanya muncul bila latitude dan longitude tersedia bersama.
- Aktual sebelum perbaikan: tombol area Maps bisa tampil walau koordinat titik tidak tersedia.

**Solusi Perbaikan**

Gunakan koordinat nullable dari dokumen lokasi privat dan tampilkan preview/tombol titik hanya jika keduanya non-null. Dokumen publik tetap hanya memuat area, sesuai batas privasi P9. **Status: diterapkan.**

**Contoh commit:** `git commit -m "fix(detail): guard Maps action on complete coordinates; Fixes #nomor"`

## 9. Foto lokal hilang setelah cache Android dibersihkan

**Judul:** `[BUG] Tampilkan placeholder saat file foto cache tidak tersedia`

**Deskripsi Masalah**

Android dapat menghapus file foto sementara yang dipilih dari cache. `Image.file` atau gambar network yang gagal dimuat tidak boleh membuat area foto menampilkan error.

**Langkah Reproduksi**

1. Pilih foto pada form atau buka barang yang menyimpan path foto lokal.
2. Hapus cache aplikasi/sistem atau gunakan path gambar yang sudah tidak ada.
3. Buka kembali halaman terkait.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: aplikasi menampilkan placeholder foto yang rapi.
- Aktual sebelum perbaikan: kegagalan memuat gambar dapat terlihat sebagai gambar rusak/error.

**Solusi Perbaikan**

Tambahkan `errorBuilder` pada seluruh `Image.file` dan `Image.network`, dengan ikon/placeholder yang konsisten. **Status: diterapkan pada preview posting dan widget foto.**

**Contoh commit:** `git commit -m "fix(images): show fallback for unavailable image files; Fixes #nomor"`

## 10. Form posting masih terisi setelah publikasi sukses

**Judul:** `[BUG] Bersihkan form setelah barang berhasil diposting`

**Deskripsi Masalah**

Setelah posting berhasil, tombol Back Android atau perpindahan tab dapat menampilkan kembali judul, deskripsi, foto, metode, atau pilihan form sebelumnya.

**Langkah Reproduksi**

1. Isi dan kirim form posting yang valid.
2. Tunggu konfirmasi berhasil.
3. Tekan Back Android atau buka kembali halaman Posting Barang.

**Perilaku yang Diharapkan vs Aktual**

- Diharapkan: controller dan seluruh state form kosong setelah sukses.
- Aktual sebelum perbaikan: form dapat tetap berisi data posting sebelumnya.

**Solusi Perbaikan**

Panggil `_resetForm()` pada jalur sukses sebelum kembali/navigasi; bersihkan controller, kategori, metode, path/XFile foto, dan error validasi. **Status: diterapkan.**

**Contoh commit:** `git commit -m "fix(post): reset form after successful publish; Fixes #nomor"`

---

## Catatan integrasi Firebase

Posting menggunakan field `pickupMethods`. Pastikan perubahan `firestore.rules` yang mengizinkan field tersebut sudah di-deploy ke proyek Firebase sebelum menguji publikasi APK:

```powershell
firebase deploy --only firestore:rules
```

Jangan jalankan contoh commit sebelum nomor issue aktual tersedia; ganti setiap `#nomor` dengan nomor issue yang dibuat di GitHub agar GitHub menutup issue terkait saat commit/push sesuai konfigurasi repository.
