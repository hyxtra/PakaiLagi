# Pertemuan 7 — MVP Lengkap PakaiLagi

Dokumen ini menjelaskan status akhir MVP PakaiLagi, tiga *advanced feature* utama, penyempurnaan UI/UX berdasarkan catatan dosen (layout adaptif, keyboard-safe, aksesibilitas, feedback aksi), penanganan state, dan cara demonstrasinya.

## 1. Status Alur MVP

Alur utama dapat didemonstrasikan dari awal hingga akhir:

1. Pengguna mengatur **alamat pengambilan** di Profil dengan *pinpoint* peta berbasis GPS.
2. Pengguna mem-posting barang dengan foto dari kamera atau galeri. Alamat penjemputan diambil dari profil.
3. Pengguna lain melihat feed dan detail barang. Lokasi yang tampil hanya kelurahan dan kota.
4. Peminta mengajukan pengambilan dan memilih metode: **Antar ke Alamat** atau **Bertemu (COD)**.
5. Pemilik menerima atau menolak pengajuan. Setelah diterima, peminta dapat melihat alamat lengkap dan membuka titik penjemputan di Google Maps.
6. Pemilik dapat menghapus barang miliknya.

Teknologi: navigasi dengan GoRouter, state dengan Riverpod, data dengan Cloud Firestore, dan identitas teknis dengan Firebase Anonymous Auth.

## 2. Tiga Advanced Features Utama

### 2.1 Kamera & Media — `image_picker`

Pengguna memotret barang langsung dengan kamera HP atau memilih foto dari galeri pada halaman **Posting**. Foto membantu pemberi menunjukkan kondisi fisik barang secara jujur kepada calon penerima.

| Aspek | Implementasi |
|---|---|
| Sumber foto | Bottom sheet "Pilih dari Galeri" / "Ambil Foto" |
| Kompresi | `maxWidth: 600`, `imageQuality: 70` agar ukuran Base64 jauh di bawah batas 1 MiB per dokumen Firestore |
| Penyimpanan | Base64 mentah di field `imageBase64` (tanpa Firebase Storage, sehingga tetap memakai paket gratis Spark) |
| Pembatalan | Jika dialog atau kamera dibatalkan, fungsi berhenti tanpa menyimpan nilai null |
| Izin ditolak | Jika izin kamera/galeri ditolak, muncul SnackBar yang menyebut izin mana yang perlu diaktifkan di Pengaturan HP |
| Validasi | Posting ditolak bila belum ada foto, disertai pesan merah dan SnackBar |

Lokasi kode: [`../lib/screens/post_item_screen.dart`](../lib/screens/post_item_screen.dart), [`../lib/repositories/firebase_repository.dart`](../lib/repositories/firebase_repository.dart).

### 2.2 GPS & Lokasi — `geolocator`, `geocoding`, `flutter_map`, `url_launcher`

Fitur ini terdiri dari dua bagian: **pinpoint presisi** saat mendaftarkan alamat, dan **tombol buka Google Maps** di halaman Detail.

#### a. Pinpoint lokasi penjemputan (Profil → Alamat Pengambilan)

1. Pengguna menekan **"Pinpoint Lokasi di Peta (GPS)"**.
2. Layar peta terbuka dan langsung meminta posisi GPS dengan `LocationAccuracy.best` (batas waktu 15 detik).
3. Peta diarahkan ke posisi GPS. Titik biru menandai posisi pengguna, dan lingkaran biru menunjukkan radius akurasi GPS dalam meter.
4. Pin merah tetap di tengah layar. Pengguna menggeser peta sampai pin tepat di titik penjemputan (misalnya depan pagar rumah). Tombol 🎯 mengembalikan peta ke posisi GPS.
5. Setiap kali peta berhenti digeser (jeda 700 ms), aplikasi membaca alamat dari titik tersebut (*reverse geocoding*). Panel bawah menampilkan alamat, koordinat 6 desimal, dan akurasi GPS.
6. **"Pilih Titik Ini"** mengisi Alamat Lengkap, Kelurahan/Desa, dan Kota/Kabupaten secara otomatis, lalu menampilkan peta mini di form. Pengguna melengkapi nomor rumah atau RT/RW lalu menekan **Simpan**.

