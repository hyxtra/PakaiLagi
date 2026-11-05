import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/pickup_methods.dart';
import '../business/item_ownership.dart';
import '../models/item.dart';
import '../providers/auth_provider.dart';
import '../providers/cloud_item_provider.dart';
import '../providers/items_provider.dart';
import '../providers/requests_provider.dart';
import '../repositories/firebase_repository.dart';
import '../services/firebase_auth_service.dart';
import '../services/location_service.dart';
import '../services/user_messages.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../widgets/accessible_tap.dart';
import '../widgets/badges.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/pin_preview_map.dart';
import '../widgets/progress_dialog.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localItem = ref.watch(itemByIdProvider(itemId));
    if (localItem != null) return _detailScaffold(context, ref, localItem);

    // Barang cloud tidak ada pada provider mock. Ambil langsung memakai
    // Firestore document ID yang diterima route.
    final cloudItem = ref.watch(cloudItemByIdProvider(itemId));
    return cloudItem.when(
      loading: () => Scaffold(
        backgroundColor: context.palette.bg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _notFoundScaffold(context),
      data: (data) {
        if (data == null) return _notFoundScaffold(context);
        return _detailScaffold(
            context,
            ref,
            Item(
              id: data.id,
              title: data.title,
              category: data.category,
              description: data.description,
              ownerId: data.donorId,
              ownerName: data.ownerName,
              ownerPhone: '',
              status: data.status == 'completed'
                  ? ItemStatus.completed
                  : data.status == 'reserved'
                      ? ItemStatus.reserved
                      : ItemStatus.available,
              swatch: const Color(0xFF2F6B4F),
              pickupMethods: kPickupMethodNames,
              address: data.areaLabel,
              imageUrl:
                  data.imageBytes == null ? null : 'base64:${data.imageBase64}',
            ),
            isCloudItem: true);
      },
    );
  }

  Scaffold _notFoundScaffold(BuildContext context) => Scaffold(
        backgroundColor: context.palette.bg,
        appBar: AppBar(),
        body: const Center(child: Text('Detail barang tidak dapat dimuat')),
      );

  Widget _detailScaffold(BuildContext context, WidgetRef ref, Item item,
      {bool isCloudItem = false}) {
    final p = context.palette;
    final user = ref.watch(authProvider);
    final firebaseUid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid;

    final ownedByMe = user != null && item.ownerId == user.id;
    final canDeleteCloudItem = isCloudItem &&
        ItemOwnership.canModify(
          donorId: item.ownerId,
          currentUserId: firebaseUid,
        );
    // Barang cloud dimiliki UID Firebase, barang lokal dimiliki ID mock.
    final isOwner = ownedByMe || canDeleteCloudItem;
    final available = item.status == ItemStatus.available;

    // Status pengajuan saya untuk barang ini, agar tombol tidak lagi
    // menawarkan "Ajukan" setelah pengajuan terkirim.
    final myRequest = isCloudItem && !isOwner
        ? ref.watch(myCloudRequestForItemProvider(item.id)).valueOrNull
        : null;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    PhotoPlaceholder(
                        item: item, height: 280, radius: 0, large: true),
                    Positioned(
                      // Area sentuh 48 dp; lingkaran tampilan tetap 40 dp,
                      // jadi posisi visualnya sama seperti sebelumnya.
                      top: 12,
                      left: 12,
                      child: SafeArea(
                        child: _circleButton(
                          Icons.arrow_back,
                          const Color(0xFF1E2621),
                          Colors.white.withValues(alpha: 0.92),
                          () => context.pop(),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CategoryBadge(category: item.category),
                        const SizedBox(width: 8),
                        StatusBadge(status: item.status),
                      ]),
                      const SizedBox(height: 14),
                      Semantics(
                        header: true,
                        child: Text(item.title,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                color: p.text)),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        header: true,
                        child: Text('Deskripsi',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: p.text)),
                      ),
                      const SizedBox(height: 6),
                      Text(item.description,
                          style: TextStyle(
                              fontSize: 14.5,
                              height: 1.55,
                              color: p.textMuted)),
                      if (isCloudItem) ...[
                        const SizedBox(height: 22),
                        _PickupLocationSection(
                          itemId: item.id,
                          areaLabel: item.address,
                          isOwner: canDeleteCloudItem,
                        ),
                      ],
                      const SizedBox(height: 22),
                      Semantics(
                        header: true,
                        child: Text('Pemberi Barang',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: p.text)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 23,
                              backgroundColor: p.surfaceAlt,
                              child: const ExcludeSemantics(
                                child:
                                    Text('👤', style: TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.ownerName,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: p.text)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Icon(Icons.phone,
                                        size: 12, color: p.textMuted),
                                    const SizedBox(width: 4),
                                    // Sebelumnya teks kosong (nomor HP belum
                                    // disimpan di data barang).
                                    Expanded(
                                      child: Text(
                                          item.ownerPhone.isNotEmpty
                                              ? item.ownerPhone
                                              : 'Nomor HP tidak dicantumkan',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: p.textMuted)),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                            Icon(Icons.verified,
                                size: 20,
                                color: p.primary,
                                semanticLabel: 'Pemberi terverifikasi'),
                          ],
                        ),
                      ),
                      // Chat hanya untuk calon penerima, bukan pemilik barang.
                      if (!isOwner) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () => context
                                .push(AppRoutes.chat(item.id, item.ownerName)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.primary,
                              side: BorderSide(color: p.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon:
                                const Icon(Icons.chat_bubble_outline, size: 19),
                            label: const Text('Chat Pemberi',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canDeleteCloudItem)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDelete(context, ref, item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.danger,
                      foregroundColor: p.onDanger,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus Barang',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            )
          else if (!isOwner)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: _requestButton(context, ref, p, item,
                    available: available,
                    isCloudItem: isCloudItem,
                    myRequestStatus: myRequest?.status),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Item item) async {
    final p = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Barang'),
        content: Text(
            'Hapus "${item.title}"? Barang dan pengajuan yang menunggu tidak '
            'bisa dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: p.danger),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = AppMessenger.of(context);
    try {
      final outcome = await runWithProgress(
        context,
        message: 'Menghapus barang…',
        task: () => awaitWrite(
            ref.read(firebaseRepositoryProvider).deleteItem(item.id)),
      );
      messenger.result(outcome,
          done: 'Barang berhasil dihapus.',
          queued: 'Barang dihapus dari perangkat. $queuedSuffix');
      if (context.mounted) context.pop();
    } catch (error) {
      showAppSnackBar(messenger,
          friendlyError(error, fallback: 'Gagal menghapus barang. Coba lagi.'),
          isError: true);
    }
  }

  /// Tombol bulat di atas foto. Lingkaran tampilan 40 dp, area sentuh 48 dp.
  Widget _circleButton(IconData icon, Color fg, Color bg, VoidCallback onTap) {
    return AccessibleTap(
      onTap: onTap,
      label: 'Kembali',
      tooltip: 'Kembali',
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: fg),
      ),
    );
  }

  /// Tombol utama calon penerima. Teksnya mencerminkan status pengajuan
  /// sehingga pengguna tahu langkah berikutnya tanpa menebak.
  Widget _requestButton(
    BuildContext context,
    WidgetRef ref,
    AppPalette p,
    Item item, {
    required bool available,
    required bool isCloudItem,
    required String? myRequestStatus,
  }) {
    final (String label, IconData icon, bool enabled) =
        switch (myRequestStatus) {
      'pending' => (
          'Menunggu Persetujuan Pemberi',
          Icons.hourglass_top_rounded,
          false
        ),
      'accepted' => ('Pengajuan Diterima', Icons.check_circle_outline, false),
      'rejected' => ('Pengajuan Ditolak', Icons.info_outline, false),
      _ => available
          ? ('Ajukan Pengambilan', Icons.card_giftcard, true)
          : ('Barang Tidak Tersedia', Icons.block, false),
    };

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled
            ? () =>
                _openRequestSheet(context, ref, item, isCloudItem: isCloudItem)
            : null,
        style: ElevatedButton.styleFrom(
          // Tinggi minimum 54 (sama seperti sebelumnya) tetapi boleh
          // bertambah bila ukuran font HP diperbesar.
          minimumSize: const Size.fromHeight(54),
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          // Abu-abu + teks gelap: kontras 5,98:1 (putih hanya 2,59:1).
          disabledBackgroundColor: const Color(0xFF9AA39C),
          disabledForegroundColor: const Color(0xFF1E2621),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _openRequestSheet(BuildContext context, WidgetRef ref, Item item,
      {bool isCloudItem = false}) {
    final p = context.palette;
    final methods =
        item.pickupMethods.isNotEmpty ? item.pickupMethods : kPickupMethodNames;
    var selected = 0;
    var sending = false;
    // Diambil sebelum await: SnackBar tetap tampil walaupun sheet sudah
    // ditutup pengguna saat proses berjalan.
    final messenger = AppMessenger.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      // Sheet boleh lebih tinggi dan bisa di-scroll bila font diperbesar.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> submit() async {
              setSheet(() => sending = true);
              try {
                if (isCloudItem) {
                  final outcome = await awaitWrite(
                    ref.read(firebaseRepositoryProvider).createPickupRequest(
                          itemId: item.id,
                          method: methods[selected],
                        ),
                    timeout: const Duration(seconds: 12),
                  );
                  messenger.result(outcome,
                      done: 'Pengajuan terkirim via "${methods[selected]}" 🎉 '
                          'Tunggu persetujuan pemberi.',
                      queued: 'Pengajuan via "${methods[selected]}". '
                          '$queuedSuffix');
                } else {
                  final user = ref.read(authProvider);
                  if (user != null) {
                    ref.read(requestsProvider.notifier).addRequest(
                          itemId: item.id,
                          requesterId: user.id,
                          requesterName: user.name,
                          method: methods[selected],
                          message: 'Halo, saya berminat dengan barang ini.',
                        );
                  }
                  messenger.success(
                      'Pengajuan terkirim via "${methods[selected]}" 🎉');
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (error) {
                // Sheet tetap terbuka agar pengguna bisa langsung mencoba lagi.
                if (ctx.mounted) setSheet(() => sending = false);
                showAppSnackBar(
                    messenger,
                    friendlyError(error,
                        fallback: 'Gagal mengirim pengajuan. Coba lagi.'),
                    isError: true);
              }
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                            color: p.border,
                            borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: Text('Metode Pengambilan',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: p.text)),
                    ),
                    const SizedBox(height: 4),
                    Text('Pilih cara kamu ingin menerima barang ini.',
                        style: TextStyle(fontSize: 14, color: p.textMuted)),
                    const SizedBox(height: 18),
                    for (var i = 0; i < methods.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AccessibleTap(
                          onTap: sending
                              ? null
                              : () => setSheet(() => selected = i),
                          label: 'Metode ${methods[i]}',
                          selected: selected == i,
                          radio: true,
                          borderRadius: BorderRadius.circular(14),
                          minSize: 0,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected == i ? p.surfaceAlt : p.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: selected == i ? p.primary : p.border,
                                  width: selected == i ? 1.6 : 1),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(methods[i],
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: p.text)),
                                ),
                                Icon(
                                  selected == i
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selected == i ? p.primary : p.border,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        // Nonaktif selama mengirim: mencegah pengajuan ganda.
                        onPressed: sending ? null : submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: p.accent,
                          foregroundColor: p.onAccent,
                          disabledBackgroundColor:
                              p.accent.withValues(alpha: 0.6),
                          disabledForegroundColor: p.onAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: sending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4, color: p.onAccent),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Mengirim pengajuan…',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                ],
                              )
                            : const Text('Konfirmasi Pengajuan',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Lokasi pengambilan dengan aturan privasi:
/// - semua pengguna: kelurahan & kota
/// - pemilik & peminta yang pengajuannya diterima: alamat lengkap
class _PickupLocationSection extends ConsumerWidget {
  const _PickupLocationSection({
    required this.itemId,
    required this.areaLabel,
    required this.isOwner,
  });

  final String itemId;
  final String areaLabel;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final myRequest = isOwner
        ? null
        : ref.watch(myCloudRequestForItemProvider(itemId)).valueOrNull;
    final accepted = myRequest?.status == 'accepted';
    final canSeeFull = isOwner || accepted;

    // Dokumen privat hanya di-watch bila rules mengizinkan; selain itu
    // listener akan langsung ditolak (permission-denied).
    final fullAddress = canSeeFull
        ? ref.watch(cloudItemPrivateLocationProvider(itemId)).valueOrNull
        : null;

    final String note;
    if (isOwner) {
      note = 'Alamat lengkap dan titik peta hanya terlihat oleh kamu dan '
          'peminta yang pengajuannya kamu terima.';
    } else if (accepted) {
      note = 'Pengajuanmu diterima, alamat lengkap dan titik peta dibagikan '
          'kepadamu.';
    } else {
      note = 'Titik penjemputan persis dibagikan setelah pengajuanmu '
          'diterima pemberi. Tombol di bawah membuka area kelurahan saja.';
    }

    // Tujuan Google Maps sesuai hak akses: titik GPS persis → alamat lengkap
    // → area kelurahan & kota (publik).
    final lat = fullAddress?.latitude;
    final lng = fullAddress?.longitude;
    final hasPin = lat != null && lng != null;
    final fullText = fullAddress?.address.trim() ?? '';
    final mapsQuery = fullText.isNotEmpty ? fullText : areaLabel.trim();
    final canOpenMaps = hasPin || mapsQuery.isNotEmpty;

    Future<void> openMaps() async {
      final opened = await LocationService.openInGoogleMaps(
        latitude: hasPin ? lat : null,
        longitude: hasPin ? lng : null,
        query: mapsQuery,
      );
      if (!opened && context.mounted) {
        AppMessenger.of(context)
            .error('Tidak ada aplikasi untuk membuka Google Maps.');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Lokasi Pengambilan',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: p.text)),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined, size: 18, color: p.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fullAddress != null && fullAddress.address.isNotEmpty
                    ? fullAddress.address
                    : areaLabel.isNotEmpty
                        ? areaLabel
                        : 'Lokasi belum diatur',
                style: TextStyle(fontSize: 14.5, height: 1.45, color: p.text),
              ),
            ),
          ],
        ),
        if (hasPin) ...[
          const SizedBox(height: 10),
          PinPreviewMap(
            latitude: lat,
            longitude: lng,
            onTap: openMaps,
            semanticLabel:
                'Peta titik penjemputan. Ketuk dua kali untuk membuka Google Maps',
          ),
        ],
        const SizedBox(height: 6),
        Text(note, style: TextStyle(fontSize: 12.5, color: p.textMuted)),
        if (canOpenMaps) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            // 48 dp: ukuran minimal area sentuh (sebelumnya 46).
            height: 48,
            child: OutlinedButton.icon(
              onPressed: openMaps,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.primary,
                side: BorderSide(color: p.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.map_outlined, size: 19),
              label: Text(
                hasPin
                    ? 'Buka Titik di Google Maps'
                    : 'Lihat Area di Google Maps',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
