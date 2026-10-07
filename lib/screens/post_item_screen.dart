import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../notifiers/item_notifier.dart';
import '../notifiers/item_state.dart';
import '../providers/auth_provider.dart';
import '../theme/app_palette.dart';

// =============================================================================
// FILE 5: post_item_screen.dart
// UI form lengkap dengan penanganan 6 kondisi state:
//   1. Initial loading (spinner)
//   2. Data berhasil dimuat (form)
//   3. Empty state (tidak ada kategori)
//   4. Error state + tombol retry
//   5. Validasi input form (pesan merah)
//   6. Loading saat submit (tombol disabled + spinner)
//
// Fitur yang ada (sesuai repo asli):
//   - Upload / preview foto (image_picker)
//   - Toggle alamat: pakai alamat profil atau isi manual
//   - Multi-select metode pengambilan
//
// Widget ini HANYA bertanggung jawab menampilkan UI.
// Semua logika bisnis ada di PostItemNotifier.
// =============================================================================

/// Daftar metode pengambilan yang tersedia.
const _kPickupMethods = [
  ('Ambil Sendiri', '🚶'),
  ('Antar ke Alamat', '🚚'),
  ('Bertemu (COD)', '🤝'),
];

class PostItemScreen extends ConsumerStatefulWidget {
  const PostItemScreen({super.key});

  @override
  ConsumerState<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends ConsumerState<PostItemScreen> {
  // ── Controller & state form ──
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _otherAddrCtrl = TextEditingController();

  String? _selectedCategory;
  final Set<String> _selectedMethods = {}; // multi-select
  bool _useProfileAddress = true; // toggle alamat
  String? _pickedImagePath; // path foto yang dipilih

  // ── KONDISI 5: Map error validasi per-field ──
  final Map<String, String> _validationErrors = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _otherAddrCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // IMAGE PICKER
  // ---------------------------------------------------------------------------

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await ImagePicker().pickImage(source: source, maxWidth: 1200);
    if (picked != null) {
      setState(() => _pickedImagePath = picked.path);
    }
  }

  // ---------------------------------------------------------------------------
  // VALIDASI INPUT (Kondisi 5)
  // ---------------------------------------------------------------------------

  /// Validasi semua field. Return true jika valid, false jika ada error.
  bool _validateForm() {
    final errors = <String, String>{};

    if (_titleCtrl.text.trim().isEmpty) {
      errors['title'] = 'Judul wajib diisi';
    }
    if (_selectedCategory == null) {
      errors['category'] = 'Pilih kategori barang dulu ya';
    }
    if (_descCtrl.text.trim().isEmpty) {
      errors['desc'] = 'Deskripsi wajib diisi';
    }
    if (_selectedMethods.isEmpty) {
      errors['methods'] = 'Pilih minimal satu metode pengambilan';
    }
    if (!_useProfileAddress && _otherAddrCtrl.text.trim().isEmpty) {
      errors['addr'] = 'Isi alamat lain atau pakai alamat profil';
    }

    setState(() {
      _validationErrors
        ..clear()
        ..addAll(errors);
    });

    return errors.isEmpty;
  }

  // ---------------------------------------------------------------------------
  // SUBMIT HANDLER
  // ---------------------------------------------------------------------------