Selama GPS dicari atau alamat dibaca, tombol **Pilih Titik Ini** dinonaktifkan dan teksnya berubah ("Mencari GPS…" / "Membaca alamat…") agar titik dan alamat yang dipilih selalu cocok.

Peta memakai OpenStreetMap melalui `flutter_map` sehingga tidak membutuhkan API key.

#### b. Buka titik penjemputan di Google Maps (halaman Detail)

| Siapa yang melihat | Yang ditampilkan | Tombol |
|---|---|---|
| Pemilik barang | Alamat lengkap + peta mini dengan pin | **Buka Titik di Google Maps** (koordinat persis) |
| Peminta yang pengajuannya **diterima** | Alamat lengkap + peta mini dengan pin | **Buka Titik di Google Maps** (koordinat persis) |
| Pengguna lain | Kelurahan & kota saja | **Lihat Area di Google Maps** (area, bukan titik rumah) |

Tautan memakai format Google Maps URLs (`https://www.google.com/maps/search/?api=1&query=lat,lng`). Di Android/iOS tautan dibuka oleh aplikasi Google Maps bila terpasang, selain itu oleh browser.

#### c. Privasi lokasi

Koordinat GPS cukup presisi untuk menunjukkan rumah pemberi, sehingga data lokasi dipisah:

| Dokumen Firestore | Isi | Siapa yang boleh membaca |
|---|---|---|
| `items/{itemId}` | `kelurahan`, `kota` | Semua pengguna yang login |
| `items/{itemId}/private/location` | `address`, `latitude`, `longitude` | Pemilik barang dan peminta yang diterima |
| `profiles/{uid}` | Alamat lengkap, kelurahan, kota, koordinat, nomor HP | Pemilik akun saja |

Aturan ini ditegakkan di server oleh [`../firestore.rules`](../firestore.rules), bukan hanya disembunyikan di UI. Rules juga menolak dokumen `items` yang mencoba menyimpan field `address`, `latitude`, atau `longitude`.

Lokasi kode:

| File | Peran |
|---|---|
| [`../lib/screens/location_picker_screen.dart`](../lib/screens/location_picker_screen.dart) | Layar pinpoint peta, GPS, lingkaran akurasi, reverse geocoding |
| [`../lib/services/location_service.dart`](../lib/services/location_service.dart) | Izin & posisi GPS, reverse geocoding, pembuka Google Maps |
| [`../lib/screens/profile_screen.dart`](../lib/screens/profile_screen.dart) | Form Alamat Pengambilan + peta mini |
| [`../lib/screens/item_detail_screen.dart`](../lib/screens/item_detail_screen.dart) | Bagian "Lokasi Pengambilan" + tombol Google Maps |
| [`../lib/widgets/pin_preview_map.dart`](../lib/widgets/pin_preview_map.dart) | Peta mini non-interaktif |
| [`../lib/business/address_privacy.dart`](../lib/business/address_privacy.dart) | Label publik "Kel. X, Kota Y" dan pemetaan hasil geocoding |
| [`../lib/repositories/firebase_repository.dart`](../lib/repositories/firebase_repository.dart) | Batch penulisan data publik + lokasi privat |

