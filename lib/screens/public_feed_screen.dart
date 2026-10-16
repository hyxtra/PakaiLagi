import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/item.dart';
import '../models/item_model.dart';
import '../providers/cloud_item_provider.dart';
import '../services/firebase_auth_service.dart';
import '../theme/app_palette.dart';

// =============================================================================
// public_feed_screen.dart
// Halaman utama untuk melihat barang online dari Firestore (100% Cloud-only).
//
// FITUR:
//   - Login anonim otomatis saat pertama kali masuk
//   - Realtime stream dari Firestore (otomatis update tanpa pull-to-refresh)
//   - Loading state saat mengambil data
//   - Error state + tombol retry
//   - Empty state jika belum ada barang
//   - Gambar ditampilkan via Image.memory(base64Decode(...))
//
// ARSITEKTUR: UI → watch cloudItemsStreamProvider → rebuild realtime
// =============================================================================

class PublicFeedScreen extends ConsumerStatefulWidget {
  const PublicFeedScreen({super.key});

  @override
  ConsumerState<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends ConsumerState<PublicFeedScreen> {
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _ensureAnonymousAuth();
  }

  // ---------------------------------------------------------------------------
  // LOGIN ANONIM OTOMATIS
  // ---------------------------------------------------------------------------

  /// Memastikan user sudah login anonim sebelum mengakses Firestore.
  Future<void> _ensureAnonymousAuth() async {
    final authService = ref.read(firebaseAuthServiceProvider);
    if (authService.currentUser != null) return;

    setState(() => _isSigningIn = true);
    try {
      await authService.signInAnonymously();
    } catch (_) {
      // Error ditangani lewat UI
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(cloudItemsStreamProvider);
    final p = Theme.of(context).extension<AppPalette>()!;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Katalog Online'),
        centerTitle: true,
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: p.primary,
      ),
      body: _isSigningIn
          ? _buildAuthLoading(p)
          : feedState.when(
              loading: () => _buildLoading(p),
              error: (error, _) => _buildError(p, error.toString()),
              data: (items) {
                if (items.isEmpty) return _buildEmpty(p);
                return _buildFeed(p, items);
              },
            ),
    );
  }

  // ===========================================================================
  // AUTH LOADING
  // ===========================================================================

  Widget _buildAuthLoading(AppPalette p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: p.primary),
          const SizedBox(height: 16),
          Text(
            'Menghubungkan ke server...',
            style: TextStyle(color: p.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LOADING STATE
  // ===========================================================================

  Widget _buildLoading(AppPalette p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: p.primary),
          const SizedBox(height: 16),
          Text(
            'Memuat barang dari cloud...',
            style: TextStyle(color: p.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmpty(AppPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_queue_rounded, size: 72, color: p.textMuted),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Barang Online',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Barang yang dipublikasikan ke cloud\nakan muncul di sini secara realtime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: p.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildError(AppPalette p, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: p.danger),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: p.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(cloudItemsStreamProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Coba Lagi',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FEED LIST — Daftar barang dari Firestore (realtime)
  // ===========================================================================

  Widget _buildFeed(AppPalette p, List<ItemModel> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _CloudItemCard(item: item, palette: p);
      },
    );
  }
}

// =============================================================================
// WIDGET PRIVAT: _CloudItemCard — Satu item barang dari Firestore
// =============================================================================

class _CloudItemCard extends StatelessWidget {
  const _CloudItemCard({
    required this.item,
    required this.palette,
  });

  final ItemModel item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final title = item.title.isEmpty ? 'Tanpa Judul' : item.title;
    final category = item.category;
    final description = item.description;
    final imageBase64 = item.imageBase64;
    final status = item.status;
    final emoji = categoryEmoji(category);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gambar barang dari Base64 ──
          if (imageBase64.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 180,
              child: Image.memory(
                base64Decode(imageBase64),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: p.surfaceAlt,
                  height: 180,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: p.textMuted,
                      size: 40,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 120,
              color: p.surfaceAlt,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: p.textMuted,
                  size: 40,
                ),
              ),
            ),

          // ── Detail teks ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Judul + Status badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status == 'available'
                            ? p.primary.withValues(alpha: 0.15)
                            : p.textMuted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status == 'available'
                            ? 'TERSEDIA'
                            : status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              status == 'available' ? p.primary : p.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Chip kategori
                if (category.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$emoji $category',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // Deskripsi
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: p.textMuted,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
