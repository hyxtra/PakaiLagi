import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_palette.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _masuk = true;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).signIn(name: _name.text, email: _email.text);
    // Navigasi ditangani otomatis oleh redirect go_router.
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Brand
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: const Text('♻️', style: TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: 16),
                Text('PakaiLagi',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.text)),
                const SizedBox(height: 6),
                Text(
                  'Berbagi barang bekas layak pakai, gratis untuk sesama 💚',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: p.textMuted, height: 1.5),
                ),
                const SizedBox(height: 32),

                // Toggle Masuk / Daftar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _modeTab('Masuk', _masuk),
                      _modeTab('Daftar', !_masuk),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                if (!_masuk)
                  _field(
                    controller: _name,
                    hint: 'Nama lengkap',
                    icon: Icons.person_outline,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                  ),
                _field(
                  controller: _email,
                  hint: 'Email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());
                    return ok ? null : 'Format email tidak valid';
                  },
                ),
                _field(
                  controller: _password,
                  hint: 'Kata sandi',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
                    return v.length < 6 ? 'Kata sandi minimal 6 karakter' : null;
                  },
                ),

                if (_masuk)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Text(
                      'Nama akun akan menyesuaikan email yang kamu pakai.',
                      style: TextStyle(fontSize: 12.5, color: p.textMuted),
                    ),
                  ),

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_masuk ? 'Masuk' : 'Buat Akun',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Dengan melanjutkan, kamu menyetujui Ketentuan Layanan & Kebijakan Privasi PakaiLagi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: p.textMuted, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text('Coba: rani@pakailagi.id / budi@pakailagi.id (sandi bebas ≥6)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: p.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String label, bool active) {
    final p = context.palette;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _masuk = label == 'Masuk'),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? p.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: active ? p.primary : p.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: p.text),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: p.textMuted, size: 20),
          filled: true,
          fillColor: p.surface,
          hintStyle: TextStyle(color: p.textMuted),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.danger, width: 1.6),
          ),
        ),
      ),
    );
  }
}
