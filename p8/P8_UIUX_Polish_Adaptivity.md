# Laporan Review P8: UI/UX Polish & Adaptivity (Aplikasi PakaiLagi)

Dokumen ini menjelaskan implementasi empat poin standar UI/UX pada aplikasi PakaiLagi: layout adaptif, keyboard-safe UI, aksesibilitas dasar, dan feedback aksi. Setiap klaim di bawah sudah dicocokkan dengan kode dan dengan hasil pengujian otomatis; hal yang belum bisa dibuktikan dituliskan apa adanya di bagian [Keterbatasan](#7-keterbatasan-yang-diketahui) dan [Bukti Screenshot](#8-bukti-screenshot).

## 1. Koreksi terhadap Rancangan Awal (Master Prompt)

Rancangan awal laporan ini memuat beberapa klaim yang tidak sesuai dengan kode. Berikut hasil pemeriksaannya sebelum pekerjaan dilakukan, dan tindakan yang diambil.

| Poin | Klaim di rancangan awal | Kenyataan di kode | Tindakan |
|---|---|---|---|
| 01 | `LayoutBuilder`; `ListView` bila lebar < 600, `GridView` 2–3 kolom bila ≥ 600 | Tidak ada `LayoutBuilder` maupun `GridView` di seluruh `lib/`. Beranda selalu 1 kolom. | **Diimplementasikan** di Beranda (bagian 2) |
| 02 | `SingleChildScrollView` | Form Posting memakai `ListView` (sama-sama dapat di-scroll). | Klaim dikoreksi di dokumen |
| 02 | `resizeToAvoidBottomInset: true` | Tidak ditulis eksplisit, tetapi nilai bawaan `Scaffold` memang `true`. | Klaim dikoreksi di dokumen |
| 02 | Padding dinamis `MediaQuery.viewInsets.bottom` | Tidak ada di kode, dan terbukti **tidak diperlukan**: field tetap berada di atas keyboard tanpa padding tersebut (hasil tes di bagian 3). | Klaim dikoreksi; kode tidak ditambah |
| 03 | Semua `IconButton`, termasuk "tombol Kamera" dan "tombol Navigasi", punya `tooltip` | Tombol kamera adalah `ListTile` ("Ambil Foto") yang sudah berlabel teks, dan navigasi bawah adalah kontrol kustom, bukan `IconButton`. Semua `IconButton` yang ada sudah punya `tooltip`. | Klaim dikoreksi; navigasi dilabeli lewat `Semantics` |
| 03 | `Semantics` label "Foto barang: [Nama]" | Label sebelumnya "Foto [Nama]". | Label disamakan menjadi **"Foto barang: [Nama]"** |
| 04 | `SnackBar` hijau (sukses) dan merah (gagal) | Semua `SnackBar` memakai warna bawaan; tidak ada hijau atau merah. | **Diimplementasikan** (bagian 5) |
| 04 | Proses "ke server (Firestore/Storage)" | Aplikasi **tidak memakai Firebase Storage**. Foto disimpan sebagai Base64 di Cloud Firestore. | Klaim dikoreksi di dokumen |
| – | "Seluruh poin telah diuji dan berfungsi penuh saat di-RUN" | Pengujian otomatis sudah dilakukan (bagian 6), tetapi aplikasi **belum dijalankan di HP sungguhan**. | Klaim diganti dengan hasil uji yang sebenarnya |
| – | "Terlampir 4 screenshot hasil pengujian langsung" | Screenshot belum ada. | Dicatat sebagai tugas yang harus diselesaikan (bagian 8) |

## 2. Poin 01 — Layout Adaptif (Layar Besar / Layar Kecil)

- **Implementasi:** Halaman Beranda (daftar barang), pada `_buildItemList` di [`../lib/screens/home_screen.dart`](../lib/screens/home_screen.dart).
- **Cara kerja:** `LayoutBuilder` membaca lebar yang tersedia (`constraints.maxWidth`) lalu memilih tata letak lewat fungsi [`homeColumnsForWidth`](../lib/screens/home_screen.dart).

| Lebar tersedia | Tata letak | Perangkat tipikal |
|---|---|---|
| < 600 dp | `ListView.builder`, 1 kolom (tampilan lama, tidak berubah) | HP portrait |
| 600 – 899 dp | `GridView.builder`, **2 kolom** | HP landscape, tablet portrait |
| ≥ 900 dp | `GridView.builder`, **3 kolom** | Tablet landscape, browser lebar |

- **Tinggi sel grid** mengikuti ukuran font perangkat (`MediaQuery.textScalerOf`, minimum 138 dp, maksimum 320 dp) agar teks tidak terpotong.
- **Tidak ada UI yang dihapus.** Kartu barang yang sama dipakai di daftar maupun grid.
- Status keadaan Memuat, Error, dan Kosong di Beranda kini dapat di-scroll (`SingleChildScrollView`), sehingga tidak melimpah pada layar pendek.

### Masalah yang ditemukan saat pengujian dan sudah diperbaiki

Pengujian dengan font HP yang diperbesar mengungkap dua overflow nyata (bukan dibuat-buat oleh tes):

| Masalah | Penyebab | Perbaikan |
|---|---|---|
| Badge kategori pada kartu melimpah 4,9 px ke kanan saat font ≥ 1,6× | Badge status yang lebar menyisakan hanya 18 dp untuk badge kategori dalam satu `Row` | Pada font > 1,15× kedua badge dipindah ke `Wrap` sehingga turun baris bila perlu. Pada font normal tampilan **tidak berubah**. |
| Teks badge status melimpah 27 px pada font 2× | `Text` di dalam `Row` tanpa batas lebar | `Flexible` + `maxLines: 1` + elipsis di [`../lib/widgets/badges.dart`](../lib/widgets/badges.dart) |
| Tampilan Memuat/Error/Kosong melimpah ke bawah di HP landscape | Header Beranda menyisakan hanya 75 dp | Dibungkus `SingleChildScrollView` |

## 3. Poin 02 — Keyboard-safe UI

- **Implementasi:** Halaman Posting Barang ([`../lib/screens/post_item_screen.dart`](../lib/screens/post_item_screen.dart)), serta form Masuk, Edit Profil, dan Alamat Pengambilan.
- **Yang diterapkan di kode:**
  - Form berada dalam `ListView` yang dapat di-scroll. Halaman berada di dalam `Scaffold` yang memakai `resizeToAvoidBottomInset` bawaan (`true`), sehingga area konten menyusut di atas keyboard.
  - `scrollPadding` dengan ruang tambahan 120 dp di bawah isian yang difokuskan, supaya pesan error di bawahnya tidak tertutup keyboard.
  - Tombol keyboard **Next** pindah ke isian berikutnya, dan **Selesai** langsung mengirim form.
  - Keyboard tertutup saat area kosong diketuk atau form di-scroll (`keyboardDismissBehavior: onDrag`).
- **Hasil uji:** pengujian dilakukan pada struktur asli aplikasi (form di dalam shell navigasi `StatefulShellRoute`) dengan keyboard setinggi 300 dp pada layar 360 × 640 dp. Posisi bawah isian terhadap tepi atas keyboard (340 dp):

| Isian | Posisi bawah | Terlihat di atas keyboard |
|---|---|---|
| Judul Barang | 234 dp | Ya |
| Deskripsi | 217 dp | Ya |

  Tidak ada error *"Bottom Overflowed"*. Hasil yang sama diperoleh pada layar 360 × 720 dp.

## 4. Poin 03 — Accessibility Dasar

- **Tooltip:** semua `IconButton` memiliki `tooltip`: tombol Kembali (Chat dan sub-halaman Profil) dan tombol lihat/sembunyikan kata sandi. Tombol GPS di peta (`FloatingActionButton`) juga bertooltip. Tombol bulat kustom (Kembali di Detail, lonceng notifikasi) memakai [`AccessibleTap`](../lib/widgets/accessible_tap.dart) dengan tooltip dan label.
- **Semantics:**
  - Foto barang diberi label **"Foto barang: [Nama Barang]"** ([`../lib/widgets/photo_placeholder.dart`](../lib/widgets/photo_placeholder.dart)).
  - Pada daftar, satu kartu dibacakan sebagai satu kalimat ("Meja Belajar. Kategori Furniture. Status disetujui. Pemberi Petra…") dan sebagai tombol. Label foto di dalam kartu sengaja tidak dibacakan terpisah agar tidak terbaca dua kali.
  - Bottom navigation dibacakan "Tab [nama]" beserta status terpilih.
- **Kontras warna:** seluruh pasangan warna utama memenuhi WCAG AA (≥ 4,5 : 1) di mode terang dan gelap.
- **Area sentuh** chip, tab, dan tombol bulat minimal 48 × 48 dp.

Daftar lengkap perbaikan aksesibilitas (label form, heading, peta, pilihan tunggal, dan lain-lain) ada di [`../p7/P7_Review_MVP_Lengkap.md`](../p7/P7_Review_MVP_Lengkap.md), bagian 3.3.

Hasil uji: pedoman aksesibilitas bawaan Flutter (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) lolos pada layar Masuk, Posting, dan kartu barang. Label foto "Foto barang: Meja Belajar" terbaca di pohon semantik.

## 5. Poin 04 — Feedback Aksi

- **Loading:** saat tombol Post, Simpan, atau Konfirmasi Pengajuan ditekan, tombol langsung **nonaktif** (mencegah kirim ganda) dan menampilkan indikator berputar disertai teks proses ("Memposting barang…", "Menyimpan…", "Mengirim pengajuan…"). Proses lain memakai dialog progres ("Menerima pengajuan…", "Menghapus barang…"). Pencarian GPS di peta menampilkan spinner dan teks "Mencari lokasi GPS kamu…".
- **Sukses / Gagal:** setiap hasil ditampilkan lewat `SnackBar` yang sekarang berwarna sesuai jenisnya melalui [`AppMessenger`](../lib/widgets/progress_dialog.dart):

| Jenis | Warna | Dipakai untuk | Kontras teks |
|---|---|---|---|
| Sukses | Hijau (warna utama tema) | Barang diposting, pengajuan terkirim, profil/alamat tersimpan, barang dihapus, pengajuan diterima/ditolak, berhasil masuk | 6,29 : 1 (terang), 7,99 : 1 (gelap) |
| Gagal | Merah (warna *danger* tema) | Gagal menyimpan/memposting, izin kamera/lokasi ditolak, GPS gagal, form belum lengkap | 4,96 : 1 (terang), 6,43 : 1 (gelap) |
| Informasi | Abu gelap bawaan | Keluar akun, perubahan menunggu koneksi | – |

- Setiap `SnackBar` memiliki **ikon** (centang / tanda seru / info) selain warna, agar pesan tidak bergantung pada warna saja (pengguna buta warna). Pesan gagal tampil 5 detik, pesan lain 4 detik, dan dibacakan otomatis oleh pembaca layar.
- **Hijau hanya bila server benar-benar sudah mengonfirmasi.** Jika perangkat offline atau koneksi lambat, aplikasi menunggu 8–12 detik lalu menampilkan pesan informasi netral: *"Perubahan sedang diproses dan akan terkirim otomatis saat koneksi kembali."* Aplikasi tidak menampilkan "berhasil" untuk sesuatu yang belum pasti.
- **Pesan gagal menyebut penyebab** (tidak ada koneksi internet, akses ditolak, data tidak ditemukan, atau izin ditolak), bukan pesan umum.
- **Penyimpanan:** foto disimpan sebagai Base64 di Cloud Firestore, **bukan** di Firebase Storage.

## 6. Hasil Verifikasi

| Pemeriksaan | Hasil |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 25 tests passed |
| `flutter build web` | Berhasil |
| Layout adaptif pada 4 ukuran: 360 dp → daftar; 768 dp → grid; 800 dp (HP landscape) → grid; 1280 dp → grid | Sesuai rancangan |
| Titik peralihan `homeColumnsForWidth`: 599,9 → 1; 600 → 2; 899,9 → 2; 900 → 3 | Sesuai rancangan |
| Overflow pada 14 kombinasi ukuran layar × ukuran font | 11 aman, 3 masih overflow (lihat bagian 7) |
| Keyboard: Judul dan Deskripsi tetap di atas keyboard pada struktur shell asli, tanpa padding `viewInsets` | Lolos |
| Kontras `SnackBar` sukses/gagal, mode terang dan gelap | Seluruhnya ≥ 4,5 : 1 |
| `SnackBar` sukses berwarna hijau, gagal merah, keduanya berikon | Lolos |
| Label foto "Foto barang: [Nama]" terbaca pembaca layar | Lolos |

Pengujian di atas memakai tes widget sekali jalan yang tidak disimpan di repositori, sehingga jumlah tes tetap 25. Layar yang membutuhkan Firebase (Detail, Profil, Aktivitas, Notifikasi) tidak dapat diuji otomatis; perilaku GPS, kamera, TalkBack, dan offline juga bergantung pada perangkat. Bagian-bagian itu harus diperiksa manual di HP.

14 kombinasi yang diuji: HP portrait 360 × 800 (font 1,15× / 1,2× / 1,6× / 2×), HP kecil 320 × 568 (1× / 2×), HP landscape 800 × 360 (1× / 1,6× / 2×, termasuk daftar kosong), tablet 768 × 1024 (1,6× / 2×), dan desktop 1280 × 800 (1×).

## 7. Keterbatasan yang Diketahui

- **Header Beranda pada layar sangat pendek dengan font maksimum.** Tiga kombinasi masih overflow di bagian bawah: HP kecil 320 × 568 dengan font 2× (56 px), serta HP landscape 800 × 360 dengan font 2× (25 px, baik dengan barang maupun daftar kosong). Penyebabnya diduga header Beranda (sapaan, pencarian, chip kategori) yang tidak muat pada tinggi layar sependek itu, tetapi widget penyebab pastinya belum ditelusuri. Memperbaikinya berarti mengubah struktur Beranda agar header ikut menggulir bersama daftar. Pada font hingga 1,6× semua kombinasi aman.
- **Belum diuji di HP sungguhan.** Seluruh bukti di atas berasal dari pengujian otomatis dan pembacaan kode.
- **Tombol bertinggi tetap.** Tombol Post, Masuk, Simpan, Hapus Barang, dan Keluar masih bertinggi tetap 52–54 dp. Pada font yang sangat besar, teksnya bisa terpotong.
- **Aksi saat offline.** Setelah batas tunggu terlewati, aplikasi menampilkan pesan "akan terkirim otomatis" tanpa mengetahui hasil akhirnya. Jika server kemudian menolak perubahan itu, pengguna tidak mendapat pemberitahuan lanjutan.
- **Warna `SnackBar` informasi** memakai warna bawaan Material, bukan warna tema.
- **Login dan Chat** masih berupa prototipe lokal.

## 8. Bukti Screenshot

Dosen meminta 4 screenshot hasil pengujian saat aplikasi dijalankan. **Screenshot ini belum diambil.** Simpan tangkapan layar dari HP di folder `p8/dokumentasi/` dengan nama berikut, lalu tambahkan tautan gambarnya ke tabel ini.

| Poin | Yang harus terlihat di screenshot | Nama file |
|---|---|---|
| 01 Layout adaptif | Beranda di HP portrait (1 kolom) dan di layar lebar atau HP dimiringkan (grid 2 kolom) | `01_layout_adaptif.png` |
| 02 Keyboard-safe | Form Posting saat mengetik Deskripsi dengan keyboard terbuka, isian terlihat di atas keyboard | `02_keyboard_safe.png` |
| 03 Aksesibilitas | TalkBack aktif membacakan kartu barang atau tombol, atau tooltip yang muncul saat ikon ditekan lama | `03_aksesibilitas.png` |
| 04 Feedback aksi | Tombol "Memposting barang…" atau `SnackBar` hijau "Barang berhasil diposting!" (dan satu `SnackBar` merah untuk kasus gagal) | `04_feedback_aksi.png` |

### Cara menjalankan untuk screenshot

```powershell
flutter run                     # HP Android (disarankan)
flutter run -d chrome           # browser, untuk tampilan layar lebar
```

- **Grid:** putar HP ke landscape, atau lebarkan jendela browser melebihi 600 dp.
- **SnackBar merah:** aktifkan Mode Pesawat lalu tekan Simpan pada Alamat, atau tekan Post dengan form kosong.
- **Tooltip:** tekan lama tombol kembali atau tombol GPS.
