# Architecture: PakaiLagi Mobile Application

## Purpose
Membangun platform aplikasi *mobile* untuk berbagi barang yang masih layak pakai secara gratis. Aplikasi ini berfokus pada siklus MVP: **Share → Find → Request → Approve → Handover → Complete**. Data disimpan dan dikelola menggunakan infrastruktur *Backend-as-a-Service* (BaaS) Supabase, dan aplikasi dibangun menggunakan React Native (Expo) untuk menargetkan *build* Android APK.

## Tech Stack
*   **Frontend:** React Native (Expo) + TypeScript
*   **Styling:** NativeWind (Tailwind CSS)
*   **Backend & Auth:** Supabase (PostgreSQL, Supabase Auth)
*   **Storage:** Supabase Storage (Untuk gambar barang)
*   **State Management:** Zustand (Global State) + TanStack Query (Data Fetching/Caching)
*   **Deployment:** EAS (Expo Application Services) untuk *build* `.apk`

## Code Rules
*   Gunakan TypeScript dengan *strict mode* diaktifkan.
*   Gunakan `PascalCase` untuk nama File *Screen*, *Component*, *Type/Interface*, dan *Database Models*.
*   Gunakan `camelCase` untuk variabel lokal, fungsi, dan nama *hooks*.
*   Pisahkan secara tegas antara komponen UI (*Screens/Components*) dengan logika pemanggilan data (*Services/Hooks*).
*   Gunakan Bahasa Indonesia untuk semua label UI, tombol, pesan *error*, dan validasi sesuai target pengguna.

## Main Entities (Database Models)

Semua entitas berada di dalam database PostgreSQL Supabase.

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
   *   `Status` (Enum: `AVAILABLE`, `REQUESTED`, `RESERVED`, `COMPLETED`)
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
   *   **RequestModal:** Pop-up/layar untuk memilih metode pengambilan (`DeliveryMethod`) sebelum mengonfirmasi pengajuan.
   *   **ManageRequestScreen:** Halaman khusus pemilik barang untuk melihat daftar pengaju, beserta tombol "Terima" atau "Tolak".

## Core Data Operations (Supabase Client)

*Berbeda dengan REST API tradisional, aplikasi ini berkomunikasi langsung dengan Supabase SDK.*

*   `fetchItems()`: Mengambil daftar `Item` dengan status `AVAILABLE`.
*   `fetchItemById(id)`: Mengambil detail satu `Item` beserta informasi `Profile` dari `OwnerId`.
*   `createItem(data)`: Mengunggah foto ke Supabase Storage, lalu melakukan INSERT ke tabel `Item`.
*   `createRequest(itemId, method)`: INSERT ke tabel `ItemRequest` dan menginisiasi status `PENDING`. UPDATE tabel `Item` menjadi `REQUESTED`.
*   `approveRequest(requestId, itemId)`: 
    *   UPDATE `ItemRequest` yang dipilih menjadi `ACCEPTED`.
    *   UPDATE otomatis semua `ItemRequest` lain untuk `itemId` tersebut menjadi `REJECTED`.
    *   UPDATE `Item` menjadi `RESERVED`.
*   `completeHandover(itemId)`: UPDATE `Item` status menjadi `COMPLETED`.

## Project Structure

Struktur monorepo sederhana berbasis Expo.

```text
pakailagi/
├── assets/                 # Gambar lokal statis, ikon aplikasi
├── src/
│   ├── components/         # UI reusable (Button, Card, InputField)
│   ├── constants/          # Konfigurasi kategori, tema warna, error messages
│   ├── hooks/              # React Query hooks (useItems.ts, useAuth.ts)
│   ├── navigation/         # Pengaturan React Navigation (TabNavigator, RootStack)
│   ├── screens/            # Layar aplikasi utama
│   ├── services/           # Konfigurasi Supabase (supabase.ts)
│   ├── store/              # Zustand global state (authStore.ts)
│   ├── types/              # Definisi antarmuka TypeScript (database.types.ts)
│   └── utils/              # Fungsi utilitas (formatDate, dll)
├── App.tsx                 # Entry point aplikasi
├── app.json                # Konfigurasi EAS dan Expo
├── tailwind.config.js      # Konfigurasi NativeWind
└── tsconfig.json           # Konfigurasi TypeScript