Izin platform: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, dan `INTERNET` di [`AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml); `NSLocationWhenInUseUsageDescription` di [`Info.plist`](../ios/Runner/Info.plist). Aplikasi hanya meminta izin lokasi saat sedang dipakai (*foreground*), tidak di latar belakang.

### 2.3 Dukungan Mode Offline — Firestore Persistence

[`FirestoreConfiguration.configure()`](../lib/services/firestore_configuration.dart) mengaktifkan `persistenceEnabled: true` sebelum aplikasi berjalan. Dokumen yang pernah dimuat (katalog, detail barang, Barang Saya, Menunggu Persetujuan, notifikasi) disimpan di cache perangkat, sehingga tetap bisa dibuka saat koneksi terputus. Perubahan yang dibuat saat offline diantrekan dan dikirim ketika koneksi kembali.

Saat pengguna menekan tombol aksi dalam keadaan offline, aplikasi tidak lagi menunggu tanpa batas. Penjelasan perilakunya ada di bagian 3.4.

Catatan: tile peta OpenStreetMap tidak ikut di-cache untuk offline. Saat offline, area peta yang belum pernah dimuat tampil kosong, tetapi teks alamat tetap terlihat dari cache Firestore.

## 3. Penyempurnaan UI/UX (Catatan Dosen)

Catatan dosen terdiri dari empat poin yang dinilai saat aplikasi dijalankan. Tidak ada elemen UI yang dihapus; perubahan tampilan dirangkum di bagian 3.5.

### 3.1 Layout adaptif (layar besar / layar kecil)

Dosen menilai poin ini **BAGUS**. Pada pertemuan ini Beranda hanya memakai widget fleksibel (`Expanded`, `Flexible`, `ListView`, `Wrap`), tanpa titik patah (*breakpoint*) khusus. Beranda kemudian dikembangkan pada P8 agar benar-benar adaptif: daftar 1 kolom di bawah 600 dp, grid 2 kolom di 600–899 dp, dan grid 3 kolom di 900 dp ke atas (lihat [`../p8/P8_UIUX_Polish_Adaptivity.md`](../p8/P8_UIUX_Polish_Adaptivity.md)). Penyesuaian berikut dilakukan di P7 agar layout tetap aman saat ukuran font HP diperbesar:

- Baris chip kategori di Beranda mengikuti ukuran font (`MediaQuery.textScalerOf`), dan area sentuhnya minimal 48 dp.
- Kartu barang di Beranda memakai `Expanded` + `Align` sehingga nama kategori yang panjang terpotong dengan elipsis dan tidak menyebabkan *overflow*.
- Tombol "Ajukan Pengambilan" dan "Konfirmasi Pengajuan" (minimum 54 dp) serta "Terima" dan "Tolak" (minimum 48 dp) dapat bertambah tinggi mengikuti teks, bukan tinggi tetap.

### 3.2 Keyboard-safe UI

Tujuannya agar kolom isian tetap terlihat saat keyboard aktif dan pengguna tidak perlu menutup keyboard secara manual.

| Perilaku | Implementasi | Layar |
|---|---|---|
| Tombol keyboard **Next** pindah ke isian berikutnya | `textInputAction: next` | Masuk/Daftar, Edit Profil, Alamat Pengambilan; di Posting dari Judul langsung ke Deskripsi |
| Tombol keyboard **Selesai** langsung mengirim form | `textInputAction: done` + `onSubmitted` | Masuk/Daftar (kata sandi), Edit Profil (Nomor HP), Alamat (Kota) |
| Tombol keyboard **Cari** | `textInputAction: search` | Beranda |
| Mengetuk area kosong menutup keyboard | `GestureDetector` di `MaterialApp.builder` ([`../lib/app.dart`](../lib/app.dart)) | Seluruh aplikasi |
| Men-scroll form/daftar menutup keyboard | `keyboardDismissBehavior: onDrag` | Masuk, Posting, Edit Profil, Alamat, Beranda, Chat |
| Pesan error tidak tertutup keyboard | `scrollPadding` dengan ruang tambahan 120 dp di bawah isian yang difokuskan | Masuk, Posting, Edit Profil, Alamat |
| Keyboard ditutup sebelum hasil ditampilkan | `unfocus()` saat Post/Simpan/Masuk ditekan | Masuk, Posting, Edit Profil, Alamat |
| Kapitalisasi otomatis | `textCapitalization` (kalimat untuk judul/deskripsi/alamat, kata untuk nama/kota) | Posting, Profil |
| Keyboard tetap terbuka setelah kirim pesan | `onEditingComplete` kosong | Chat |

Seluruh form berada di dalam area yang dapat di-scroll, dan `Scaffold` menggeser konten ke atas keyboard (`resizeToAvoidBottomInset` bawaan).

### 3.3 Aksesibilitas dasar

#### a. Kontras warna (WCAG 2.1 AA, minimal 4,5 : 1)

Rasio kontras dihitung dengan rumus *relative luminance* WCAG. Warna yang tidak lolos diganti, dan seluruh nilai sekarang berada di palet tema ([`../lib/theme/app_palette.dart`](../lib/theme/app_palette.dart)).

| Pasangan warna | Sebelum | Sesudah |
|---|---|---|
| Teks tombol oranye (Masuk, Ajukan, Simpan, Konfirmasi) | putih 2,17 : 1 | teks gelap **7,15 : 1** |
| Teks abu-abu (`textMuted`) di latar halaman, mode terang | 4,19 : 1 | **5,30 : 1** |
| Teks abu-abu di latar hijau muda, mode terang | 3,85 : 1 | **4,86 : 1** |
| Teks badge kategori (oranye) | 2,67 : 1 | **5,34 : 1** |
| Badge status "DISETUJUI" | 1,97 : 1 | **4,86 : 1** |
| Badge status "SELESAI" | 2,31 : 1 | **5,54 : 1** |
| Hijau utama di atas permukaan, mode gelap | 4,31 : 1 | **7,22 : 1** |
| Teks di atas tombol hijau, mode gelap | putih 3,93 : 1 | teks gelap **7,99 : 1** |
| Badge status "TERSEDIA", mode gelap | 2,41 : 1 | **5,63 : 1** |
| Teks tombol nonaktif ("Barang Tidak Tersedia") | putih 2,59 : 1 | teks gelap **5,98 : 1** |
| Jam pada gelembung chat milik sendiri | 4,03 : 1 | **5,07 : 1** |

Sebanyak 19 pasangan warna utama di mode terang dan gelap diperiksa, dan seluruhnya ≥ 4,5 : 1.

#### b. Pembaca layar (TalkBack / VoiceOver)

| Masalah sebelumnya | Perbaikan |
|---|---|
| 9 kontrol kustom (chip kategori, kartu barang, tab Aktivitas, tab Masuk/Daftar, chip form Posting, area foto, pilihan metode, balasan cepat chat) berupa `GestureDetector` yang tidak dikenali sebagai tombol | Diganti [`AccessibleTap`](../lib/widgets/accessible_tap.dart): dibacakan sebagai tombol, dengan status terpilih/tidak, dan memiliki efek sentuh (*ripple*) |
| Tombol ikon tanpa label | Tombol kembali (Detail, Chat, sub-halaman Profil), lonceng notifikasi (dengan jumlah belum dibaca), kirim chat, tombol GPS, dan lihat/sembunyikan kata sandi kini memiliki label dan *tooltip* |
| Label form terpisah dari isian; pembaca layar hanya membacakan teks contoh | Label, isian, dan pesan error digabung (`MergeSemantics`), sehingga dibacakan "Judul Barang, …, kotak edit" |
| Pesan error tidak dibacakan | Pesan error ditandai `liveRegion` sehingga dibacakan saat muncul |
| Kartu barang dibacakan sebagai potongan teks | Satu kalimat: judul, kategori, status, pemberi |
| Emoji sebagai ikon dibacakan sebagai nama emoji | Emoji dikecualikan dari pembaca layar; foto diberi label "Foto <judul>" |
| Judul bagian tidak dikenali | Judul halaman dan bagian ditandai sebagai *heading* |
| Peta tidak punya keterangan | Peta mini dan peta pinpoint diberi label; alamat di panel peta dibacakan otomatis saat berubah |
| Bottom navigation tidak menyebut tab aktif | Setiap tab dibacakan "Tab <nama>" beserta status terpilih |
| Pilihan tunggal (kategori, metode, mode Masuk/Daftar) | Dibacakan sebagai pilihan dalam satu grup (*radio*) |
| Tombol "Kelola Pengajuan" tidak menyebut barang | Dibacakan "Kelola pengajuan untuk <judul>, N pengajuan baru" |

#### c. Area sentuh dan ukuran teks

- Chip, tab, dan tombol bulat memiliki area sentuh **minimal 48 × 48 dp** (pedoman Android/Material). Tampilan visual chip tidak diperbesar; hanya area sentuhnya.
- Tombol kirim chat, "Kelola Pengajuan", dan "Buka Titik di Google Maps" naik dari 46 dp menjadi 48 dp.
- Tombol "Ajukan Pengambilan", "Konfirmasi Pengajuan", "Terima", dan "Tolak" memakai tinggi minimum (54 dp dan 48 dp), sehingga ikut membesar saat ukuran font HP diperbesar. Tombol lain (Post, Masuk, Simpan, Hapus Barang, Keluar, Pinpoint) masih bertinggi tetap 52–54 dp, lihat bagian 7.

### 3.4 Feedback aksi

Prinsipnya: setiap aksi pengguna harus dijawab oleh UI, sehingga pengguna tidak perlu bertanya "sedang diproses atau tidak?".

| Aksi | Sebelum | Sesudah |
|---|---|---|
| **Konfirmasi Pengajuan** | Tidak ada tanda proses; tombol bisa diketuk berulang | Tombol menjadi "Mengirim pengajuan…" dengan spinner dan nonaktif; jika gagal, sheet tetap terbuka agar bisa langsung dicoba lagi |
| **Setelah mengajukan** | Tombol tetap "Ajukan Pengambilan" | Tombol berubah sesuai status: "Menunggu Persetujuan Pemberi", "Pengajuan Diterima", atau "Pengajuan Ditolak" |
| **Terima / Tolak pengajuan** | Langsung dieksekusi tanpa konfirmasi atau indikator | Dialog konfirmasi (keputusan tidak dapat diubah), lalu dialog progres "Menerima pengajuan…" / "Menolak pengajuan…", lalu SnackBar hasil. Bila barang sudah direservasi, ada teks yang menjelaskan mengapa tombol Terima nonaktif |
| **Hapus barang** | Tanpa indikator setelah konfirmasi | Dialog progres "Menghapus barang…", lalu SnackBar dan kembali ke halaman sebelumnya |
| **Post barang** | Spinner saja | Tombol "Memposting barang…"; bila form belum lengkap, halaman otomatis menggulir ke isian pertama yang salah disertai SnackBar "Lengkapi N isian yang ditandai merah." |
| **Simpan Edit Profil** | Tanpa indikator | Tombol "Menyimpan…" dan seluruh isian dikunci selama proses |
| **Simpan Alamat** | Spinner saja | Tombol "Menyimpan…" dan seluruh isian dikunci |
| **Masuk / Daftar** | Langsung pindah halaman | SnackBar "Berhasil masuk. Halo, <nama>!"; bila form tidak valid, error diperbarui langsung saat mengetik |
| **Keluar** | Langsung keluar | Dialog konfirmasi, lalu SnackBar "Kamu sudah keluar dari akun." |
| **Ketuk notifikasi** | Menunggu server dulu baru pindah halaman | Pindah halaman langsung; tanda "sudah dibaca" dikirim di belakang |
| **Pencarian GPS di peta** | Panel menulis "Alamat tidak terbaca" saat GPS masih dicari | Panel menulis "Mencari lokasi GPS kamu…" |
| **Memuat daftar barang** | Spinner tanpa keterangan | Spinner dengan teks "Memuat barang…" |
| **Statistik Profil** | Selalu menampilkan 0 | Dihitung dari data Firestore; tampil "–" selama data belum termuat |
| **Nomor HP pemberi** | Baris kosong | "Nomor HP tidak dicantumkan" |

#### Perilaku saat offline

Operasi tulis Firestore baru selesai setelah server mengonfirmasi, sehingga saat offline tombol sebelumnya berputar tanpa akhir. Kini setiap aksi tulis menunggu paling lama beberapa detik ([`awaitWrite`](../lib/services/user_messages.dart)):

| Aksi | Batas tunggu |
|---|---|
| Hapus barang, simpan profil, simpan alamat | 8 detik |
| Post barang | 10 detik |
| Pengajuan, terima/tolak pengajuan | 12 detik |

Jika batas terlewati, pengguna melihat pesan *"Koneksi sedang lambat atau terputus. Perubahan sedang diproses dan akan terkirim otomatis saat koneksi kembali."* Perubahan tetap tersimpan di cache perangkat dan dikirim otomatis oleh Firestore ketika koneksi kembali.

Pesan gagal juga lebih spesifik ([`friendlyError`](../lib/services/user_messages.dart)): tidak ada koneksi, akses ditolak server, data tidak ditemukan, atau server terlalu lama merespons.

Lokasi kode: [`../lib/widgets/accessible_tap.dart`](../lib/widgets/accessible_tap.dart), [`../lib/widgets/progress_dialog.dart`](../lib/widgets/progress_dialog.dart), [`../lib/services/user_messages.dart`](../lib/services/user_messages.dart), [`../lib/theme/app_palette.dart`](../lib/theme/app_palette.dart), [`../lib/app.dart`](../lib/app.dart), serta layar yang terdampak (`sign_in`, `home`, `post_item`, `item_detail`, `manage_request`, `profile`, `activity`, `chat`, `notifications`).

### 3.5 Perubahan tampilan yang perlu diketahui

- **Teks pada tombol oranye** kini gelap, bukan putih, karena putih tidak memenuhi standar kontras.
- **Hijau pada mode gelap** lebih terang; teks abu-abu dan teks badge sedikit lebih gelap di mode terang.
- **Ukuran yang sedikit bertambah:** bar balasan cepat chat 42 → 52 dp (chip tetap 34 dp), tombol kirim chat, "Kelola Pengajuan", dan "Buka Titik di Google Maps" 46 → 48 dp.
- **Elemen baru:** tombol lihat/sembunyikan kata sandi, dialog konfirmasi Terima/Tolak dan Keluar, serta dialog progres.
- Tombol **"Chat Pemberi"** tidak lagi muncul pada barang milik sendiri.
- Barang berstatus "Selesai" tidak lagi terbaca "Tersedia" di layar Kelola Pengajuan.

## 4. Penanganan UX States

| State | Implementasi |
|---|---|
| Loading | Beranda, Barang Saya, Kelola Pengajuan, dan Notifikasi menampilkan `CircularProgressIndicator` dengan label untuk pembaca layar. Tombol Post, Simpan, dan Konfirmasi Pengajuan berubah menjadi spinner disertai teks proses dan dinonaktifkan. Tombol 🎯 di peta menampilkan spinner selama mencari GPS; panel peta menampilkan "Mencari lokasi GPS kamu…" atau "Membaca alamat…". |
| Empty | Beranda, Barang Saya, pengajuan keluar, dan daftar pengajuan memiliki pesan kosong. Lokasi yang belum diatur tampil "Lokasi belum diatur". |
| Error | Stream Firestore menampilkan pesan kegagalan; Beranda menyediakan "Coba lagi". Aksi yang gagal menampilkan SnackBar dengan penyebab yang spesifik. |
| Offline | Aksi tulis berhenti menunggu setelah 8–12 detik dan menampilkan pesan bahwa perubahan akan terkirim otomatis. Data yang pernah dimuat tetap terbaca dari cache. |
| Cancel kamera | Pemilih foto yang dibatalkan menghentikan proses tanpa null exception. |
| Izin kamera/galeri ditolak | SnackBar menyebut izin yang perlu diaktifkan di Pengaturan HP. |
| GPS mati | SnackBar meminta pengguna mengaktifkan GPS. Peta tetap bisa digeser manual. |
| Izin lokasi ditolak | SnackBar menjelaskan bahwa titik bisa dipilih manual dengan menggeser peta. Jika ditolak permanen, pengguna diarahkan ke Pengaturan HP. |
| GPS terlalu lama | Setelah 15 detik, SnackBar menyarankan pindah ke tempat terbuka atau memilih titik manual. |
| Alamat tidak terbaca | Titik tetap bisa dipilih; pengguna diminta mengisi alamat, kelurahan, dan kota secara manual. |
| Google Maps tidak tersedia | SnackBar "Tidak ada aplikasi untuk membuka Google Maps." |
| Alamat profil belum lengkap | Posting ditolak dengan pesan merah dan tombol "Atur di Profil". |

## 5. Cara Demonstrasi

Persiapan (sekali): jalankan `flutter pub get`, lalu deploy rules dan index dengan `firebase deploy --only firestore`.

1. **Kamera** — Jalankan `flutter run` di HP Android. Buka tab **Posting**, ketuk area foto, pilih **Ambil Foto**, lalu tekan Batal untuk menunjukkan *cancel handling*. Ulangi dan ambil foto sungguhan.
2. **GPS pinpoint** — Buka **Profil → Alamat Pengambilan → Pinpoint Lokasi di Peta (GPS)**. Izinkan akses lokasi. Tunjukkan titik biru, lingkaran akurasi, dan nilai "Akurasi GPS ±X m". Geser peta sedikit dan tunjukkan alamat yang berubah. Tekan **Pilih Titik Ini**, lengkapi nomor rumah, lalu **Simpan**.
3. **Posting** — Kembali ke **Posting**. Tunjukkan alamat lengkap dari profil dan keterangan "Terlihat oleh pengguna lain: Kel. X, Kota Y". Isi form lalu tekan **Post**.
4. **Privasi & Google Maps** — Buka detail barang dari HP/akun lain. Tunjukkan bahwa hanya kelurahan & kota yang tampil, lalu tekan **Lihat Area di Google Maps**. Ajukan pengambilan, terima dari akun pemilik, lalu buka detail lagi dari akun peminta: alamat lengkap, peta mini, dan tombol **Buka Titik di Google Maps** kini tampil.
5. **Offline** — Setelah katalog dan detail pernah dibuka, aktifkan Mode Pesawat. Buka ulang katalog, detail, dan tab Aktivitas untuk menunjukkan data dari cache.
6. **Layout adaptif** — Buka Beranda di HP, lalu di browser (`flutter run -d chrome`) atau dengan ukuran font HP diperbesar (Pengaturan → Tampilan → Ukuran font). Tunjukkan bahwa chip dan kartu tidak terpotong.
7. **Keyboard-safe** — Di form **Posting**, ketuk Judul, ketik, lalu tekan **Next** di keyboard: fokus pindah ke Deskripsi dan kolom tetap terlihat di atas keyboard. Ketuk area kosong untuk menutup keyboard. Di layar **Masuk**, isi kata sandi lalu tekan **Selesai**.
8. **Aksesibilitas** — Aktifkan TalkBack (letak menu berbeda tiap merek HP, umumnya Pengaturan → Aksesibilitas → TalkBack). Sentuh kartu barang dan chip kategori untuk menunjukkan bahwa keduanya dibacakan sebagai tombol berikut statusnya. Tunjukkan juga tombol oranye dengan teks gelap.
9. **Feedback aksi** — Ajukan pengambilan dan tunjukkan tombol "Mengirim pengajuan…", lalu tombol yang berubah menjadi "Menunggu Persetujuan Pemberi". Dari akun pemilik, tekan **Terima** untuk menunjukkan dialog konfirmasi dan dialog "Menerima pengajuan…". Terakhir, aktifkan Mode Pesawat lalu tekan **Simpan** pada Alamat untuk menunjukkan pesan bahwa perubahan akan dikirim saat online.

Demo GPS sebaiknya memakai HP sungguhan. Emulator Android memakai lokasi tiruan dari pengaturan emulator.

## 6. Hasil Verifikasi

| Pemeriksaan | Hasil |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 25 tests passed |
| `flutter build web` | Berhasil |
| Kompilasi `firestore.rules` (`firebase deploy --only firestore:rules --dry-run`) | Berhasil |
| Kontras warna, 19 pasangan × 2 mode | Seluruhnya ≥ 4,5 : 1 |
| Pedoman aksesibilitas Flutter (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) pada layar Masuk, Posting, dan kartu barang | Lolos |
| Keyboard: Next, Selesai, ketuk area kosong, dan isian tetap terlihat di atas keyboard pada layar 360 × 720 dp | Lolos |
| Posting dengan form kosong menggulir ke isian pertama yang salah | Lolos |

Tiga baris terakhir diperiksa dengan 14 tes widget sekali jalan yang seluruhnya lulus. File tes tersebut tidak disimpan di repositori, karena itu jumlah tes tetap 25.

Layar yang membutuhkan Firebase (Detail, Profil, Aktivitas, Notifikasi, Kelola Pengajuan) tidak dapat diuji otomatis tanpa emulator Firebase. Selain itu, GPS, kamera, TalkBack, dan perilaku offline bergantung pada perangkat. Bagian-bagian ini diperiksa manual mengikuti langkah demo pada bagian 5.

## 7. Keterbatasan yang Diketahui

- **Web**: peta dan GPS browser berfungsi (butuh `localhost` atau HTTPS), tetapi alamat tidak terbaca otomatis karena paket `geocoding` hanya mendukung Android dan iOS. Alamat diisi manual.
- **Akurasi GPS** bergantung pada perangkat dan lingkungan. Di dalam ruangan akurasi bisa puluhan meter, sehingga pengguna menyempurnakan titik dengan menggeser peta.
- **Tile OpenStreetMap** gratis untuk pemakaian kecil seperti demo tugas. Aplikasi dengan banyak pengguna perlu penyedia tile sendiri atau berbayar.
- **Barang lama** yang diposting sebelum fitur ini belum punya kelurahan, kota, dan titik peta, sehingga tampil "Lokasi belum diatur".
- **Aksi saat offline**: setelah batas tunggu terlewati, aplikasi menampilkan pesan "perubahan akan terkirim otomatis" tanpa mengetahui hasil akhirnya. Jika server kemudian menolak perubahan itu (misalnya karena aturan keamanan), pengguna tidak mendapat pemberitahuan lanjutan.
- **Metode pengambilan** yang dipilih pemberi saat memposting belum disimpan, sehingga peminta selalu melihat kedua metode (Antar ke Alamat dan Bertemu (COD)).
- **Tinggi tetap**: tombol Post, Masuk/Buat Akun, Simpan, Hapus Barang, Keluar, Pinpoint, dan Pilih Titik Ini masih bertinggi tetap 52–54 dp. Pada ukuran font HP yang sangat besar, teksnya bisa terpotong.
- **Login** masih tiruan dan belum terhubung ke Firebase Authentication; Firebase hanya memakai akun anonim untuk identitas teknis.
- **Chat** masih berupa prototipe lokal dan belum tersimpan di server.

## 8. Bukti Demo

Simpan tangkapan layar di folder `p7/dokumentasi/` dengan nama berikut, lalu tautan di bawah akan tampil otomatis.

**Advanced feature**

| Fitur | Tangkapan layar |
|---|---|
| Kamera: pilih sumber foto | ![Kamera](dokumentasi/01_kamera.png) |
| GPS: peta pinpoint dengan lingkaran akurasi | ![Pinpoint](dokumentasi/02_gps_pinpoint.png) |
| GPS: form alamat dengan peta mini | ![Form alamat](dokumentasi/03_alamat_profil.png) |
| Detail: tampilan publik (kelurahan & kota) | ![Detail publik](dokumentasi/04_detail_publik.png) |
| Detail: peminta diterima + tombol Google Maps | ![Detail diterima](dokumentasi/05_detail_google_maps.png) |
| Offline: katalog dari cache (Mode Pesawat) | ![Offline](dokumentasi/06_offline.png) |

**Catatan dosen (4 tangkapan layar)**

| Poin | Tangkapan layar |
|---|---|
| 01 Layout adaptif: Beranda di HP dan di layar lebar | ![Layout adaptif](dokumentasi/07_layout_adaptif.png) |
| 02 Keyboard-safe: form Posting saat mengetik Deskripsi dengan keyboard terbuka | ![Keyboard-safe](dokumentasi/08_keyboard_safe.png) |
| 03 Aksesibilitas: TalkBack aktif membacakan kartu barang atau chip kategori | ![Aksesibilitas](dokumentasi/09_aksesibilitas.png) |
| 04 Feedback aksi: tombol "Mengirim pengajuan…" atau dialog "Menerima pengajuan…" | ![Feedback aksi](dokumentasi/10_feedback_aksi.png) |
