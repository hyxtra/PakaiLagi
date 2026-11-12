# Pertemuan 9 — Test & Refactor PakaiLagi

Dokumen ini merangkum analisis kondisi awal kode, daftar perubahan yang dilakukan, serta panduan verifikasi dalam siklus **Refactor → Test** pada proyek PakaiLagi.

Pendekatan yang digunakan mengacu pada prinsip **Clean Code**: menghilangkan duplikasi (*DRY*) dan memisahkan tanggung jawab tiap komponen (*Separation of Concerns*).

---

## 1. Analisis Kondisi Awal

Sebelum refactoring dilakukan, dilakukan pemeriksaan menyeluruh terhadap struktur file dan logika yang ada. Berikut hasilnya:

| Aspek | Kondisi Awal |
|---|---|
| `lib/validators/item_validator.dart` | ✅ Sudah ada dan berfungsi |
| `lib/utils/item_validator.dart` | ❌ Belum ada — path ini perlu disediakan sebagai alias |
| `lib/repositories/item_repository.dart` | ⚠️ Ada, namun hanya mengelola kategori (bukan operasi Firestore) |
| `lib/repositories/firebase_repository.dart` | ✅ Repository Firestore lengkap sudah tersedia |
| `_validateForm()` di `PostItemScreen` | ❌ **Duplikasi** — aturan validasi ditulis ulang secara manual, tidak memanggil `ItemValidator` |
| SnackBar helper | ⚠️ `AppMessenger` dipanggil langsung di banyak layar tanpa helper terpusat |
| Unit test validator | ✅ `test/validators/item_validator_test.dart` sudah ada (3 test) |
| Widget test `PostItemScreen` | ✅ `test/post_item_screen_test.dart` sudah ada (6 kondisi UI) |

### Temuan Duplikasi Utama

Metode `_validateForm()` di `PostItemScreen` memiliki aturan validasi yang **sama persis** dengan `ItemValidator`, tetapi tidak memanggil class tersebut — melainkan mendefinisikan ulang kondisinya secara terpisah:

```dart
// Di PostItemScreen._validateForm() — DUPLIKASI ❌
if (_titleCtrl.text.trim().isEmpty) errors['title'] = 'Judul wajib diisi';

// Di ItemValidator — SUMBER KEBENARAN ✅
static String? validateTitle(String? value) {
  if (value == null || value.trim().isEmpty) return 'Judul wajib diisi';
  return null;
}
```

Kondisi ini melanggar prinsip DRY karena perubahan aturan validasi harus dilakukan di dua tempat sekaligus, yang berpotensi menimbulkan inkonsistensi.

---

## 2. Penyesuaian Path

Terdapat perbedaan antara path yang digunakan di spesifikasi tugas (`lib/utils/item_validator.dart`) dengan path yang sudah ada di project (`lib/validators/item_validator.dart`).

Solusi yang dipilih adalah **membuat file re-export** di `lib/utils/item_validator.dart` yang mengarah ke file asli di `lib/validators/`. Pendekatan ini memungkinkan kedua path digunakan secara bergantian tanpa memindahkan file dan tanpa memutus import yang sudah berjalan.

---

## 3. Daftar Perubahan

### 3.1 File Baru

| File | Fungsi |
|---|---|
| `lib/utils/item_validator.dart` | Re-export dari `validators/item_validator.dart` agar tersedia di dua path |
| `lib/widgets/form_field_widget.dart` | Widget reusable: `AppTextField`, `AppErrorText`, `AppLabeledField` |
| `test/utils/item_validator_utils_test.dart` | Unit test untuk memverifikasi re-export berjalan benar |
| `test/widgets/form_field_widget_test.dart` | Widget test untuk ketiga widget baru |

### 3.2 File yang Dimodifikasi

| File | Perubahan |
|---|---|
| `lib/screens/post_item_screen.dart` | `_validateForm()` kini memanggil `ItemValidator`; helper UI diganti widget reusable |
| `lib/validators/item_validator.dart` | Ditambah `validatePickupMethods()` dan `validateImage()` |
| `test/validators/item_validator_test.dart` | Ditambah test untuk dua validator baru |

---

## 4. Prinsip Clean Code yang Diterapkan

