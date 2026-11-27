import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:pakailagi/models/app_user.dart';
import 'package:pakailagi/providers/auth_provider.dart';
import 'package:pakailagi/screens/sign_in_screen.dart';
import 'package:pakailagi/services/firebase_auth_service.dart';
import 'package:pakailagi/services/user_messages.dart';
import 'package:pakailagi/theme/app_palette.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier({
    this.nextFlowResult = AuthFlowResult.needsEmailVerification,
    this.verifiedAfterCheck = false,
    String? initialPendingEmail,
  })  : _initialPendingEmail = initialPendingEmail,
        super.forTest();

  final AuthFlowResult nextFlowResult;
  bool verifiedAfterCheck;
  final String? _initialPendingEmail;

  int googleCalls = 0;
  int signInCalls = 0;
  int registerCalls = 0;
  int checkVerificationCalls = 0;
  int resendCalls = 0;
  int cancelCalls = 0;

  @override
  String? get pendingVerificationEmail => _initialPendingEmail;

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
    state = const AppUser(
      id: 'g1',
      name: 'Petra Google',
      email: 'petra@gmail.com',
      phone: '',
      address: '',
    );
  }

  @override
  Future<AuthFlowResult> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (nextFlowResult == AuthFlowResult.signedIn) {
      state = AppUser(
        id: 'u1',
        name: 'Budi',
        email: email.trim(),
        phone: '',
        address: '',
      );
    }
    return nextFlowResult;
  }

  @override
  Future<AuthFlowResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    if (nextFlowResult == AuthFlowResult.signedIn) {
      state = AppUser(
        id: 'u1',
        name: name.trim(),
        email: email.trim(),
        phone: '',
        address: '',
      );
    }
    return nextFlowResult;
  }

  @override
  Future<bool> completeEmailVerification() async {
    checkVerificationCalls++;
    if (!verifiedAfterCheck) return false;
    state = const AppUser(
      id: 'u1',
      name: 'Budi',
      email: 'budi@gmail.com',
      phone: '',
      address: '',
    );
    return true;
  }

  @override
  Future<void> resendVerificationEmail() async {
    resendCalls++;
  }

  @override
  Future<void> cancelPendingVerification() async {
    cancelCalls++;
    state = null;
  }
}

void main() {
  testWidgets(
      'SignInScreen menampilkan tombol Masuk dengan Google dan memanggil Google Sign-In',
      (tester) async {
    final fakeAuth = _FakeAuthNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith((_) => fakeAuth)],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppPalette.light]),
          home: const SignInScreen(),
        ),
      ),
    );

    expect(find.text('Masuk dengan Google'), findsOneWidget);
    expect(find.text('atau dengan email'), findsOneWidget);

    await tester.tap(find.text('Masuk dengan Google'));
    await tester.pumpAndSettle();

    expect(fakeAuth.googleCalls, 1);
    expect(fakeAuth.state?.email, 'petra@gmail.com');
  });

  testWidgets(
      'Masuk dengan email belum terverifikasi menahan di panel Verifikasi Email',
      (tester) async {
    final fakeAuth = _FakeAuthNotifier(
      nextFlowResult: AuthFlowResult.needsEmailVerification,
      verifiedAfterCheck: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith((_) => fakeAuth)],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppPalette.light]),
          home: const SignInScreen(),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'budi@gmail.com');
    await tester.enterText(fields.at(1), 'rahasia123');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signInCalls, 1);
    expect(fakeAuth.state, isNull);
    expect(find.text('Verifikasi Email Kamu'), findsOneWidget);
    expect(find.text('budi@gmail.com'), findsOneWidget);

    await tester.ensureVisible(find.text('Saya Sudah Verifikasi'));
    await tester.tap(find.text('Saya Sudah Verifikasi'));
    await tester.pumpAndSettle();
    expect(fakeAuth.checkVerificationCalls, 1);
    expect(fakeAuth.state, isNull);

    fakeAuth.verifiedAfterCheck = true;
    await tester.tap(find.text('Saya Sudah Verifikasi'));
    await tester.pumpAndSettle();
    expect(fakeAuth.checkVerificationCalls, 2);
    expect(fakeAuth.state?.email, 'budi@gmail.com');
  });

  test('friendlyError memetakan error Google Sign-In dengan pesan ramah', () {
    expect(
      friendlyError(
        const GoogleSignInCancelledException(),
        fallback: 'fallback',
      ),
      'Masuk dengan Google dibatalkan.',
    );
    expect(
      friendlyError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'missing sha1',
        ),
        fallback: 'fallback',
      ),
      contains('SHA-1'),
    );
  });
}

