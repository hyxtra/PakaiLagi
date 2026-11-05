import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/pickup_methods.dart';
import '../models/item.dart';
import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cloud_item_provider.dart';
import '../providers/notification_provider.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../widgets/accessible_tap.dart';
import '../widgets/item_card.dart';

/// Batas lebar layar kecil/besar (dp). Di bawah ini: daftar 1 kolom (HP
/// portrait). Di atas ini: grid (tablet, HP landscape, browser lebar).
const double kWideBreakpoint = 600;

/// Batas lebar untuk grid 3 kolom (dp).
const double kExtraWideBreakpoint = 900;

/// Jumlah kolom daftar barang di Beranda menurut lebar yang tersedia.
/// 1 = daftar vertikal (ListView), 2–3 = grid (GridView).
int homeColumnsForWidth(double maxWidth) {
  if (maxWidth < kWideBreakpoint) return 1;
  if (maxWidth < kExtraWideBreakpoint) return 2;
  return 3;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  String _cat = 'Semua';

  /// Konversi data Firestore Map → Item model agar bisa pakai ItemCard.
  Item _cloudMapToItem(ItemModel data) {
    return Item(
      id: data.id,
      title: data.title,
      category: data.category,
      description: data.description,
      ownerId: data.donorId,
      ownerName: data.ownerName,
      ownerPhone: '',
      status: ItemStatus.available,
      swatch: const Color(0xFF2F6B4F),
      pickupMethods: kPickupMethodNames,
      address: '',
      // Simpan Base64 string sebagai imageUrl, akan di-handle khusus
      imageUrl:
          data.imageBase64.isNotEmpty ? 'base64:${data.imageBase64}' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = ref.watch(authProvider);
    final unreadNotifications =
        ref.watch(unreadCloudNotificationsCountProvider);

    final cloudAsync = ref.watch(cloudItemsStreamProvider);
    final cloudItems = cloudAsync.valueOrNull ?? const <ItemModel>[];
    final filtered = cloudItems.map(_cloudMapToItem).where((item) {
      if (item.status != ItemStatus.available) return false;
      final matchQuery =
          item.title.toLowerCase().contains(_query.toLowerCase());
      return matchQuery && (_cat == 'Semua' || item.category == _cat);
    }).toList();
    final cats = ['Semua', ...kCategories.map((c) => c.name)];
    final chipHeight =
        MediaQuery.textScalerOf(context).scale(36).clamp(36.0, 80.0);
    final chipRowHeight = chipHeight < 48 ? 48.0 : chipHeight;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Halo, ${user?.firstName ?? 'Teman'} 👋',
                          style: TextStyle(fontSize: 13.5, color: p.textMuted)),
                      const SizedBox(height: 2),
                      Text('Barang siap diberi hidup kedua',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: p.text,
                              height: 1.25)),
                    ],
                  ),
                ),
                AccessibleTap(
                  onTap: () => context.push(AppRoutes.notifications),
                  label: unreadNotifications > 0
                      ? 'Notifikasi, $unreadNotifications belum dibaca'
                      : 'Notifikasi',
                  tooltip: 'Notifikasi',
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: p.surfaceAlt,
                              borderRadius: BorderRadius.circular(14)),
                          child: Icon(Icons.notifications_none,
                              size: 20, color: p.primary),
                        ),
                        if (unreadNotifications > 0)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 16),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.center,
                              height: 16,
                              decoration: BoxDecoration(
                                color: p.danger,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadNotifications > 9
                                    ? '9+'
                                    : '$unreadNotifications',
                                style: TextStyle(
                                    color: p.onDanger,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              // Tombol keyboard "Cari" menutup keyboard agar hasil terlihat.
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: TextStyle(color: p.text),
              decoration: InputDecoration(
                hintText: 'Cari barang, mis. meja belajar…',
                hintStyle: TextStyle(color: p.textMuted),
                prefixIcon: Icon(Icons.search, color: p.textMuted, size: 18),
                filled: true,
                fillColor: p.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Category chips. Tinggi chip ikut membesar bila ukuran font HP
          // diperbesar, dan area sentuh minimal 48 dp.
          SizedBox(
            height: chipRowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final active = cats[i] == _cat;
                return AccessibleTap(
                  onTap: () => setState(() => _cat = cats[i]),
                  label: 'Filter kategori ${cats[i]}',
                  selected: active,
                  radio: true,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    height: chipHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? p.primary : p.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: active ? p.primary : p.border),
                    ),
                    child: Text(
                      cats[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? p.onPrimary : p.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            // Tiga tampilan status memakai _centeredScrollable: di layar
            // pendek (HP landscape, font besar) isinya bisa di-scroll dan
            // tidak melimpah ke bawah.
            child: cloudAsync.isLoading
                ? _centeredScrollable(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                            color: p.primary,
                            semanticsLabel: 'Memuat daftar barang'),
                        const SizedBox(height: 12),
                        Text('Memuat barang…',
                            style: TextStyle(color: p.textMuted)),
                      ],
                    ),
                  )
                : cloudAsync.hasError
                    ? _centeredScrollable(
                        Semantics(
                          liveRegion: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Gagal memuat barang. Periksa koneksi kamu.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: p.textMuted)),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () =>
                                    ref.invalidate(cloudItemsStreamProvider),
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? _centeredScrollable(
                            Semantics(
                              liveRegion: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const ExcludeSemantics(
                                    child: Text('📦',
                                        style: TextStyle(fontSize: 48)),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Belum ada barang yang cocok.',
                                      style: TextStyle(
                                          color: p.textMuted, fontSize: 14)),
                                ],
                              ),
                            ),
                          )
                        : _buildItemList(filtered, p),
          ),
        ],
      ),
    );
  }

  /// Memusatkan [child] di area daftar, tetapi tetap bisa di-scroll bila
  /// ruangnya lebih pendek dari isinya.
  Widget _centeredScrollable(Widget child) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: child,
      ),
    );
  }

  /// Daftar barang yang menyesuaikan lebar layar lewat [LayoutBuilder]:
  /// - maxWidth < 600  → ListView (1 kolom)
  /// - 600–899         → GridView 2 kolom
  /// - ≥ 900           → GridView 3 kolom
  Widget _buildItemList(List<Item> items, AppPalette p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = homeColumnsForWidth(constraints.maxWidth);
        // Men-scroll daftar menutup keyboard pencarian.
        const dismiss = ScrollViewKeyboardDismissBehavior.onDrag;

        if (columns == 1) {
          return ListView.builder(
            keyboardDismissBehavior: dismiss,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildItemCard(items[i], p),
          );
        }

        // Tinggi sel grid tetap (kartu berisi foto 92 dp + teks) dan ikut
        // membesar bila ukuran font HP diperbesar, agar teks tidak terpotong.
        final cellHeight =
            MediaQuery.textScalerOf(context).scale(138).clamp(138.0, 320.0);
        return GridView.builder(
          keyboardDismissBehavior: dismiss,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            // Kartu sudah punya jarak bawah 14 dp sendiri.
            mainAxisSpacing: 0,
            mainAxisExtent: cellHeight,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _buildItemCard(items[i], p),
        );
      },
    );
  }

  /// Build card yang bisa menampilkan foto Base64 dari cloud
  /// atau foto biasa dari data lokal.
  Widget _buildItemCard(Item item, AppPalette p) {
    // Jika imageUrl dimulai "base64:", render Image.memory
    final isBase64 =
        item.imageUrl != null && item.imageUrl!.startsWith('base64:');

    if (isBase64) {
      final b64 = item.imageUrl!.substring(7); // hapus prefix "base64:"
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AccessibleTap(
          onTap: () => context.push(AppRoutes.itemDetail(item.id)),
          label: ItemCard.semanticLabel(item),
          borderRadius: BorderRadius.circular(18),
          minSize: 0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    child: Image.memory(
                      base64Decode(b64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF2F6B4F),
                        alignment: Alignment.center,
                        child: Text(categoryEmoji(item.category),
                            style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Expanded + Align: badge status tetap di kanan, dan
                          // nama kategori panjang/font besar tidak overflow.
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: p.primarySoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${categoryEmoji(item.category)} ${item.category}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: p.primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: p.statusAvailable.withValues(alpha: 0.12),
                            ),
                            child: Text(
                              '◎ TERSEDIA',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: p.statusAvailable),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: p.text),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 13, color: p.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.ownerName,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(fontSize: 12.5, color: p.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Item lokal — pakai ItemCard biasa
    return ItemCard(
      item: item,
      onTap: () => context.push(AppRoutes.itemDetail(item.id)),
    );
  }
}
