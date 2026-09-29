import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/mock_data.dart';
import '../models/item.dart';
import '../providers/auth_provider.dart';
import '../providers/items_provider.dart';
import '../theme/app_palette.dart';

class PostItemScreen extends ConsumerStatefulWidget {
  const PostItemScreen({super.key});

  @override
  ConsumerState<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends ConsumerState<PostItemScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _otherAddr = TextEditingController();
  String? _category;
  final Set<String> _methods = {};
  bool _useProfileAddress = true;
  String? _pickedImagePath;

  final Map<String, String> _errors = {};

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _otherAddr.dispose();
    super.dispose();
  }

  void _submit() {
    final user = ref.read(authProvider);
    final e = <String, String>{};
    if (_title.text.trim().isEmpty) e['title'] = 'Judul wajib diisi';
    if (_category == null) e['category'] = 'Pilih kategori barang dulu ya';
    if (_desc.text.trim().isEmpty) e['desc'] = 'Deskripsi wajib diisi';
    if (_methods.isEmpty) e['methods'] = 'Pilih minimal satu metode pengambilan';
    if (!_useProfileAddress && _otherAddr.text.trim().isEmpty) {
      e['addr'] = 'Isi alamat lain atau pakai alamat profil';
    }
    setState(() => _errors
      ..clear()
      ..addAll(e));
    if (e.isNotEmpty || user == null) return;

    ref.read(itemsProvider.notifier).addItem(
          title: _title.text.trim(),
          category: _category!,
          description: _desc.text.trim(),
          pickupMethods: _methods.toList(),
          address: _useProfileAddress ? user.address : _otherAddr.text.trim(),
          ownerId: user.id,
          ownerName: user.name,
          ownerPhone: user.phone,
          imageUrl: _pickedImagePath,
        );

    _title.clear();
    _desc.clear();
    _otherAddr.clear();
    setState(() {
      _category = null;
      _methods.clear();
      _useProfileAddress = true;
      _pickedImagePath = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Barang berhasil diposting! 🎉')),
    );
  }

  Future<void> _pickImage(BuildContext ctx) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: ctx,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1200);
    if (picked != null) {
      setState(() => _pickedImagePath = picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = ref.watch(authProvider);
    final profileAddress = user?.address ?? '-';

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
            child: Text('Posting Barang',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _label('Foto Barang'),
                GestureDetector(
                  onTap: () => _pickImage(context),
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.primary.withValues(alpha: 0.4), width: 1.4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _pickedImagePath != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              kIsWeb
                                  ? Image.network(_pickedImagePath!, fit: BoxFit.cover)
                                  : Image.file(File(_pickedImagePath!), fit: BoxFit.cover),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_outlined, size: 36, color: p.primary),
                              const SizedBox(height: 10),
                              Text('Ketuk untuk menambah foto',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: p.primary, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Maks. 5 foto · JPG atau PNG',
                                  style: TextStyle(fontSize: 12, color: p.textMuted)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                _label('Judul Barang'),
                _input(_title, 'Mis. Meja Belajar Kayu Jati Belanda', error: _errors['title']),

                const SizedBox(height: 20),
                _label('Kategori'),
                if (_errors['category'] != null) _errText(_errors['category']!),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in kCategories)
                      GestureDetector(
                        onTap: () => setState(() => _category = c.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _category == c.name ? p.primary : p.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _category == c.name ? p.primary : p.border),
                          ),
                          child: Text('${c.emoji} ${c.name}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _category == c.name ? p.onPrimary : p.textMuted,
                              )),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),
                _label('Deskripsi'),
                _input(_desc, 'Ceritakan kondisi barang, ukuran, dan alasan diberikan…',
                    error: _errors['desc'], maxLines: 5),

                const SizedBox(height: 20),
                _label('Metode Pengambilan'),
                Text('Pilih cara penerima bisa mengambil barangmu (boleh lebih dari satu).',
                    style: TextStyle(fontSize: 12, color: p.textMuted)),
                if (_errors['methods'] != null) _errText(_errors['methods']!),
                const SizedBox(height: 10),
                for (final m in kPickupMethodInfo) _methodTile(m.$1, m.$2, m.$3),

                const SizedBox(height: 20),
                _label('Alamat Pengambilan'),
                Text('Pakai alamat dari profil, atau masukkan alamat lain.',
                    style: TextStyle(fontSize: 12, color: p.textMuted)),
                const SizedBox(height: 10),
                _addrOption(true, 'Alamat Profil', profileAddress),
                const SizedBox(height: 10),
                _addrOption(false, 'Alamat Lain', 'Masukkan alamat pengambilan yang berbeda.'),
                if (!_useProfileAddress) ...[
                  const SizedBox(height: 10),
                  _input(_otherAddr, 'Mis. Jl. Kenanga No. 10, Jakarta Selatan…',
                      error: _errors['addr'], maxLines: 3),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Posting Barang',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(t, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.text)),
    );
  }

  Widget _errText(String t) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Text(t, style: TextStyle(fontSize: 12, color: p.danger)),
    );
  }

  Widget _input(TextEditingController c, String hint, {String? error, int maxLines = 1}) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: c,
          maxLines: maxLines,
          style: TextStyle(color: p.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: p.textMuted),
            filled: true,
            fillColor: p.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: error != null ? p.danger : p.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: error != null ? p.danger : p.primary, width: 1.6),
            ),
          ),
        ),
        if (error != null) _errText(error),
      ],
    );
  }

  Widget _methodTile(String icon, String label, String desc) {
    final p = context.palette;
    final active = _methods.contains(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => active ? _methods.remove(label) : _methods.add(label)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? p.surfaceAlt : p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? p.primary : p.border, width: active ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.text)),
                    const SizedBox(height: 2),
                    Text(desc, style: TextStyle(fontSize: 12, color: p.textMuted)),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: active ? p.primary : p.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: active ? p.primary : p.border, width: 1.6),
                ),
                child: active ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addrOption(bool isProfile, String title, String body) {
    final p = context.palette;
    final active = _useProfileAddress == isProfile;
    return GestureDetector(
      onTap: () => setState(() => _useProfileAddress = isProfile),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? p.surfaceAlt : p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? p.primary : p.border, width: active ? 1.6 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: p.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.4)),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? p.primary : Colors.transparent,
                border: Border.all(color: active ? p.primary : p.border, width: 2),
              ),
              child: active
                  ? const Center(
                      child: SizedBox(
                        width: 8,
                        height: 8,
                        child: DecoratedBox(
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
