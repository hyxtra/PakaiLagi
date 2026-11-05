import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../business/address_privacy.dart';
import '../router/app_router.dart';
import '../widgets/pin_preview_map.dart';
import 'location_picker_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/cloud_item_provider.dart';
import '../providers/theme_provider.dart';
import '../repositories/firebase_repository.dart';
import '../business/item_status_rules.dart';
import '../services/user_messages.dart';
import '../theme/app_palette.dart';
import '../widgets/progress_dialog.dart';

enum _View { menu, edit, address, help }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _View _view = _View.menu;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: switch (_view) {
        _View.menu => _menu(),
        _View.edit =>
          _EditProfileView(onBack: () => setState(() => _view = _View.menu)),
        _View.address =>
          _AddressView(onBack: () => setState(() => _view = _View.menu)),
        _View.help =>
          _HelpView(onBack: () => setState(() => _view = _View.menu)),
      },
    );
  }

  Widget _menu() {
    final p = context.palette;
    final mockUser = ref.watch(authProvider);
    final cloudUser = ref.watch(cloudProfileProvider).valueOrNull;
    final user = cloudUser ?? mockUser;
    final isDark = ref.watch(themeModeProvider);
    // Statistik dari Firestore. Sebelumnya dihitung dari data lokal mock
    // yang selalu kosong, sehingga selalu tampil 0 dan membingungkan.
    final myCloudItems = ref.watch(myCloudItemsStreamProvider).valueOrNull;
    final outgoing =
        ref.watch(myOutgoingCloudRequestItemIdsProvider).valueOrNull;
    final myItems = myCloudItems?.length;
    final given = myCloudItems
        ?.where((it) => it.status == ItemStatusRules.completed)
        .length;
    final requests = outgoing?.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Semantics(
          header: true,
          child: Text('Profil',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
        ),
        const SizedBox(height: 18),
        // Kartu identitas
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: p.primary,
                // Inisial hanya hiasan; nama lengkap dibacakan di sebelahnya.
                child: ExcludeSemantics(
                  child: Text(user?.initials ?? '?',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: p.onPrimary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'Pengguna',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: p.text)),
                    const SizedBox(height: 3),
                    Text(user?.email ?? '-',
                        style: TextStyle(fontSize: 13, color: p.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Statistik
        Row(
          children: [
            // "–" selama data belum termuat, bukan angka 0 yang menyesatkan.
            _stat(myItems?.toString() ?? '–', 'Barang Saya'),
            const SizedBox(width: 12),
            _stat(given?.toString() ?? '–', 'Diberikan'),
            const SizedBox(width: 12),
            _stat(requests?.toString() ?? '–', 'Pengajuan'),
          ],
        ),
        const SizedBox(height: 22),

        // Mode gelap. MergeSemantics: TalkBack membacakan "Mode Gelap,
        // sakelar, aktif/nonaktif" dalam satu fokus.
        MergeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                    size: 20, color: p.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Mode Gelap',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: p.text)),
                ),
                Switch(
                  value: isDark,
                  activeThumbColor: p.primary,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Menu
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              _menuTile(Icons.edit_outlined, 'Edit Profil',
                  () => setState(() => _view = _View.edit)),
              _divider(),
              _menuTile(Icons.location_on_outlined, 'Alamat Pengambilan',
                  () => setState(() => _view = _View.address)),
              _divider(),
              _menuTile(Icons.help_outline, 'Bantuan & Panduan',
                  () => setState(() => _view = _View.help)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _confirmSignOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.danger,
              side: BorderSide(color: p.danger.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout, size: 19),
            label: const Text('Keluar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  /// Konfirmasi sebelum keluar, lalu beri tahu bahwa proses berhasil.
  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text('Kamu perlu masuk lagi untuk memakai PakaiLagi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style:
                  TextButton.styleFrom(foregroundColor: context.palette.danger),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = AppMessenger.of(context);
    ref.read(authProvider.notifier).signOut();
    messenger.info('Kamu sudah keluar dari akun.');
  }

  Widget _stat(String value, String label) {
    final p = context.palette;
    return Expanded(
      child: MergeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: p.primary)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: p.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap) {
    final p = context.palette;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 21, color: p.primary),
      title: Text(label,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
      trailing: Icon(Icons.chevron_right, color: p.textMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _divider() {
    final p = context.palette;
    return Divider(height: 1, indent: 56, color: p.border);
  }
}

/// ------- Sub-view: Edit Profil -------
class _EditProfileView extends ConsumerStatefulWidget {
  const _EditProfileView({required this.onBack});
  final VoidCallback onBack;

  @override
  ConsumerState<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<_EditProfileView> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  bool _saving = false;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final messenger = AppMessenger.of(context);
    final current =
        ref.read(cloudProfileProvider).valueOrNull ?? ref.read(authProvider);
    setState(() => _saving = true);
    try {
      final outcome = await awaitWrite(
        ref.read(firebaseRepositoryProvider).saveMyProfile(
              name: _name.text.trim(),
              email: _email.text.trim(),
              phone: _phone.text.trim(),
              address: current?.address ?? '',
              kelurahan: current?.kelurahan ?? '',
              kota: current?.kota ?? '',
              latitude: current?.latitude,
              longitude: current?.longitude,
            ),
      );
      ref.read(authProvider.notifier).updateUser(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
          );
      messenger.result(outcome,
          done: 'Profil berhasil diperbarui',
          queued: 'Profil tersimpan di perangkat. $queuedSuffix');
    } catch (error) {
      showAppSnackBar(messenger,
          friendlyError(error, fallback: 'Gagal menyimpan profil. Coba lagi.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final u =
        ref.read(cloudProfileProvider).valueOrNull ?? ref.read(authProvider);
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SubScaffold(
      title: 'Edit Profil',
      onBack: widget.onBack,
      children: [
        _LabeledField(
          label: 'Nama Lengkap',
          controller: _name,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        _LabeledField(
          label: 'Email',
          controller: _email,
          enabled: !_saving,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        _LabeledField(
          label: 'Nomor HP',
          controller: _phone,
          enabled: !_saving,
          keyboardType: TextInputType.phone,
          // Field terakhir: "Selesai" di keyboard langsung menyimpan.
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 8),
        _SaveButton(onPressed: _saving ? null : _save, loading: _saving),
      ],
    );
  }
}

/// ------- Sub-view: Alamat Pengambilan -------
class _AddressView extends ConsumerStatefulWidget {
  const _AddressView({required this.onBack});
  final VoidCallback onBack;

  @override
  ConsumerState<_AddressView> createState() => _AddressViewState();
}

class _AddressViewState extends ConsumerState<_AddressView> {
  late final TextEditingController _addr;
  late final TextEditingController _kelurahan;
  late final TextEditingController _kota;
  double? _latitude;
  double? _longitude;
  bool _saving = false;
  final Map<String, String> _errors = {};

  bool get _hasPin => _latitude != null && _longitude != null;

  @override
  void initState() {
    super.initState();
    final user =
        ref.read(cloudProfileProvider).valueOrNull ?? ref.read(authProvider);
    _addr = TextEditingController(text: user?.address ?? '');
    _kelurahan = TextEditingController(text: user?.kelurahan ?? '');
    _kota = TextEditingController(text: user?.kota ?? '');
    _latitude = user?.latitude;
    _longitude = user?.longitude;
  }

  @override
  void dispose() {
    _addr.dispose();
    _kelurahan.dispose();
    _kota.dispose();
    super.dispose();
  }

  /// Pesan informasi setelah memilih titik di peta (bukan sukses/gagal).
  void _snack(String message) {
    if (!mounted) return;
    AppMessenger.of(context).info(message);
  }

  /// Buka peta pinpoint. Peta langsung mencari GPS bila belum ada titik.
  Future<void> _pickOnMap() async {
    final picked = await context.push<PickedLocation>(
      AppRoutes.pickLocation,
      extra: _hasPin ? LatLng(_latitude!, _longitude!) : null,
    );
    if (picked == null || !mounted) return;

    final parts = picked.address;
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
      if (parts != null) {
        _addr.text = parts.fullAddress;
        if (parts.kelurahan.isNotEmpty) _kelurahan.text = parts.kelurahan;
        if (parts.kota.isNotEmpty) _kota.text = parts.kota;
      }
      _errors.clear();
    });
    _snack(parts != null
        ? 'Alamat terisi dari titik peta. Lengkapi nomor rumah atau RT/RW, '
            'lalu tekan Simpan.'
        : 'Titik dipilih. Isi alamat, kelurahan, dan kota secara manual, '
            'lalu tekan Simpan.');
  }

  Future<void> _save() async {
    // Tutup keyboard agar pesan error/hasil tidak tertutup.
    FocusScope.of(context).unfocus();
    final errors = <String, String>{
      if (_addr.text.trim().isEmpty) 'addr': 'Alamat lengkap wajib diisi',
      if (_kelurahan.text.trim().isEmpty)
        'kelurahan': 'Kelurahan/desa wajib diisi',
      if (_kota.text.trim().isEmpty) 'kota': 'Kota/kabupaten wajib diisi',
    };
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    if (errors.isNotEmpty) return;

    final messenger = AppMessenger.of(context);
    final current =
        ref.read(cloudProfileProvider).valueOrNull ?? ref.read(authProvider);
    setState(() => _saving = true);
    try {
      final outcome = await awaitWrite(
        ref.read(firebaseRepositoryProvider).saveMyProfile(
              name: current?.name ?? 'Pengguna',
              email: current?.email ?? '',
              phone: current?.phone ?? '',
              address: _addr.text.trim(),
              kelurahan: _kelurahan.text.trim(),
              kota: _kota.text.trim(),
              latitude: _latitude,
              longitude: _longitude,
            ),
      );
      ref.read(authProvider.notifier).updateUser(
            address: _addr.text.trim(),
            kelurahan: _kelurahan.text.trim(),
            kota: _kota.text.trim(),
            latitude: _latitude,
            longitude: _longitude,
            clearCoordinates: !_hasPin,
          );
      messenger.result(outcome,
          done: 'Alamat pengambilan tersimpan',
          queued: 'Alamat tersimpan di perangkat. $queuedSuffix');
    } catch (error) {
      showAppSnackBar(messenger,
          friendlyError(error, fallback: 'Gagal menyimpan alamat. Coba lagi.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final area =
        AddressPrivacy.areaLabel(kelurahan: _kelurahan.text, kota: _kota.text);

    return _SubScaffold(
      title: 'Alamat Pengambilan',
      onBack: widget.onBack,
      children: [
        _pinSection(p),
        const SizedBox(height: 18),
        _LabeledField(
          label: 'Alamat Lengkap',
          controller: _addr,
          maxLines: 4,
          enabled: !_saving,
          error: _errors['addr'],
          textCapitalization: TextCapitalization.sentences,
          hint:
              'Mis. Jl. Kenanga No. 10 RT 02/RW 05, Kel. Melati, Jakarta Selatan',
        ),
        _LabeledField(
          label: 'Kelurahan / Desa',
          controller: _kelurahan,
          enabled: !_saving,
          error: _errors['kelurahan'],
          hint: 'Mis. Melati',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        _LabeledField(
          label: 'Kota / Kabupaten',
          controller: _kota,
          enabled: !_saving,
          error: _errors['kota'],
          hint: 'Mis. Jakarta Selatan',
          textCapitalization: TextCapitalization.words,
          // Field terakhir: "Selesai" di keyboard langsung menyimpan.
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          onChanged: (_) => setState(() {}),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 16, color: p.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pengguna lain hanya melihat: '
                  '${area.isEmpty ? '(kelurahan & kota)' : area}. '
                  'Alamat lengkap dan titik peta hanya dibagikan ke peminta '
                  'yang pengajuannya kamu terima.',
                  style:
                      TextStyle(fontSize: 12.5, height: 1.45, color: p.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SaveButton(onPressed: _saving ? null : _save, loading: _saving),
      ],
    );
  }

  /// Tombol pinpoint (belum ada titik) atau pratinjau peta (sudah ada titik).
  Widget _pinSection(AppPalette p) {
    if (!_hasPin) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _pickOnMap,
          style: ElevatedButton.styleFrom(
            backgroundColor: p.primary,
            foregroundColor: p.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.my_location, size: 20),
          label: const Text('Pinpoint Lokasi di Peta (GPS)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text('Titik Penjemputan',
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: p.text)),
        ),
        PinPreviewMap(
          latitude: _latitude!,
          longitude: _longitude!,
          onTap: _saving ? null : _pickOnMap,
          semanticLabel:
              'Peta titik penjemputan tersimpan. Ketuk dua kali untuk mengubah titik',
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.gps_fixed, size: 14, color: p.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_latitude!.toStringAsFixed(6)}, '
                '${_longitude!.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12.5, color: p.textMuted),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : _pickOnMap,
              child: const Text('Ubah Titik'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _latitude = null;
                        _longitude = null;
                      }),
              style: TextButton.styleFrom(foregroundColor: p.danger),
              child: const Text('Hapus'),
            ),
          ],
        ),
      ],
    );
  }
}

/// ------- Sub-view: Bantuan & Panduan -------
class _HelpView extends StatelessWidget {
  const _HelpView({required this.onBack});
  final VoidCallback onBack;

  static const _faqs = [
    (
      'Bagaimana cara memberi barang?',
      'Atur dulu Alamat Pengambilan di Profil (bisa memakai GPS). Lalu buka tab Posting, isi detail barang, pilih metode pengambilan, dan tekan Post. Pengguna lain hanya melihat kelurahan & kota.'
    ),
    (
      'Bagaimana cara meminta barang?',
      'Buka detail barang di Beranda, tekan Ajukan Pengambilan, pilih metode, lalu konfirmasi.'
    ),
    (
      'Apakah benar-benar gratis?',
      'Ya. PakaiLagi adalah platform berbagi barang bekas layak pakai, gratis untuk sesama.'
    ),
    (
      'Bagaimana koordinasi dengan pemberi?',
      'Gunakan fitur Chat pada detail barang untuk menyepakati waktu & lokasi pengambilan.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _SubScaffold(
      title: 'Bantuan & Panduan',
      onBack: onBack,
      children: [
        for (final f in _faqs)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.$1,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: p.text)),
                const SizedBox(height: 6),
                Text(f.$2,
                    style: TextStyle(
                        fontSize: 13.5, height: 1.5, color: p.textMuted)),
              ],
            ),
          ),
      ],
    );
  }
}

/// ------- Helper widgets untuk sub-view -------
class _SubScaffold extends StatelessWidget {
  const _SubScaffold(
      {required this.title, required this.onBack, required this.children});
  final String title;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
          child: Row(
            children: [
              IconButton(
                  tooltip: 'Kembali',
                  icon: Icon(Icons.arrow_back, color: p.text),
                  onPressed: onBack),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: p.text)),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: p.border),
        Expanded(
          child: ListView(
            // Men-scroll form menutup keyboard.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: children,
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.hint,
    this.enabled = true,
    this.error,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? hint;
  final bool enabled;
  final String? error;

  /// Hanya terpanggil oleh ketikan pengguna, bukan oleh perubahan
  /// `controller.text` dari kode (mis. hasil GPS).
  final ValueChanged<String>? onChanged;

  /// "Next" memindahkan fokus ke field berikutnya; "Done" untuk field
  /// terakhir. Default mengikuti Flutter (newline untuk multi-baris).
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // Label + field + error digabung: pembaca layar membacakan
      // "<label>, <error>, kotak edit", bukan hanya teks contoh.
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 2),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.text)),
            ),
            TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              enabled: enabled,
              onChanged: onChanged,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              textCapitalization: textCapitalization,
              // Ruang ekstra agar pesan error di bawah field tetap terlihat
              // di atas keyboard.
              scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              style: TextStyle(color: p.text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: p.textMuted),
                filled: true,
                fillColor: p.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: error != null ? p.danger : p.border),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: error != null ? p.danger : p.primary, width: 1.6),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Semantics(
                  liveRegion: true,
                  child: Text(error!,
                      style: TextStyle(fontSize: 12, color: p.danger)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed, this.loading = false});
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          // Teks gelap di atas oranye: 7,15:1 (putih hanya 2,17:1).
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.accent.withValues(alpha: 0.6),
          disabledForegroundColor: p.onAccent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: p.onAccent),
                  ),
                  const SizedBox(width: 12),
                  const Text('Menyimpan…',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              )
            : const Text('Simpan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
