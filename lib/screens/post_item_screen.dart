import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/pickup_methods.dart';
import '../models/app_user.dart';
import '../notifiers/item_notifier.dart';
import '../notifiers/item_state.dart';
import '../providers/auth_provider.dart';
import '../providers/cloud_item_provider.dart';
import '../router/app_router.dart';
import '../services/user_messages.dart';
import '../theme/app_palette.dart';
import '../widgets/accessible_tap.dart';
import '../widgets/progress_dialog.dart';

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
// Fitur yang ada:
//   - Upload / preview foto (image_picker)
//   - Alamat penjemputan diambil dari alamat profil (diisi di menu Profil,
//     bisa memakai GPS). Form menampilkan alamat lengkap; pengguna lain
//     hanya melihat kelurahan & kota.
//   - Multi-select metode pengambilan
//   - Tombol "Post" → simpan langsung ke Firestore + Base64
//
// Widget ini HANYA bertanggung jawab menampilkan UI.
// Semua logika bisnis ada di PostItemNotifier dan CloudItemNotifier.
// =============================================================================

class PostItemScreen extends ConsumerStatefulWidget {
  const PostItemScreen({super.key});

  @override
  ConsumerState<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends ConsumerState<PostItemScreen> {
  // ── Controller & state form ──
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _descFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  /// Penanda tiap bagian form, dipakai untuk scroll ke isian yang salah.
  final Map<String, GlobalKey> _sectionKeys = {
    for (final key in const [
      'image',
      'title',
      'category',
      'desc',
      'methods',
      'addr'
    ])
      key: GlobalKey(debugLabel: 'section-$key'),
  };

  String? _selectedCategory;
  final Set<String> _selectedMethods = {}; // multi-select
  String? _pickedImagePath; // path foto untuk preview
  XFile? _pickedXFile; // XFile asli untuk readAsBytes (kompatibel web)

  // ── KONDISI 5: Map error validasi per-field ──
  final Map<String, String> _validationErrors = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _descFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Profil cloud adalah sumber utama alamat; profil mock lokal hanya
  /// cadangan selama profil cloud belum termuat.
  AppUser? _profile() =>
      ref.read(cloudProfileProvider).valueOrNull ?? ref.read(authProvider);

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
    XFile? result;
    try {
      // imageQuality menjaga ukuran Base64 jauh di bawah batas 1 MiB per
      // dokumen.
      result = await ImagePicker()
          .pickImage(source: source, maxWidth: 600, imageQuality: 70);
    } catch (_) {
      // Mis. izin kamera/galeri ditolak. Sebelumnya error ini tidak
      // tertangani dan pengguna tidak mendapat penjelasan.
      if (mounted) {
        AppMessenger.of(context).error(source == ImageSource.camera
            ? 'Kamera tidak bisa dibuka. Periksa izin kamera di Pengaturan HP.'
            : 'Galeri tidak bisa dibuka. Periksa izin foto di Pengaturan HP.');
      }
      return;
    }
    final picked = result;
    if (picked == null || !mounted) return;
    setState(() {
      _pickedImagePath = picked.path;
      _pickedXFile = picked;
      _validationErrors.remove('image');
    });
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
    if (_profile()?.hasPickupAddress != true) {
      errors['addr'] =
          'Lengkapi alamat pengambilan di menu Profil terlebih dahulu';
    }

    setState(() {
      _validationErrors
        ..clear()
        ..addAll(errors);
    });

    return errors.isEmpty;
  }

  // ---------------------------------------------------------------------------
  // PUBLISH KE CLOUD HANDLER — Firebase Firestore + Base64
  // ---------------------------------------------------------------------------

