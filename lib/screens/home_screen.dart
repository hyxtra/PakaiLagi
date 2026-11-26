import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../business/item_filters.dart';
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
const double kWideBreakpoint = 360;

/// Batas lebar untuk grid 3 kolom (dp).
const double kExtraWideBreakpoint = 900;

/// Jumlah kolom daftar barang di Beranda menurut lebar yang tersedia.
/// Layar sangat sempit memakai satu kolom, HP dua kolom, layar lebar tiga.
int homeColumnsForWidth(double maxWidth) {
  if (maxWidth < kWideBreakpoint) return 1;
  if (maxWidth < kExtraWideBreakpoint) return 2;
  return 3;
}

/// Apakah header Beranda disematkan di atas daftar (true) atau ikut menggulir
/// bersama daftar (false).
///
/// Header disematkan hanya bila setelah header masih tersisa ruang daftar
/// yang layak. Tinggi header diukur dari tampilan sebenarnya dan membesar
/// mengikuti ukuran font perangkat; konstanta di bawah adalah hasil ukur
/// (lihat laporan P10).
bool homeShouldPinHeader({
  required double availableHeight,
  required double textScale,
}) {
  final headerHeight = kHomeHeaderBaseHeight * (textScale < 1 ? 1 : textScale);
  return availableHeight >= headerHeight + kHomeMinListHeight;
}

/// Tinggi header Beranda pada font normal (dp). Terukur pada tes widget:
/// sekitar 260 dp (font 1x), 355 dp (1,3x), 437 dp (1,6x), 526 dp (2x). Model
/// linear 270 dp x skala font cukup dekat; selisih kecilnya ditutup oleh
/// [kHomeMinListHeight].
const double kHomeHeaderBaseHeight = 270;

