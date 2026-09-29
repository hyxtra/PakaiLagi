import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/item.dart';
import '../models/pickup_request.dart';

/// Beberapa user mock berbeda supaya alur pemberi vs peminta terlihat
/// sebagai orang yang berbeda (bukan satu nama hardcode).
const mockUsers = <AppUser>[
  AppUser(
    id: 'u1',
    name: 'Rani Kusuma',
    email: 'rani@pakailagi.id',
    phone: '0812-3345-9087',
    address: 'Jl. Melati No. 27, Cimanggis, Depok, Jawa Barat 16451',
  ),
  AppUser(
    id: 'u2',
    name: 'Budi Hartono',
    email: 'budi@pakailagi.id',
    phone: '0857-1120-4432',
    address: 'Jl. Kenanga No. 10, Beji, Depok, Jawa Barat 16421',
  ),
  AppUser(
    id: 'u3',
    name: 'Siti Marlina',
    email: 'siti@pakailagi.id',
    phone: '0819-8876-2210',
    address: 'Jl. Anggrek No. 5, Sawangan, Depok, Jawa Barat 16511',
  ),
];

AppUser? findMockUserByEmail(String email) {
  final e = email.trim().toLowerCase();
  for (final u in mockUsers) {
    if (u.email.toLowerCase() == e) return u;
  }
  return null;
}

final seedItems = <Item>[
  const Item(
    id: '1',
    title: 'Meja Belajar Kayu Jati Belanda',
    category: 'Furniture',
    description:
        'Meja belajar kayu solid ukuran 80x50 cm. Ada sedikit goresan di sudut, tapi masih kokoh dan nyaman dipakai.',
    ownerId: 'u2',
    ownerName: 'Budi Hartono',
    ownerPhone: '0857-1120-4432',
    status: ItemStatus.available,
    swatch: Color(0xFFCBA976),
    pickupMethods: ['Ambil Langsung', 'Bertemu'],
    address: 'Jl. Kenanga No. 10, Beji, Depok',
    imageUrl: 'https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd?w=400',
  ),
  const Item(
    id: '2',
    title: 'Kursi Kayu Lipat (2 pcs)',
    category: 'Furniture',
    description:
        'Dua kursi kayu lipat, cocok untuk teras atau ruang tamu tambahan. Masih kuat dan engsel lancar.',
    ownerId: 'u2',
    ownerName: 'Budi Hartono',
    ownerPhone: '0857-1120-4432',
    status: ItemStatus.available,
    swatch: Color(0xFF8FB59B),
    pickupMethods: ['Ambil Langsung', 'Kurir'],
    address: 'Jl. Kenanga No. 10, Beji, Depok',
    imageUrl: 'https://images.unsplash.com/photo-1503602642458-232111445657?w=400',
  ),
  const Item(
    id: '3',
    title: 'Buku Pelajaran SMA Kelas 11 (1 set)',
    category: 'Perlengkapan Sekolah',
    description:
        'Satu set buku pelajaran Kelas 11 kurikulum terbaru. Kondisi rapi, sampul masih bagus, catatan minim.',
    ownerId: 'u1',
    ownerName: 'Rani Kusuma',
    ownerPhone: '0812-3345-9087',
    status: ItemStatus.available,
    swatch: Color(0xFF6E86A8),
    pickupMethods: ['Ambil Langsung', 'Bertemu', 'Kurir'],
    address: 'Jl. Melati No. 27, Cimanggis, Depok',
    imageUrl: 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=400',
  ),
  const Item(
    id: '4',
    title: 'Kipas Angin Berdiri 16 inci',
    category: 'Elektronik',
    description:
        'Kipas angin berdiri masih berfungsi normal, 3 kecepatan. Kabel aman. Gratis untuk yang mau ambil sendiri.',
    ownerId: 'u3',
    ownerName: 'Siti Marlina',
    ownerPhone: '0819-8876-2210',
    status: ItemStatus.available,
    swatch: Color(0xFF9AA9B4),
    pickupMethods: ['Ambil Langsung'],
    address: 'Jl. Anggrek No. 5, Sawangan, Depok',
    imageUrl: 'https://images.unsplash.com/photo-1617952739858-28043cec91fd?w=400',
  ),
  const Item(
    id: '5',
    title: 'Boks Bayi Kayu + Kasur',
    category: 'Perlengkapan Bayi & Anak',
    description:
        'Boks bayi lengkap dengan kasur tipis. Cat masih mulus, roda berfungsi. Diberikan gratis, semoga bermanfaat.',
    ownerId: 'u1',
    ownerName: 'Rani Kusuma',
    ownerPhone: '0812-3345-9087',
    status: ItemStatus.completed,
    swatch: Color(0xFFD8B0A0),
    pickupMethods: ['Bertemu', 'Kurir'],
    address: 'Jl. Melati No. 27, Cimanggis, Depok',
    imageUrl: 'https://images.unsplash.com/photo-1586105449897-20b5efeb3233?w=400',
  ),
  const Item(
    id: '6',
    title: 'Panci Set Stainless (3 pcs)',
    category: 'Peralatan Rumah Tangga',
    description:
        'Set panci stainless isi 3 ukuran. Masih layak pakai, tidak penyok. Bersih dan siap digunakan.',
    ownerId: 'u3',
    ownerName: 'Siti Marlina',
    ownerPhone: '0819-8876-2210',
    status: ItemStatus.available,
    swatch: Color(0xFFB6C2AC),
    pickupMethods: ['Ambil Langsung', 'Bertemu'],
    address: 'Jl. Anggrek No. 5, Sawangan, Depok',
    imageUrl: 'https://images.unsplash.com/photo-1584990347449-a6d4ec89e3a7?w=400',
  ),
];

/// Pengajuan mock. Difokuskan pada barang milik Rani (u1) supaya saat login
/// sebagai Rani, alur "Kelola Pengajuan" langsung ada isinya.
final seedRequests = <PickupRequest>[
  const PickupRequest(
    id: 'r1',
    itemId: '3',
    requesterId: 'u4',
    requesterName: 'Andi Saputra',
    method: 'Ambil Langsung',
    message: 'Halo, saya berminat. Bisa saya ambil akhir pekan ini?',
    time: '2 jam lalu',
  ),
  const PickupRequest(
    id: 'r2',
    itemId: '3',
    requesterId: 'u5',
    requesterName: 'Maya Lestari',
    method: 'Bertemu',
    message: 'Boleh ketemuan di stasiun dekat rumah? Terima kasih.',
    time: '5 jam lalu',
  ),
  const PickupRequest(
    id: 'r3',
    itemId: '3',
    requesterId: 'u6',
    requesterName: 'Fikri Ramadhan',
    method: 'Kurir',
    message: 'Saya kirim kurir saja ya, ongkir saya yang tanggung.',
    time: 'kemarin',
  ),
];

const kPickupMethodInfo = <(String, String, String)>[
  ('🏪', 'Ambil Langsung', 'Penerima datang ke lokasi pemberi.'),
  ('🤝', 'Bertemu', 'Janjian bertemu di titik yang disepakati.'),
  ('🚚', 'Kurir', 'Kirim lewat kurir, ongkir sesuai kesepakatan.'),
];
