import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/items_provider.dart';
import '../providers/requests_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_palette.dart';

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
        _View.edit => _EditProfileView(onBack: () => setState(() => _view = _View.menu)),
        _View.address => _AddressView(onBack: () => setState(() => _view = _View.menu)),
        _View.help => _HelpView(onBack: () => setState(() => _view = _View.menu)),
      },
    );
  }

  Widget _menu() {
    final p = context.palette;
    final user = ref.watch(authProvider);
    final isDark = ref.watch(themeModeProvider);
    final myItems = ref.watch(myItemsProvider).length;
    final given = ref
        .watch(itemsProvider)
        .where((it) => it.ownerId == user?.id && it.status.name == 'completed')
        .length;
    final requests = ref.watch(myOutgoingRequestsProvider).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('Profil',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
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
                child: Text(user?.initials ?? '?',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'Pengguna',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.text)),
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
            _stat('$myItems', 'Barang Saya'),
            const SizedBox(width: 12),
            _stat('$given', 'Diberikan'),
            const SizedBox(width: 12),
            _stat('$requests', 'Pengajuan'),
          ],
        ),
        const SizedBox(height: 22),

        // Mode gelap
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 20, color: p.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Mode Gelap',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
              ),
              Switch(
                value: isDark,
                activeThumbColor: p.primary,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ],
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
              _menuTile(Icons.edit_outlined, 'Edit Profil', () => setState(() => _view = _View.edit)),
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
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.danger,
              side: BorderSide(color: p.danger.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout, size: 19),
            label: const Text('Keluar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    final p = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: p.primary)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: p.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap) {
    final p = context.palette;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 21, color: p.primary),
      title: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
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

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider);
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
        _LabeledField(label: 'Nama Lengkap', controller: _name),
        _LabeledField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress),
        _LabeledField(label: 'Nomor HP', controller: _phone, keyboardType: TextInputType.phone),
        const SizedBox(height: 8),
        _SaveButton(onPressed: () {
          ref.read(authProvider.notifier).updateUser(
                name: _name.text.trim(),
                email: _email.text.trim(),
                phone: _phone.text.trim(),
              );
          _done(context, 'Profil berhasil diperbarui ✅');
        }),
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

  @override
  void initState() {
    super.initState();
    _addr = TextEditingController(text: ref.read(authProvider)?.address ?? '');
  }

  @override
  void dispose() {
    _addr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SubScaffold(
      title: 'Alamat Pengambilan',
      onBack: widget.onBack,
      children: [
        _LabeledField(
          label: 'Alamat Lengkap',
          controller: _addr,
          maxLines: 4,
          hint: 'Mis. Jl. Kenanga No. 10, Kel. Melati, Jakarta Selatan',
        ),
        const SizedBox(height: 8),
        _SaveButton(onPressed: () {
          ref.read(authProvider.notifier).updateUser(address: _addr.text.trim());
          _done(context, 'Alamat pengambilan tersimpan ✅');
        }),
      ],
    );
  }
}

/// ------- Sub-view: Bantuan & Panduan -------
class _HelpView extends StatelessWidget {
  const _HelpView({required this.onBack});
  final VoidCallback onBack;

  static const _faqs = [
    ('Bagaimana cara memberi barang?',
        'Buka tab Posting, isi detail barang, pilih metode & alamat pengambilan, lalu tekan Posting Barang.'),
    ('Bagaimana cara meminta barang?',
        'Buka detail barang di Beranda, tekan Ajukan Pengambilan, pilih metode, lalu konfirmasi.'),
    ('Apakah benar-benar gratis?',
        'Ya. PakaiLagi adalah platform berbagi barang bekas layak pakai, gratis untuk sesama.'),
    ('Bagaimana koordinasi dengan pemberi?',
        'Gunakan fitur Chat pada detail barang untuk menyepakati waktu & lokasi pengambilan.'),
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
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: p.text)),
                const SizedBox(height: 6),
                Text(f.$2, style: TextStyle(fontSize: 13.5, height: 1.5, color: p.textMuted)),
              ],
            ),
          ),
      ],
    );
  }
}

/// ------- Helper widgets untuk sub-view -------
class _SubScaffold extends StatelessWidget {
  const _SubScaffold({required this.title, required this.onBack, required this.children});
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
              IconButton(icon: Icon(Icons.arrow_back, color: p.text), onPressed: onBack),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.text)),
            ],
          ),
        ),
        Divider(height: 1, color: p.border),
        Expanded(
          child: ListView(
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
  });
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(label,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.text)),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: p.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: p.textMuted),
              filled: true,
              fillColor: p.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.primary, width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});
  final VoidCallback onPressed;

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
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

void _done(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