  /// Publish barang langsung ke Firestore.
  /// Gambar di-encode menjadi Base64 string (tanpa Firebase Storage).
  Future<void> _handlePublishToCloud() async {
    // Tutup keyboard agar pesan hasil dan isian yang salah tidak tertutup.
    FocusScope.of(context).unfocus();
    final isFormValid = _validateForm();
    final hasImage = _pickedImagePath != null && _pickedImagePath!.isNotEmpty;
    if (!hasImage) {
      setState(() {
        _validationErrors['image'] = 'Foto barang wajib ditambahkan untuk post';
      });
      if (mounted) {
        AppMessenger.of(context)
            .error('Tambahkan foto barang dulu sebelum post.');
      }
    }
    final profile = _profile();
    if (!isFormValid || !hasImage || profile == null) {
      // Tombol Post ada di paling bawah, sedangkan isian yang salah bisa di
      // atas layar. Scroll ke isian pertama agar pengguna tahu kenapa post
      // tidak terkirim.
      _scrollToFirstError();
      if (hasImage && mounted) {
        final count = _validationErrors.length;
        AppMessenger.of(context)
            .error('Lengkapi $count isian yang ditandai merah.');
      }
      return;
    }

    final messenger = AppMessenger.of(context);
    WriteOutcome? outcome;
    String? errorMessage;
    try {
      // Baca bytes dari XFile (kompatibel web + mobile). Login Firebase
      // dipastikan di repository lewat ensureSignedIn().
      final imageBytes = await _pickedXFile!.readAsBytes();
      final notifier = ref.read(cloudItemNotifierProvider.notifier);
      outcome = await notifier.publishItem(
        title: _titleCtrl.text.trim(),
        category: _selectedCategory!,
        description: _descCtrl.text.trim(),
        imageBytes: imageBytes,
        ownerName: profile.name,
        pickupAddress: profile,
      );
      final state = ref.read(cloudItemNotifierProvider);
      if (state is PublishError) errorMessage = state.message;
    } catch (error) {
      errorMessage = friendlyError(error,
          fallback: 'Gagal membaca foto. Pilih ulang foto lalu coba lagi.');
    }

    if (!mounted) return;
    if (outcome != null) {
      _resetForm();
      final seeAction = SnackBarAction(
        label: 'Lihat',
        textColor: outcome == WriteOutcome.synced
            ? context.palette.onPrimary
            : Colors.white,
        onPressed: () {
          if (mounted) context.go(AppRoutes.home);
        },
      );
      // Hijau hanya bila server sudah mengonfirmasi; bila masih menunggu
      // koneksi, pesannya netral agar tidak menjanjikan hal yang belum pasti.
      if (outcome == WriteOutcome.synced) {
        messenger.success('Barang berhasil diposting!', action: seeAction);
      } else {
        messenger.info('Barang tersimpan di perangkat. $queuedSuffix',
            action: seeAction);
      }
    } else {
      showAppSnackBar(
          messenger, errorMessage ?? 'Gagal memposting barang. Coba lagi.',
          isError: true);
    }
  }

  /// Urutan bagian form dari atas ke bawah.
  static const _fieldOrder = [
    'image',
    'title',
    'category',
    'desc',
    'methods',
    'addr'
  ];

