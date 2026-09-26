# Architecture: PakaiLagi Mobile Application

## Purpose
Membangun platform aplikasi *mobile* untuk berbagi barang yang masih layak pakai secara gratis. Aplikasi ini berfokus pada siklus MVP: **Share → Find → Request → Approve → Handover → Complete**. Data disimpan dan dikelola menggunakan infrastruktur *Backend-as-a-Service* (BaaS) Supabase, dan aplikasi dibangun menggunakan **Flutter** untuk menargetkan *build* Android APK serta distribusi Web/PWA (Progressive Web App).

## Tech Stack
*   **Frontend:** Flutter SDK + Dart
*   **Styling:** Widget bawaan Flutter (`ThemeData`, `TextStyle`) — tanpa library styling tambahan
*   **State Management:** Riverpod (`StateNotifierProvider`/`Notifier` untuk state UI, `FutureProvider`/`AsyncNotifierProvider` untuk data server)
*   **Routing:** go_router (mendukung nested route, tab, dan deep link — juga kompatibel dengan Flutter Web)
*   **Backend & Auth:** Supabase (PostgreSQL, Supabase Auth) via package `supabase_flutter`
*   **Storage:** Supabase Storage (untuk gambar barang)
*   **Form Validation:** Validasi manual per-field (opsional: `flutter_form_builder` bila butuh struktur lebih rapi)
*   **Image Handling:** `image_picker` (ambil foto) + `flutter_image_compress` (kompresi sebelum upload)
*   **Realtime (opsional):** Supabase Realtime — untuk update status `ItemRequest` otomatis di ActivityScreen tanpa perlu refresh manual
*   **Deployment:** `flutter build apk` untuk Android, `flutter build web` untuk rilis Web/PWA (hosting di Vercel/Netlify)

## Code Rules
*   Gunakan Dart dengan *null safety* diaktifkan penuh.
*   Gunakan `PascalCase` untuk nama Class, Screen (Widget), Model, dan Enum.
*   Gunakan `camelCase` untuk variabel lokal, fungsi, method, dan nama file (`snake_case` untuk nama file sesuai konvensi Dart, misal `login_screen.dart`).
*   Pisahkan secara tegas antara komponen UI (*Screens/Widgets*) dengan logika pemanggilan data (*Services/Providers*).
*   Gunakan Bahasa Indonesia untuk semua label UI, tombol, pesan *error*, dan validasi.

## Main Entities (Database Models)

Semua entitas berada di dalam database PostgreSQL Supabase (tidak berubah dari desain awal).

1. **Profile**
   *   `Id` (UUID, PK, berelasi langsung dengan `auth.users` Supabase)
   *   `FullName` (String)
   *   `PhoneNumber` (String, nullable)
   *   `AvatarUrl` (String, nullable)
   *   `CreatedAt` (Timestamp)

2. **Item**
   *   `Id` (UUID, PK)
   *   `OwnerId` (UUID, FK -> Profile.Id)
   *   `Title` (String)
   *   `Description` (Text)
   *   `Category` (String)
   *   `Status` (Enum: `AVAILABLE`, `RESERVED`, `COMPLETED`)
   *   `ImageUrl` (String, URL dari Supabase Storage)
   *   `CreatedAt` (Timestamp)

3. **ItemRequest**
   *   `Id` (UUID, PK)
   *   `ItemId` (UUID, FK -> Item.Id)
   *   `RequesterId` (UUID, FK -> Profile.Id)
   *   `Status` (Enum: `PENDING`, `ACCEPTED`, `REJECTED`)
   *   `DeliveryMethod` (Enum: `AMBIL_LANGSUNG`, `BERTEMU`, `KURIR`)
   *   `CreatedAt` (Timestamp)

## Database Rules & Security (Supabase RLS)
*   **Row Level Security (RLS)** harus diaktifkan untuk semua tabel.
*   **Profile:** Pengguna hanya dapat mengedit (UPDATE) baris profil milik mereka sendiri.
*   **Item:**
    *   Semua pengguna yang terautentikasi (SELECT) dapat melihat barang dengan status `AVAILABLE`.
    *   Hanya pengguna yang membuat barang (`OwnerId`) yang dapat melakukan UPDATE atau DELETE.
*   **ItemRequest:**
    *   Pengaju (`RequesterId`) dapat melihat dan membatalkan pengajuannya sendiri.
    *   Pemilik barang (`OwnerId`) dapat melihat semua pengajuan terhadap barang miliknya dan melakukan UPDATE status (menerima/menolak).

## Frontend Screens (UI Requirements)

1. **Auth Flow**
   *   **LoginScreen:** Form email dan password.
   *   **RegisterScreen:** Form pendaftaran (Email, Password, FullName).