/// Tinggi minimum area daftar agar header layak disematkan (dp).
const double kHomeMinListHeight = 150;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  String _cat = 'Semua';
  String _condition = 'Semua';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      pickupMethods: data.availablePickupMethods,
      address: '',
      condition: data.condition,
      listingType: data.listingType,
      price: data.price,
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
    final filtered = filterItems(
      items: cloudItems,
      query: _query,
      category: _cat,
      condition: _condition,
    ).map(_cloudMapToItem).toList(growable: false);
    final cats = ['Semua', ...kCategories.map((c) => c.name)];
    final chipHeight =
        MediaQuery.textScalerOf(context).scale(36).clamp(36.0, 80.0);
    final chipRowHeight = chipHeight < 48 ? 48.0 : chipHeight;

    // Header (sapaan, pencarian, chip kategori) dipisah dari isi supaya bisa
    // disematkan di atas daftar (layar cukup tinggi) atau ikut menggulir
    // (layar pendek: HP landscape, font besar).
    final header = Column(
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
                            padding: const EdgeInsets.symmetric(horizontal: 4),
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
            controller: _searchController,
            onChanged: (v) => setState(() {
              _query = v;
              if (v.trim().isEmpty) {
                _cat = 'Semua';
                _condition = 'Semua';
              }
            }),
            // Tombol keyboard "Cari" menutup keyboard agar hasil terlihat.
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            style: TextStyle(color: p.text),
            decoration: InputDecoration(
              hintText: 'Cari barang, mis. meja belajar…',
              hintStyle: TextStyle(color: p.textMuted),
              prefixIcon: Icon(Icons.search, color: p.textMuted, size: 18),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _cat = 'Semua';
                          _condition = 'Semua';
                        });
                      },
                      icon: Icon(Icons.close, color: p.textMuted, size: 18),
                    ),
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
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Kondisi barang',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.textMuted)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: chipRowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: ItemCondition.all.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final condition =
                  index == 0 ? 'Semua' : ItemCondition.all[index - 1];
              final active = condition == _condition;
              return AccessibleTap(
                onTap: () => setState(() => _condition = condition),
                label: 'Filter kondisi $condition',
                selected: active,
                radio: true,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  height: chipHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? p.primary : p.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: active ? p.primary : p.border),
                  ),
                  child: Text(condition,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? p.onPrimary : p.textMuted)),
                ),
              );
            },
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
      ],
    );

    // Isi di bawah header. [embedded] = true bila seluruh Beranda sedang
    // menggulir (mode layar pendek): isi tidak boleh punya scroll sendiri.
    Widget body({required bool embedded}) {
      if (cloudAsync.isLoading) {
        return _statusView(
          embedded,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  color: p.primary, semanticsLabel: 'Memuat daftar barang'),
              const SizedBox(height: 12),
              Text('Memuat barang…', style: TextStyle(color: p.textMuted)),
            ],
          ),
        );
      }
      if (cloudAsync.hasError) {
        return _statusView(
          embedded,
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
                  onPressed: () => ref.invalidate(cloudItemsStreamProvider),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        );
      }
      if (filtered.isEmpty) {
        return _statusView(
          embedded,
          Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExcludeSemantics(
                  child: Text('📦', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 12),
                Text('Belum ada barang yang cocok.',
                    style: TextStyle(color: p.textMuted, fontSize: 14)),
              ],
            ),
          ),
        );
      }
      return _buildItemList(filtered, p, embedded: embedded);
    }

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pinned = homeShouldPinHeader(
            availableHeight: constraints.maxHeight,
            textScale: MediaQuery.textScalerOf(context).scale(1),
          );
          if (pinned) {
            // Tampilan HP biasa: header tetap di atas, hanya daftar yang
            // menggulir (perilaku semula).
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Expanded(child: body(embedded: false)),
              ],
            );
          }
          // Layar terlalu pendek untuk header + daftar sekaligus: seluruh
          // Beranda menggulir, sehingga tidak ada overflow dan daftar tetap
          // bisa dijangkau.
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                body(embedded: true),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Tampilan Memuat / Error / Kosong. Pada mode pinned dipusatkan dan bisa
  /// di-scroll bila ruang lebih pendek dari isinya; pada mode embedded
  /// (Beranda sudah menggulir) cukup diberi jarak.
  Widget _statusView(bool embedded, Widget child) {
    if (!embedded) return _centeredScrollable(child);
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(child: child),
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
  ///
  /// [embedded] = true bila seluruh Beranda sudah menggulir (mode layar
  /// pendek): daftar ditampilkan setinggi isinya dan tidak menggulir sendiri.
  Widget _buildItemList(List<Item> items, AppPalette p,
      {required bool embedded}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = homeColumnsForWidth(constraints.maxWidth);
        // Men-scroll daftar menutup keyboard pencarian.
        const dismiss = ScrollViewKeyboardDismissBehavior.onDrag;

        if (columns == 1) {
          return ListView.builder(
            keyboardDismissBehavior: dismiss,
            shrinkWrap: embedded,
            physics: embedded ? const NeverScrollableScrollPhysics() : null,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildItemCard(items[i]),
          );
        }

        // Kartu foto-first memerlukan tinggi berdasarkan lebar aktual sel;
        // ruang teks ikut membesar sesuai skala font agar grid tidak overflow.
        final cellWidth = (constraints.maxWidth - (columns - 1) * 16) / columns;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final cellHeight =
            (cellWidth * 0.75 + 150 * textScale).clamp(250.0, 900.0);
        return GridView.builder(
          keyboardDismissBehavior: dismiss,
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            // Kartu sudah punya jarak bawah 14 dp sendiri.
            mainAxisSpacing: 0,
            mainAxisExtent: cellHeight,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _buildItemCard(items[i]),
        );
      },
    );
  }

  /// Kartu feed yang dipakai untuk barang cloud maupun lokal.
  Widget _buildItemCard(Item item) {
    return ItemCard(
      item: item,
      onTap: () => context.push(AppRoutes.itemDetail(item.id)),
    );
  }
}
