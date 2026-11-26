# P11 — Branching, Issues, Unit Tests, dan CI/CD

## Alur branch

`v1.0` menjadi titik awal rilis. Kerjakan perubahan di `v1.0_dev`, lalu gabungkan ke `V1.1` setelah review.

```bash
git switch main
git pull origin main
git switch -c v1.0
git push -u origin v1.0

git switch -c v1.0_dev
git push -u origin v1.0_dev
# Kerjakan P11 di branch ini, lalu commit dan push.

git switch -c V1.1 v1.0
git merge --no-ff v1.0_dev
git push -u origin V1.1
```

Jika branch `v1.0` sudah mewakili commit rilis yang ada di GitHub, gunakan `git switch v1.0` sebagai ganti membuatnya lagi. Pipeline berjalan pada push dan pull request ke `v1.0_dev` maupun `V1.1`.

## Sepuluh GitHub Issues

### 1. [BUG] Hapus pencarian harus mengembalikan semua barang

**Deskripsi masalah:** Hasil Beranda masih dapat tertahan oleh filter kategori/kondisi setelah query pencarian dikosongkan.

**Langkah reproduksi:** Pilih kategori, cari judul, lalu hapus seluruh teks pencarian.

**Diharapkan vs aktual:** Diharapkan daftar kembali menampilkan seluruh barang tersedia dan chip kembali ke “Semua”; aktualnya daftar dapat tampak kosong/masih tersaring.

**Solusi perbaikan:** Hitung ulang filter dari query saat ini dan reset pilihan kategori/kondisi saat query kosong.

```bash
git commit -m "Fixes #1 Reset feed filters when search is cleared"
```

### 2. [BUG] Tolak judul dan deskripsi yang hanya berisi spasi

**Deskripsi masalah:** Whitespace dapat terlihat seperti input, tetapi tidak mempunyai isi yang berguna.

**Langkah reproduksi:** Masukkan spasi saja ke judul atau deskripsi, lalu simpan.

**Diharapkan vs aktual:** Diharapkan validasi menolak nilai kosong setelah trim; aktualnya nilai berisi spasi berisiko lolos.

**Solusi perbaikan:** Terapkan `.trim()` terpusat di `ItemValidator`.

```bash
git commit -m "Fixes #2 Trim text before item validation"
```

### 3. [BUG] Tampilkan koordinat ringkas tanpa overflow

**Deskripsi masalah:** Banyak angka desimal membuat koordinat sulit dibaca dan dapat meluber pada layar sempit.

**Langkah reproduksi:** Buka pemilih lokasi pada perangkat sempit dan lihat label koordinat.

**Diharapkan vs aktual:** Diharapkan empat angka desimal dan teks tetap berada di layout; aktualnya koordinat panjang berisiko overflow.

**Solusi perbaikan:** Format latitude/longitude dengan `toStringAsFixed(4)` serta batasi baris dan overflow.

```bash
git commit -m "Fixes #3 Format coordinates for narrow screens"
```

### 4. [BUG] Perbarui state Detail setelah pengajuan dikirim

**Deskripsi masalah:** Tombol Ajukan Ambil dapat sesaat tetap terlihat aktif setelah pengajuan berhasil.

**Langkah reproduksi:** Buka detail barang, kirim pengajuan, lalu amati tombol.

**Diharapkan vs aktual:** Diharapkan tombol segera menunjukkan status menunggu; aktualnya UI bisa menunggu pembaruan berikutnya.

**Solusi perbaikan:** Sinkronkan provider pengajuan setelah write dan tampilkan status dari stream pengajuan.

```bash
git commit -m "Fixes #4 Refresh detail request state after submit"
```

### 5. [BUG] Tangani timestamp null pada barang lama

**Deskripsi masalah:** Dokumen Firestore lama atau belum memiliki `createdAt` dapat gagal diparse.

**Langkah reproduksi:** Baca dokumen tanpa timestamp atau dengan timestamp null.

**Diharapkan vs aktual:** Diharapkan model tetap dimuat dengan tanggal opsional; aktualnya parser dapat melempar error.

**Solusi perbaikan:** Terima `Timestamp`, `DateTime`, atau null di `ItemModel.fromMap`.

```bash
git commit -m "Fixes #5 Handle missing Firestore timestamps"
```

### 6. [FEATURE] Tambahkan penawaran Gratis dan Tebus Murah

