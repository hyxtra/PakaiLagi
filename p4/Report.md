# PROMPTS.md — Dokumentasi Tugas State Management (Flutter + Riverpod)

> **Proyek:** PakaiLagi — Aplikasi donasi barang bekas  
> **Fitur yang diimplementasikan:** Post Item (Tambah Barang)  
> **State Management:** `flutter_riverpod` dengan pola Clean Architecture  

---

## 1. Informasi Reviewer: Posisi Kode State Management

Implementasi fitur "Post Item" dipisahkan ke dalam 3 lapisan utama sesuai prinsip Clean Architecture:

| Lapisan | Tanggung Jawab | Lokasi File |
|---------|---------------|-------------|
| **Widget (UI)** | Menampilkan antarmuka, menangani input pengguna, dan merespon perubahan state | `lib/screens/post_item_screen.dart` |
| **Notifier (Logika & State)** | Mengelola logika bisnis, mengubah state, dan menjadi jembatan antara UI dan data | `lib/notifiers/item_notifier.dart` |
| **State (Definisi Kondisi UI)** | Mendefinisikan semua kemungkinan kondisi UI menggunakan `sealed class` | `lib/notifiers/item_state.dart` |
| **Repository (Sumber Data)** | Menyediakan data kategori (simulasi API) dengan kemampuan simulasi error/empty | `lib/repositories/item_repository.dart` |
| **Model (Kontrak Data)** | Model data `Item`, `Category`, dan `ItemModel` | `lib/models/item.dart`, `lib/models/item_model.dart` |
| **Widget Test** | Pengujian otomatis untuk memvalidasi 6 kondisi UI | `test/post_item_screen_test.dart` |

### Diagram Ketergantungan Antar-Lapisan

```
┌─────────────────────────────────┐
│   post_item_screen.dart (UI)    │  ← Hanya tahu State & Notifier
│   Membaca state, mengirim aksi  │
└──────────────┬──────────────────┘
               │ ref.watch / ref.read
               ▼
┌─────────────────────────────────┐
│   item_notifier.dart (Logika)   │  ← Mengelola state, memanggil Repository
│   + item_state.dart (Kondisi)   │
└──────────────┬──────────────────┘
               │ fetchCategories()
               ▼
┌─────────────────────────────────┐
│   item_repository.dart (Data)   │  ← Sumber data (mock/API)
│   Mengembalikan List<Category>  │
└─────────────────────────────────┘
```

---

## 2. Informasi Reviewer: Proses Kerja State Management (6 Kondisi UI)

State dikelola menggunakan `sealed class PostItemState` yang memiliki 4 subclass. Dengan pola ini, compiler Dart memastikan **semua kondisi ditangani** di UI melalui exhaustive `switch`.

### Alur Perpindahan State:

**Kondisi 1 → Initial Loading:**  
Saat `PostItemScreen` pertama kali dibuka, `postItemNotifierProvider` dibuat secara otomatis. Di dalam pembuatan provider, `loadCategories()` langsung dipanggil. State awal adalah `PostItemLoading()` — UI menampilkan `CircularProgressIndicator` dan teks "Memuat data kategori...".

**Kondisi 2 → Data Berhasil Dimuat (Form):**  
Jika `repository.fetchCategories()` berhasil dan hasilnya tidak kosong, state berubah menjadi `PostItemLoaded(categories: [...])`. UI menampilkan form lengkap: **Foto Barang** (image_picker), **Judul**, **Kategori** (chip selector), **Deskripsi**, **Metode Pengambilan** (multi-select chip), dan **Alamat Penjemputan** (toggle alamat profil / isi manual).

**Kondisi 3 → Empty State:**  
Jika `fetchCategories()` berhasil tapi mengembalikan list kosong, state menjadi `PostItemEmpty()`. UI menampilkan ikon, pesan "Belum Ada Kategori", dan tombol "Muat Ulang" yang memanggil `loadCategories()` ulang.

**Kondisi 4 → Error State + Retry:**  
Jika `fetchCategories()` melempar exception, state menjadi `PostItemError(message)`. UI menampilkan ikon ☁️✗, pesan error, dan tombol "Coba Lagi" yang memanggil `loadCategories()` ulang untuk mencoba kembali.

**Kondisi 5 → Validasi Input Form:**  
Validasi dilakukan **di dalam Widget** (`_validateForm()`) tanpa mengubah state utama dari Notifier. Pesan error merah ditampilkan di bawah setiap field yang kosong menggunakan `Map<String, String> _validationErrors` lokal. Validasi mencakup: Judul, Kategori, Deskripsi, Metode Pengambilan, dan Alamat (jika toggle "Pakai alamat profil" dimatikan).