2. **Main Tab Navigation**
   *   **HomeScreen:** Menampilkan daftar barang `AVAILABLE`. Memiliki kolom pencarian (*search bar*) dan filter kategori.
   *   **PostItemScreen:** Form dengan input gambar, judul, kategori, dan deskripsi untuk membuat `Item` baru.
   *   **ActivityScreen:** Menampilkan dua tab:
       *   *Menunggu Persetujuan:* Daftar barang yang sedang diajukan oleh *user*.
       *   *Barang Saya:* Daftar barang milik *user* dan status pengajuannya dari orang lain.
   *   **ProfileScreen:** Menampilkan detail profil dan tombol *Logout*.

3. **Detail & Action Screens**
   *   **ItemDetailScreen:** Menampilkan informasi lengkap barang. Tombol "Ajukan Pengambilan" muncul jika *user* bukan pemilik barang.
   *   **RequestModal:** Pop-up/layar (`showModalBottomSheet`) untuk memilih metode pengambilan (`DeliveryMethod`) sebelum mengonfirmasi pengajuan.
   *   **ManageRequestScreen:** Halaman khusus pemilik barang untuk melihat daftar pengaju, beserta tombol "Terima" atau "Tolak".

## Core Data Operations (Supabase Client via `supabase_flutter`)

*   `fetchItems()`: Mengambil daftar `Item` dengan status `AVAILABLE`.
*   `fetchItemById(id)`: Mengambil detail satu `Item` beserta informasi `Profile` dari `OwnerId`.
*   `createItem(data)`: Kompresi gambar (`flutter_image_compress`), unggah ke Supabase Storage, lalu melakukan INSERT ke tabel `Item`.
*   `createRequest(itemId, method)`: INSERT ke tabel `ItemRequest` dengan status `PENDING`. (Status `Item` dibiarkan TETAP `AVAILABLE` agar bisa menerima banyak pengajuan).
*   `approveRequest(requestId, itemId)`: Memanggil fungsi RPC `approve_handover` di Supabase untuk eksekusi transaksi yang aman.
*   `completeHandover(itemId)`: UPDATE `Item` status menjadi `COMPLETED`.

## Advanced Database Operations (Supabase)
Untuk menjaga integritas data dan mencegah *bug* logika aplikasi:
1. **Database Transactions via RPC:** Fungsi `approve_handover(target_request_id, target_item_id)` akan membungkus 3 aksi dalam satu transaksi: mengubah status target request menjadi `ACCEPTED`, menolak sisa request lain menjadi `REJECTED`, dan mengubah status item menjadi `RESERVED`.
2. **Storage Auto-Cleanup (Trigger):** PostgreSQL Trigger memantau tabel Item. Jika barang dihapus, trigger otomatis menghapus file gambar fisiknya di Supabase Storage.

## PWA Considerations (Flutter Web)
*   Konfigurasi `web/manifest.json` (nama app, icon, `display: "standalone"`, warna tema) agar Chrome menampilkan opsi "Instal" di Android.
*   Flutter secara default menyertakan *service worker* dasar saat `flutter build web` — pastikan caching strategy sesuai kebutuhan offline-first.
*   Hosting via Vercel/Netlify otomatis menyediakan HTTPS, memenuhi syarat wajib PWA.

## Project Structure

Struktur aplikasi berbasis Flutter (single-package).

```text
pakailagi/
├── android/                # Konfigurasi native Android (untuk build APK)
├── web/                    # Konfigurasi Flutter Web (manifest.json, index.html)
├── assets/                 # Gambar lokal statis, ikon aplikasi
├── lib/
│   ├── main.dart           # Entry point aplikasi
│   ├── app.dart            # Root widget, setup tema & router
│   ├── routes/
│   │   └── app_routes.dart # Konfigurasi go_router
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── post_item/
│   │   │   └── post_item_screen.dart
│   │   ├── activity/
│   │   │   └── activity_screen.dart
│   │   ├── profile/
│   │   │   └── profile_screen.dart
│   │   └── item_detail/
│   │       ├── item_detail_screen.dart
│   │       ├── request_modal.dart
│   │       └── manage_request_screen.dart
│   ├── widgets/             # UI reusable (PrimaryButton, AppTextField, ItemCard, StatusBadge)
│   ├── models/              # ProfileModel, ItemModel, ItemRequestModel (fromJson/toJson)
│   ├── providers/           # Riverpod providers (authProvider, itemsProvider, requestsProvider)
│   ├── services/            # supabase_service.dart, auth_service.dart, item_service.dart, request_service.dart
│   └── constants/           # Konfigurasi kategori, tema warna, pesan error
├── pubspec.yaml             # Dependencies (supabase_flutter, flutter_riverpod, go_router, image_picker, flutter_image_compress)
└── analysis_options.yaml    # Linting rules
```
