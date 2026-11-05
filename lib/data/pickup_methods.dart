/// Metode pengambilan PakaiLagi. Satu-satunya sumber daftar metode: dipakai
/// oleh form Posting (pemberi) dan form pengajuan (peminta).
///
/// Setiap entri: (nama, emoji, penjelasan singkat).
const kPickupMethods = <(String, String, String)>[
  (
    'Antar ke Alamat',
    '🚚',
    'Barang diantar ke alamat penerima, ongkir sesuai kesepakatan.'
  ),
  ('Bertemu (COD)', '🤝', 'Janjian bertemu di titik yang disepakati bersama.'),
];

/// Nama-nama metode saja, dalam urutan yang sama dengan [kPickupMethods].
final kPickupMethodNames =
    List<String>.unmodifiable(kPickupMethods.map((m) => m.$1));