  void _scrollToFirstError() {
    final first =
        _fieldOrder.firstWhere(_validationErrors.containsKey, orElse: () => '');
    if (first.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[first]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300),
            alignment: 0.1,
            curve: Curves.easeOut);
      } else if (_scrollCtrl.hasClients) {
        // Bagian di luar cache ListView belum ter-build; semua bagian berada
        // di atas tombol Post, jadi scroll ke atas.
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  /// Reset semua field form ke kondisi awal.
  void _resetForm() {
    _titleCtrl.clear();
    _descCtrl.clear();
    setState(() {
      _selectedCategory = null;
      _selectedMethods.clear();
      _pickedImagePath = null;
      _pickedXFile = null;
      _validationErrors.clear();
    });
  }

  // ===========================================================================
  // BUILD — Memilih tampilan berdasarkan state dari Notifier
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(postItemNotifierProvider);
    final publishState = ref.watch(cloudItemNotifierProvider);
    final p = Theme.of(context).extension<AppPalette>()!;
    final profile =
        ref.watch(cloudProfileProvider).valueOrNull ?? ref.watch(authProvider);

    // Cek apakah sedang dalam proses publish ke cloud
    final isPublishing = publishState is PublishLoading;

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
                  _buildForm(p, postState, profile, isPublishing),
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

  Widget _buildForm(AppPalette p, PostItemLoaded loadedState, AppUser? profile,
      bool isPublishing) {
    final isSubmitting = loadedState.isSubmitting || isPublishing;

    return ListView(
      controller: _scrollCtrl,
      // Men-scroll form menutup keyboard.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ── Foto Barang ──
        _label(p, 'Foto Barang', sectionKey: _sectionKeys['image']),
        AccessibleTap(
          onTap: isSubmitting ? null : _pickImage,
          label: _pickedImagePath == null
              ? 'Tambah foto barang dari kamera atau galeri'
              : 'Foto barang sudah dipilih. Ketuk untuk mengganti foto',
          borderRadius: BorderRadius.circular(14),
          minSize: 0,
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
        if (_validationErrors['image'] != null)
          _errorText(p, _validationErrors['image']!),

        const SizedBox(height: 20),

        // ── Field: Judul Barang ──
        _labeledTextField(
          p,
          label: 'Judul Barang',
          sectionKey: _sectionKeys['title'],
          controller: _titleCtrl,
          hint: 'Mis. Meja Belajar Kayu Jati Belanda',
          enabled: !isSubmitting,
          error: _validationErrors['title'],
          // "Next" langsung ke Deskripsi (melewati chip kategori).
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _descFocus.requestFocus(),
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: 20),

        // ── Field: Kategori (chip selector) ──
        _label(p, 'Kategori', sectionKey: _sectionKeys['category']),
        // ── KONDISI 5: Error validasi untuk kategori ──
        if (_validationErrors['category'] != null)
          _errorText(p, _validationErrors['category']!),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          // Area sentuh chip sudah 48 dp (lebih tinggi dari tampilannya), jadi
          // jarak antarbaris dikurangi agar tampilan tetap rapat.
          runSpacing: 0,
          children: [
            for (final cat in loadedState.categories)
              _chip(
                p,
                label: '${cat.emoji} ${cat.name}',
                semanticLabel: 'Kategori ${cat.name}',
                radio: true,
                selected: _selectedCategory == cat.name,
                enabled: !isSubmitting,
                onTap: () => setState(() {
                  _selectedCategory = cat.name;
                  _validationErrors.remove('category');
                }),
              ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Field: Deskripsi ──
        _labeledTextField(
          p,
          label: 'Deskripsi',
          sectionKey: _sectionKeys['desc'],
          controller: _descCtrl,
          focusNode: _descFocus,
          hint: 'Ceritakan kondisi barang, ukuran, dll…',
          maxLines: 4,
          enabled: !isSubmitting,
          error: _validationErrors['desc'],
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: 20),

        // ── Field: Metode Pengambilan (multi-select chip) ──
        _label(p, 'Metode Pengambilan', sectionKey: _sectionKeys['methods']),
        if (_validationErrors['methods'] != null)
          _errorText(p, _validationErrors['methods']!),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          // Area sentuh chip sudah 48 dp (lebih tinggi dari tampilannya), jadi
          // jarak antarbaris dikurangi agar tampilan tetap rapat.
          runSpacing: 0,
          children: [
            for (final (method, emoji, _) in kPickupMethods)
              _chip(
                p,
                label: '$emoji $method',
                semanticLabel: 'Metode $method',
                selected: _selectedMethods.contains(method),
                enabled: !isSubmitting,
                onTap: () => setState(() {
                  if (_selectedMethods.contains(method)) {
                    _selectedMethods.remove(method);
                  } else {
                    _selectedMethods.add(method);
                    _validationErrors.remove('methods');
                  }
                }),
              ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Field: Alamat Penjemputan ──
        _label(p, 'Alamat Penjemputan', sectionKey: _sectionKeys['addr']),
        // Alamat selalu berasal dari profil. Form menampilkan alamat lengkap
        // ke pemilik; pengguna lain hanya melihat kelurahan & kota.
        _pickupAddressCard(p, profile, isSubmitting),
        if (_validationErrors['addr'] != null)
          _errorText(p, _validationErrors['addr']!),

        const SizedBox(height: 28),

        // ── Tombol Utama: Publish (Firestore) ──
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : _handlePublishToCloud,
            style: ElevatedButton.styleFrom(
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              disabledBackgroundColor: p.primary.withValues(alpha: 0.6),
              disabledForegroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isSubmitting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: p.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Teks ini menjawab "sedang apa?" selama proses.
                      const Text(
                        'Memposting barang…',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  )
                : const Text(
                    'Post',
                    semanticsLabel: 'Post barang',
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

  /// Kartu alamat penjemputan dari profil (hanya-baca).
  Widget _pickupAddressCard(AppPalette p, AppUser? profile, bool isSubmitting) {
    final ready = profile?.hasPickupAddress == true;
    final hasError = _validationErrors['addr'] != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasError ? p.danger : p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 20, color: p.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ready
                      ? profile!.address
                      : 'Alamat pengambilan belum diatur di Profil.',
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: ready ? p.text : p.textMuted),
                ),
              ),
            ],
          ),
          if (ready) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: p.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 14, color: p.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Terlihat oleh pengguna lain: ${profile!.areaLabel}',
                      style: TextStyle(fontSize: 12, color: p.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  isSubmitting ? null : () => context.go(AppRoutes.profile),
              child: Text(ready ? 'Ubah di Profil' : 'Atur di Profil'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(AppPalette p, String text, {Key? sectionKey}) {
    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      // Judul bagian dikenali pembaca layar sebagai heading.
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: p.text,
          ),
        ),
      ),
    );
  }

  /// ── KONDISI 5: Text error merah di bawah field ──
  /// liveRegion: pembaca layar langsung membacakan pesan saat muncul.
  Widget _errorText(AppPalette p, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2, bottom: 4),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: p.danger),
        ),
      ),
    );
  }

  /// Label + field + pesan error digabung menjadi satu node aksesibilitas,
  /// sehingga TalkBack membacakan "Judul Barang, <error>, kotak edit" dan
  /// bukan hanya teks contoh (hint).
  Widget _labeledTextField(
    AppPalette p, {
    required String label,
    Key? sectionKey,
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    String? error,
    int maxLines = 1,
    bool enabled = true,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(p, label, sectionKey: sectionKey),
          _textField(
            p,
            controller: controller,
            hint: hint,
            focusNode: focusNode,
            error: error,
            maxLines: maxLines,
            enabled: enabled,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            textCapitalization: textCapitalization,
          ),
        ],
      ),
    );
  }

  Widget _textField(
    AppPalette p, {
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    String? error,
    int maxLines = 1,
    bool enabled = true,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          enabled: enabled,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          textCapitalization: textCapitalization,
          // Ruang ekstra di bawah field yang difokuskan, agar pesan error di
          // bawahnya tetap terlihat di atas keyboard.
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
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
  /// Area sentuh minimal 48 dp dan dikenali pembaca layar sebagai pilihan.
  Widget _chip(
    AppPalette p, {
    required String label,
    required String semanticLabel,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
    bool radio = false,
  }) {
    return AccessibleTap(
      onTap: enabled ? onTap : null,
      label: semanticLabel,
      selected: selected,
      radio: radio,
      borderRadius: BorderRadius.circular(12),
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