| Prinsip | Penerapan |
|---|---|
| **DRY** *(Don't Repeat Yourself)* | `_validateForm()` memanggil `ItemValidator` sebagai sumber kebenaran tunggal; helper UI dikonsolidasi ke widget reusable |
| **Separation of Concerns** | Validasi → `ItemValidator`; tampilan field → `AppTextField`; operasi Firestore → `FirebaseRepository` |
| **Single Responsibility** | Setiap class dan fungsi memiliki satu tanggung jawab yang jelas |
| **Testability** | Semua logika validasi bersifat murni (*pure function*), tidak bergantung pada Flutter atau Firebase, sehingga mudah diuji tanpa setup tambahan |

---

## 5. Verifikasi — Menjalankan Analisis dan Test

Jalankan perintah berikut dari direktori root project di terminal:

```powershell
# Analisis statis — pastikan tidak ada error atau peringatan
dart analyze lib test

# Jalankan seluruh test suite
flutter test
```

Untuk menjalankan test per file secara terpisah:

```powershell
flutter test test/validators/item_validator_test.dart
flutter test test/utils/item_validator_utils_test.dart
flutter test test/widgets/form_field_widget_test.dart
```

### Target Hasil

```text
dart analyze lib test  →  No issues found!
flutter test           →  All tests passed!
```

### Rincian Test per File

| File | Jumlah Test | Jenis |
|---|---|---|
| `test/validators/item_validator_test.dart` | 15 | Unit test — 5 validator (title, category, description, methods, image) |
| `test/utils/item_validator_utils_test.dart` | 6 | Unit test — verifikasi re-export via path `utils/` |
| `test/widgets/form_field_widget_test.dart` | 10 | Widget test — `AppErrorText`, `AppTextField`, `AppLabeledField` |
| `test/post_item_screen_test.dart` | 6 | Widget test — 6 kondisi UI `PostItemScreen` (tidak diubah) |

---

## 6. Struktur File Setelah P9

```text
lib/
├── utils/
│   └── item_validator.dart          ← Baru (re-export)
├── validators/
│   └── item_validator.dart          ← Dimodifikasi (+2 validator)
├── widgets/
│   └── form_field_widget.dart       ← Baru (AppTextField + AppErrorText + AppLabeledField)
└── screens/
    └── post_item_screen.dart        ← Dimodifikasi (961 → 796 baris)

test/
├── utils/
│   └── item_validator_utils_test.dart  ← Baru (6 test)
├── validators/
│   └── item_validator_test.dart        ← Dimodifikasi (3 → 15 test)
└── widgets/
    └── form_field_widget_test.dart     ← Baru (10 test)
```

---

## 7. Ringkasan Perubahan per File

### `lib/validators/item_validator.dart`
Dua validator baru ditambahkan agar seluruh aturan validasi form terpusat di satu tempat:
- `validatePickupMethods(Set<String>)` — memastikan minimal satu metode pengambilan dipilih
- `validateImage(String?)` — memastikan foto barang sudah dipilih sebelum posting

### `lib/utils/item_validator.dart`
File baru berisi satu baris re-export yang mengarahkan ke `validators/item_validator.dart`, sehingga kedua path dapat digunakan secara bergantian tanpa efek samping.

### `lib/widgets/form_field_widget.dart`
Tiga widget reusable yang diekstrak dari `PostItemScreen`:
- `AppErrorText` — teks pesan validasi merah dengan dukungan aksesibilitas (`liveRegion`)
- `AppTextField` — `TextField` bertemakan `AppPalette`, otomatis menampilkan `AppErrorText` bila ada error
- `AppLabeledField` — gabungan label + `AppTextField` dalam satu node semantik (`MergeSemantics`)

### `lib/screens/post_item_screen.dart`

| Perubahan | Keterangan |
|---|---|
| `_validateForm()` | Kini memanggil `ItemValidator` — tidak ada lagi duplikasi logika |
| `_labeledTextField()` | Dihapus — digantikan `AppLabeledField` |
| `_textField()` | Dihapus — logika dipindah ke `AppTextField` |
| `_errorText()` | Dihapus — digantikan `AppErrorText` |
| Ukuran file | 961 baris → 796 baris (**berkurang 165 baris**) |

### Cakupan Test P9

| File Test | Jumlah Test | Jenis |
|---|---|---|
| `validators/item_validator_test.dart` | 15 | Unit |
| `utils/item_validator_utils_test.dart` | 6 | Unit |
| `widgets/form_field_widget_test.dart` | 10 | Widget |