**Deskripsi masalah:** Pengguna tidak dapat membedakan barang gratis dari barang dengan harga simbolis.

**Langkah reproduksi:** Buat barang dan cari pilihan jenis penawaran serta harga.

**Diharapkan vs aktual:** Diharapkan dapat memilih Gratis atau Tebus Murah hingga Rp50.000; aktualnya hanya ada satu jenis penawaran.

**Solusi perbaikan:** Tambahkan field listing type dan validasi harga di form, validator, model, repository, dan Firestore rules.

```bash
git commit -m "Fixes #6 Add free and low-cost listing types"
```

### 7. [FEATURE] Tambahkan alasan saat mengajukan pengambilan

**Deskripsi masalah:** Pemberi barang tidak memperoleh konteks kebutuhan peminta.

**Langkah reproduksi:** Buka detail barang dan tekan Ajukan Pengambilan.

**Diharapkan vs aktual:** Diharapkan peminta bisa menulis alasan singkat yang terlihat pemberi; aktualnya tidak ada input alasan.

**Solusi perbaikan:** Simpan alasan opsional dengan batas 240 karakter dan tampilkan pada pengelolaan pengajuan.

```bash
git commit -m "Fixes #7 Add a short pickup request reason"
```

### 8. [FEATURE] Sediakan filter kondisi barang di Beranda

**Deskripsi masalah:** Pengguna tidak dapat menyaring barang berdasarkan kondisi.

**Langkah reproduksi:** Buka Beranda dan cari filter kondisi.

**Diharapkan vs aktual:** Diharapkan tersedia Semua, Seperti Baru, Sangat Layak, dan Layak Pakai; aktualnya feed hanya dapat disaring lewat kategori/pencarian.

**Solusi perbaikan:** Tambahkan field kondisi, chip filter, dan filter gabungan kategori/kondisi.

```bash
git commit -m "Fixes #8 Add item condition filter to feed"
```

### 9. [FEATURE] Tampilkan jarak barang dari lokasi profil

**Deskripsi masalah:** Pengguna sulit memperkirakan jarak sebelum mengatur pengambilan.

**Langkah reproduksi:** Atur koordinat profil dan buka detail barang dengan lokasi yang dapat diakses.

**Diharapkan vs aktual:** Diharapkan jarak garis lurus ditampilkan dalam km; aktualnya jarak tidak tersedia.

**Solusi perbaikan:** Hitung jarak Haversine dan gunakan koordinat barang privat hanya bagi pemilik/peminta yang diterima.

```bash
git commit -m "Fixes #9 Show privacy-safe item distance"
```

### 10. [FEATURE] Bagikan ringkasan barang ke WhatsApp

**Deskripsi masalah:** Pengguna perlu menyusun ulang informasi barang sebelum membagikannya.

**Langkah reproduksi:** Buka detail barang dan tekan tombol bagikan.

**Diharapkan vs aktual:** Diharapkan ringkasan judul, kategori, kondisi, penawaran, area, dan deskripsi siap dibagikan; aktualnya belum ada formatter khusus.

**Solusi perbaikan:** Buat `ShareFormatter` murni dan buka tautan berbagi WhatsApp dari halaman detail.

```bash
git commit -m "Fixes #10 Add WhatsApp item summary sharing"
```

## Verifikasi 200 unit tests

Suite P9 yang sudah ada tetap dipertahankan sebanyak 81 test. Untuk menjaga seluruh test lama sekaligus mencapai tepat 200 kasus aktual pada satu perintah `flutter test`, P11 menambah 119 test: 38 validator, 32 model, 27 helper, dan 22 filter. Pembagian ini menyesuaikan rencana awal 60/50/50/40 yang jika ditambahkan ke suite P9 akan menghasilkan 281 kasus, bukan 200.

```bash
flutter test --reporter expanded
```

### Simulasi pipeline gagal

Tambahkan sementara assertion yang sengaja salah ke salah satu test, misalnya `expect(2 + 2, 5);`, lalu jalankan `flutter test`. Job `unit-test` harus gagal dan job `build-and-deploy` tidak berjalan karena menggunakan `needs: unit-test`.

Pulihkan assertion tersebut, jalankan kembali `flutter test` sampai semua 200 test lulus, lalu push perubahan. Sesudah tes lulus, workflow membangun APK release dan mengunggah artifact `pakailagi-release-apk`.