  Future<void> _handleSubmit() async {
    // ── KONDISI 5: Cek validasi dulu ──
    if (!_validateForm()) return;

    final user = ref.read(authProvider);
    if (user == null) return;

    final address =
        _useProfileAddress ? user.address : _otherAddrCtrl.text.trim();

    // ── KONDISI 6: Panggil notifier.submitItem → isSubmitting jadi true ──
    final success =
        await ref.read(postItemNotifierProvider.notifier).submitItem(
              title: _titleCtrl.text.trim(),
              category: _selectedCategory!,
              description: _descCtrl.text.trim(),
              pickupMethods: _selectedMethods.toList(),
              address: address,
              imageUrl: _pickedImagePath,
            );

    if (success && mounted) {
      // Reset form setelah berhasil
      _titleCtrl.clear();
      _descCtrl.clear();
      _otherAddrCtrl.clear();
      setState(() {
        _selectedCategory = null;
        _selectedMethods.clear();
        _useProfileAddress = true;
        _pickedImagePath = null;
        _validationErrors.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barang berhasil diposting! 🎉'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ===========================================================================
  // BUILD — Memilih tampilan berdasarkan state dari Notifier
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(postItemNotifierProvider);
    final p = Theme.of(context).extension<AppPalette>()!;
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: Text(
                'Posting Barang',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ),

            // ── KONTEN UTAMA — switch berdasarkan state ──
            Expanded(
              child: switch (postState) {
                // ━━ KONDISI 1: Initial Loading ━━
                PostItemLoading() => _buildLoading(p),

                // ━━ KONDISI 3: Empty State ━━
                PostItemEmpty() => _buildEmpty(p),

                // ━━ KONDISI 4: Error State + Retry ━━
                PostItemError(message: final msg) => _buildError(p, msg),

                // ━━ KONDISI 2, 5, 6: Form ━━
                PostItemLoaded() =>
                  _buildForm(p, postState, user?.address ?? ''),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // KONDISI 1: Initial Loading
  // ===========================================================================

  Widget _buildLoading(AppPalette p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: p.primary),
          const SizedBox(height: 16),
          Text(
            'Memuat data kategori...',
            style: TextStyle(color: p.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KONDISI 3: Empty State
  // ===========================================================================

  Widget _buildEmpty(AppPalette p) {
    return RefreshIndicator(
      color: p.primary,
      onRefresh: () =>
          ref.read(postItemNotifierProvider.notifier).loadCategories(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 64, color: p.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Belum Ada Kategori',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Data kategori barang belum tersedia.\nSilakan coba lagi nanti.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: p.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(postItemNotifierProvider.notifier)
                          .loadCategories(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.primary,
                        side: BorderSide(color: p.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Muat Ulang'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KONDISI 4: Error State + Tombol Retry
  // ===========================================================================

  Widget _buildError(AppPalette p, String message) {
    return RefreshIndicator(
      color: p.primary,
      onRefresh: () =>
          ref.read(postItemNotifierProvider.notifier).loadCategories(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 64, color: p.danger),
                    const SizedBox(height: 16),
                    Text(
                      'Terjadi Kesalahan',
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
                      style: TextStyle(
                          fontSize: 14, color: p.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => ref
                          .read(postItemNotifierProvider.notifier)
                          .loadCategories(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: p.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Coba Lagi',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KONDISI 2: Form (Data Berhasil Dimuat)
  // + KONDISI 5: Validasi Input
  // + KONDISI 6: Loading Saat Submit
  // ===========================================================================

  Widget _buildForm(
      AppPalette p, PostItemLoaded loadedState, String profileAddress) {
    final isSubmitting = loadedState.isSubmitting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ── Foto Barang ──
        _label(p, 'Foto Barang'),
        GestureDetector(
          onTap: isSubmitting ? null : _pickImage,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _pickedImagePath == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 40, color: p.textMuted),
                      const SizedBox(height: 8),
                      Text('Tambah Foto',
                          style: TextStyle(color: p.textMuted, fontSize: 13)),
                    ],
                  )
                // Preview foto yang sudah dipilih
                : kIsWeb
                    ? Image.network(_pickedImagePath!,
                        fit: BoxFit.cover, width: double.infinity)
                    : Image.file(File(_pickedImagePath!),
                        fit: BoxFit.cover, width: double.infinity),
          ),
        ),

        const SizedBox(height: 20),

        // ── Field: Judul Barang ──
        _label(p, 'Judul Barang'),
        _textField(
          p,
          controller: _titleCtrl,
          hint: 'Mis. Meja Belajar Kayu Jati Belanda',
          enabled: !isSubmitting,
          error: _validationErrors['title'],
        ),

        const SizedBox(height: 20),

        // ── Field: Kategori (chip selector) ──
        _label(p, 'Kategori'),
        // ── KONDISI 5: Error validasi untuk kategori ──
        if (_validationErrors['category'] != null)
          _errorText(p, _validationErrors['category']!),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in loadedState.categories)
              _chip(
                p,
                label: '${cat.emoji} ${cat.name}',
                selected: _selectedCategory == cat.name,
                enabled: !isSubmitting,
                onTap: () => setState(() => _selectedCategory = cat.name),
              ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Field: Deskripsi ──
        _label(p, 'Deskripsi'),
        _textField(
          p,
          controller: _descCtrl,
          hint: 'Ceritakan kondisi barang, ukuran, dll…',
          maxLines: 4,
          enabled: !isSubmitting,
          error: _validationErrors['desc'],
        ),

        const SizedBox(height: 20),

        // ── Field: Metode Pengambilan (multi-select chip) ──
        _label(p, 'Metode Pengambilan'),
        if (_validationErrors['methods'] != null)
          _errorText(p, _validationErrors['methods']!),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (method, emoji) in _kPickupMethods)
              _chip(
                p,
                label: '$emoji $method',
                selected: _selectedMethods.contains(method),
                enabled: !isSubmitting,
                onTap: () => setState(() {
                  if (_selectedMethods.contains(method)) {
                    _selectedMethods.remove(method);
                  } else {
                    _selectedMethods.add(method);
                  }
                }),
              ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Field: Alamat Penjemputan ──
        _label(p, 'Alamat Penjemputan'),
        // Toggle: pakai alamat profil atau isi manual
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: SwitchListTile(
              dense: true,
              value: _useProfileAddress,
              activeThumbColor: p.primary,
              onChanged: isSubmitting
                  ? null
                  : (v) => setState(() => _useProfileAddress = v),
              title: Text(
                'Pakai alamat profil',
                style: TextStyle(fontSize: 13.5, color: p.text),
              ),
              subtitle: Text(
                profileAddress.isNotEmpty ? profileAddress : 'Belum diatur',
                style: TextStyle(fontSize: 12, color: p.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (!_useProfileAddress) ...[
          const SizedBox(height: 8),
          _textField(
            p,
            controller: _otherAddrCtrl,
            hint: 'Mis. Jl. Merdeka No. 10, Jakarta Selatan',
            enabled: !isSubmitting,
            error: _validationErrors['addr'],
          ),
        ],

        const SizedBox(height: 28),

        // ── Tombol Submit ──
        // ── KONDISI 6: Loading saat submit ──
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: p.accent.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isSubmitting
                // ── KONDISI 6: Spinner di dalam tombol ──
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Kirim',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================

  Widget _label(AppPalette p, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
      ),
    );
  }

  /// ── KONDISI 5: Text error merah di bawah field ──
  Widget _errorText(AppPalette p, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2, bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: p.danger),
      ),
    );
  }

  Widget _textField(
    AppPalette p, {
    required TextEditingController controller,
    required String hint,
    String? error,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          style: TextStyle(color: p.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: p.textMuted),
            filled: true,
            fillColor: enabled ? p.surface : p.surface.withValues(alpha: 0.6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              // ── KONDISI 5: Border merah jika ada error ──
              borderSide:
                  BorderSide(color: error != null ? p.danger : p.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: error != null ? p.danger : p.primary,
                width: 1.6,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: p.border),
            ),
          ),
        ),
        if (error != null) _errorText(p, error),
      ],
    );
  }

  /// Chip selector yang bisa single-select (kategori) atau multi-select (metode).
  Widget _chip(
    AppPalette p, {
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? p.primary : p.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? p.onPrimary : p.textMuted,
          ),
        ),
      ),
    );
  }
}
