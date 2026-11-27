import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_messages.dart';
import '../theme/app_palette.dart';
import '../widgets/accessible_tap.dart';
import '../widgets/progress_dialog.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _masuk = true;
  bool _obscurePassword = true;

  /// Setelah submit pertama, error diperbarui langsung saat pengguna mengetik
  /// sehingga ia tahu kapan isiannya sudah benar.
  bool _submitted = false;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  /// Email yang sedang menunggu verifikasi tautan dari Firebase Auth.
  String? _pendingVerificationEmail;
  bool _isCheckingVerification = false;
  bool _isResendingVerification = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final pendingEmail = ref.read(authProvider.notifier).pendingVerificationEmail;
    if (pendingEmail != null && pendingEmail.trim().isNotEmpty) {
      _pendingVerificationEmail = pendingEmail.trim();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool get _busy =>
      _isSubmitting ||
      _isGoogleSubmitting ||
      _isCheckingVerification ||
      _isResendingVerification;

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  void _focusFirstInvalidField() {
    final FocusNode target;
    if (!_masuk && _name.text.trim().isEmpty) {
      target = _nameFocus;
    } else {
      final email = _email.text.trim();
      if (email.isEmpty || !_emailRegex.hasMatch(email)) {
        target = _emailFocus;
      } else {
        target = _passwordFocus;
      }
    }
    if (!target.hasFocus) {
      target.requestFocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = target.context;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 200),
          alignment: 0.3,
        );
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final messenger = AppMessenger.of(context);
    setState(() => _isGoogleSubmitting = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      final name = ref.read(authProvider)?.firstName ?? '';
      messenger.success('Berhasil masuk dengan Google. Halo, $name!');
    } on GoogleSignInCancelledException {
      if (!mounted) return;
      messenger.info('Masuk dengan Google dibatalkan.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        messenger,
        friendlyError(error,
            fallback: 'Gagal masuk dengan Google. Coba lagi.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final isLogin = _masuk;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) {
      _focusFirstInvalidField();
      return;
    }
    FocusScope.of(context).unfocus();
    final messenger = AppMessenger.of(context);
    final emailText = _email.text.trim();
    setState(() => _isSubmitting = true);
    try {
      final notifier = ref.read(authProvider.notifier);
      final AuthFlowResult result;
      if (isLogin) {
        result = await notifier.signIn(
          email: emailText,
          password: _password.text,
        );
      } else {
        result = await notifier.register(
          name: _name.text,
          email: emailText,
          password: _password.text,
        );
      }
      if (!mounted) return;
      if (result == AuthFlowResult.needsEmailVerification) {
        setState(() => _pendingVerificationEmail = emailText);
        _startResendCooldown();
        messenger.info(
          'Tautan verifikasi dikirim ke $emailText. Buka email kamu lalu konfirmasi.',
        );
        return;
      }
      final name = ref.read(authProvider)?.firstName ?? '';
      messenger.success(isLogin
          ? 'Berhasil masuk. Halo, $name!'
          : 'Akun Firebase berhasil dibuat. Selamat datang, $name!');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        messenger,
        friendlyError(error,
            fallback: 'Gagal ${isLogin ? 'masuk' : 'membuat akun'}. Coba lagi.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _checkVerification() async {
    if (_busy) return;
    final messenger = AppMessenger.of(context);
    setState(() => _isCheckingVerification = true);
    try {
      final verified =
          await ref.read(authProvider.notifier).completeEmailVerification();
      if (!mounted) return;
      if (verified) {
        final name = ref.read(authProvider)?.firstName ?? '';
        messenger.success('Email terverifikasi! Selamat datang, $name.');
      } else {
        showAppSnackBar(
          messenger,
          'Email belum terverifikasi. Klik tautan di Kotak Masuk atau folder Spam terlebih dahulu.',
          isError: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        messenger,
        friendlyError(error, fallback: 'Gagal memeriksa status verifikasi.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isCheckingVerification = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_busy || _resendCooldown > 0) return;
    final messenger = AppMessenger.of(context);
    setState(() => _isResendingVerification = true);
    try {
      await ref.read(authProvider.notifier).resendVerificationEmail();
      if (!mounted) return;
      _startResendCooldown();
      messenger.success(
          'Tautan verifikasi baru dikirim ke $_pendingVerificationEmail.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        messenger,
        friendlyError(error, fallback: 'Gagal mengirim ulang email verifikasi.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isResendingVerification = false);
    }
  }

  Future<void> _cancelVerification() async {
    if (_busy) return;
    _cooldownTimer?.cancel();
    await ref.read(authProvider.notifier).cancelPendingVerification();
    if (!mounted) return;
    setState(() {
      _pendingVerificationEmail = null;
      _resendCooldown = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: _pendingVerificationEmail != null
              ? _verificationView(p)
              : _authFormView(p),
        ),
      ),
    );
  }

  Widget _brandHeader(AppPalette p) => Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: p.primary.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/logo/pakailagi_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text('PakaiLagi',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800, color: p.text)),
          ),
          const SizedBox(height: 6),
          Text(
            'Berbagi barang bekas layak pakai, gratis untuk sesama 💚',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.textMuted, height: 1.5),
          ),
        ],
      );

  Widget _verificationView(AppPalette p) {
    final email = _pendingVerificationEmail ?? '';
    return Column(
      children: [
        _brandHeader(p),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mark_email_unread_outlined,
                    size: 30, color: p.primary),
              ),
              const SizedBox(height: 14),
              Text(
                'Verifikasi Email Kamu',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: p.text),
              ),
              const SizedBox(height: 8),
              Text(
                'Tautan verifikasi resmi telah dikirim ke:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: p.textMuted),
              ),
              const SizedBox(height: 6),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: p.primary),
              ),
              const SizedBox(height: 12),
              Text(
                'Buka kotak masuk (atau folder Spam), klik tautan verifikasi di email tersebut, lalu tekan tombol di bawah untuk masuk.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: p.textMuted, height: 1.45),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _busy ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isCheckingVerification
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: p.onAccent,
                          ),
                        )
                      : const Text(
                          'Saya Sudah Verifikasi',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed:
                      (_busy || _resendCooldown > 0) ? null : _resendVerification,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: p.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isResendingVerification
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: p.primary,
                          ),
                        )
                      : Text(
                          _resendCooldown > 0
                              ? 'Kirim Ulang (${_resendCooldown}d)'
                              : 'Kirim Ulang Email Verifikasi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _resendCooldown > 0 ? p.textMuted : p.text,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _cancelVerification,
                child: Text(
                  'Gunakan akun atau email lain',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _authFormView(AppPalette p) => Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            _brandHeader(p),
            const SizedBox(height: 28),

            // Tombol Masuk dengan Akun Google Asli
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _busy ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: p.surface,
                  foregroundColor: p.text,
                  side: BorderSide(color: p.border, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isGoogleSubmitting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: p.primary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _GoogleMark(size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Masuk dengan Google',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: p.text,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: p.border, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'atau dengan email',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: p.textMuted),
                  ),
                ),
                Expanded(child: Divider(color: p.border, height: 1)),
              ],
            ),
            const SizedBox(height: 20),

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
            const SizedBox(height: 18),

            if (!_masuk)
              _field(
                controller: _name,
                focusNode: _nameFocus,
                hint: 'Nama lengkap',
                icon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
            _field(
              controller: _email,
              focusNode: _emailFocus,
              hint: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email wajib diisi';
                }
                final ok = _emailRegex.hasMatch(v.trim());
                return ok ? null : 'Format email tidak valid';
              },
            ),
            _field(
              controller: _password,
              focusNode: _passwordFocus,
              hint: 'Kata sandi',
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              suffix: IconButton(
                tooltip: _obscurePassword
                    ? 'Tampilkan kata sandi'
                    : 'Sembunyikan kata sandi',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: p.textMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Kata sandi wajib diisi';
                }
                return v.length < 6 ? 'Kata sandi minimal 6 karakter' : null;
              },
            ),

            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                'Email wajib diverifikasi lewat tautan di kotak masuk sebelum dapat digunakan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: p.onAccent,
                        ),
                      )
                    : Text(_masuk ? 'Masuk' : 'Buat Akun',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Dengan melanjutkan, kamu menyetujui Ketentuan Layanan & Kebijakan Privasi PakaiLagi.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12.5, color: p.textMuted, height: 1.5),
            ),
          ],
        ),
      );

  Widget _modeTab(String label, bool active) {
    final p = context.palette;
    return Expanded(
      child: AccessibleTap(
        onTap: _busy
            ? null
            : () => setState(() {
                  _masuk = label == 'Masuk';
                  _submitted = false;
                }),
        label: label == 'Masuk' ? 'Mode masuk' : 'Mode daftar akun baru',
        selected: active,
        radio: true,
        borderRadius: BorderRadius.circular(10),
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
    FocusNode? focusNode,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        onFieldSubmitted: onSubmitted,
        onEditingComplete: onSubmitted != null ? () {} : null,
        scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        validator: validator,
        style: TextStyle(color: p.text),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: p.textMuted, size: 20),
          suffixIcon: suffix,
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

/// Ikon huruf "G" Google 4 warna tanpa ketergantungan aset eksternal.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _GoogleMarkPainter(),
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.19;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Merah (atas), Kuning (kiri), Hijau (bawah), Biru (kanan)
    canvas.drawArc(rect, -2.35, 1.85, false, arcPaint(const Color(0xFFEA4335)));
    canvas.drawArc(rect, 2.55, 1.38, false, arcPaint(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, 0.72, 1.85, false, arcPaint(const Color(0xFF34A853)));
    canvas.drawArc(rect, -0.08, 0.85, false, arcPaint(const Color(0xFF4285F4)));

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final midY = size.height / 2;
    canvas.drawLine(
      Offset(size.width * 0.52, midY),
      Offset(size.width - stroke * 0.15, midY),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