**Kondisi 6 → Loading Saat Submit (Anti Double Tap):**  
Saat user menekan "Kirim" dan validasi lolos, `submitItem()` di Notifier mengubah `PostItemLoaded.isSubmitting` menjadi `true`. UI merespons dengan: tombol berubah menjadi spinner, tombol di-disable (`onPressed: null`), dan semua field input juga di-disable. Setelah submit selesai, `isSubmitting` kembali `false` dan form di-reset.

### Diagram Alur State:

```
                    ┌───────────────┐
        ┌───────────│ PostItemLoading│ (Kondisi 1)
        │           └───────┬───────┘
        │                   │ fetchCategories()
        │                   ▼
        │     ┌─────────────┼──────────────┐
        │     ▼             ▼              ▼
        │  Berhasil      Kosong         Error
        │     │             │              │
        │     ▼             ▼              ▼
        │  ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  │  Loaded   │ │  Empty   │ │  Error   │
        │  │(Kondisi 2)│ │(Kondisi 3)│ │(Kondisi 4)│
        │  └──┬───────┘ └────┬─────┘ └────┬─────┘
        │     │              │             │
        │     │ submit()     │ retry       │ retry
        │     ▼              └─────────────┘
        │  isSubmitting=true      │
        │  (Kondisi 6)            │
        │     │                   │
        │     ▼                   │
        │  Selesai → reset form   │
        └─────────────────────────┘
```

---

## 3. Dokumentasi Transparansi AI

### 3.1 Prompt Utama

Ringkasan prompt yang digunakan untuk menginstruksikan AI:

> *"Buatkan implementasi fitur Post Item menggunakan Clean Architecture (3 lapisan: Widget, Notifier, Repository) dengan state management flutter_riverpod. Implementasikan 6 kondisi UI: (1) Initial Loading saat fetch kategori, (2) Data Loaded menampilkan form, (3) Empty State jika kategori kosong, (4) Error State dengan tombol Retry, (5) Validasi Input Form, (6) Loading saat Submit untuk mencegah double tap. Sertakan widget test untuk semua 6 kondisi."*

### 3.2 Review & Perbaikan Mandiri

Beberapa penyesuaian yang saya periksa dan perbaiki sendiri terhadap kode hasil AI:

* **Perbaikan Flaky Test:** Widget test awalnya menggunakan `Future.delayed` yang menyebabkan pending timer saat pengujian. Saya ganti dengan `_FakePostItemNotifier` yang langsung meng-set state secara synchronous tanpa memanggil repository asli, sehingga `flutter test` berjalan 100% tanpa flaky.

* **Pembersihan Lint:** Menghapus sintaks `const` redundan pada parameter durasi dan menghapus fungsi helper yang tidak terpakai agar hasil `flutter analyze` bersih tanpa warning.

* **Keamanan Async Gap:** Menambahkan pengecekan `mounted` sebelum memanggil `ScaffoldMessenger.of(context).showSnackBar()` setelah proses async `submitItem()` selesai, untuk mencegah error jika user sudah meninggalkan screen.

* **Pemulihan Fitur yang Hilang:** Saat refactoring ke Clean Architecture, AI menulis ulang `post_item_screen.dart` dari nol sehingga beberapa fitur dari versi asli hilang (upload foto, toggle alamat profil, multi-select metode pengambilan). Saya bandingkan dengan repo asli dan gabungkan kembali semua fitur ke dalam struktur Clean Architecture.

* **Pemisahan Lapisan:** Saya verifikasi bahwa Widget hanya menangani UI, Notifier hanya mengelola logika dan state, dan Repository hanya menyediakan data — tidak ada pencampuran tanggung jawab antar-lapisan.

---

## 4. Bukti Screenshot & Widget Test

> **Catatan:** Ganti placeholder di bawah ini dengan screenshot asli dari perangkat/emulator.

### 4.1 Screenshot 6 Kondisi UI

| Kondisi | Screenshot |
|---------|-----------|
| 1. Initial Loading | ![Kondisi 1 - Loading](screenshots/kondisi_1_loading.png) |
| 2. Data Loaded (Form) | ![Kondisi 2 - Form](screenshots/kondisi_2_form.png) |
| 3. Empty State | ![Kondisi 3 - Empty](screenshots/kondisi_3_empty.png) |
| 4. Error State + Retry | ![Kondisi 4 - Error](screenshots/kondisi_4_error.png) |
| 5. Validasi Input | ![Kondisi 5 - Validasi](screenshots/kondisi_5_validasi.png) |
| 6. Submit Loading | ![Kondisi 6 - Submit](screenshots/kondisi_6_submit.png) |

### 4.2 Hasil Widget Test (`flutter test`)

![Hasil Flutter Test](screenshots/flutter_test_result.png)

### 4.3 Hasil Analisis (`flutter analyze`)

![Hasil Flutter Analyze](screenshots/flutter_analyze_result.png)