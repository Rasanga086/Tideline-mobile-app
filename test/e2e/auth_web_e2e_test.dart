// End-to-end sign-up / sign-in against a REAL running backend, from inside Chrome
// (so requests go through the browser, including CORS). Not part of `flutter test`.
//
// Run against a disposable backend, never your everyday database:
//   flutter test --platform chrome test/e2e \
//     --dart-define=API_BASE_URL=http://localhost:8084
//
// Each run creates new accounts with unique e2e-*@example.test emails.
@TestOn('browser')
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/core/config.dart';

final _rand = Random();
final _run = DateTime.now().millisecondsSinceEpoch;
String _email(String tag) => 'e2e-$tag-$_run@example.test';
String _nic() =>
    List.generate(12, (_) => _rand.nextInt(10)).join(); // 12-digit NIC format

Map<String, Object?> _person(String email, String role, {String? org}) => {
  'firstName': 'Test',
  'lastName': 'Account',
  'email': email,
  'nic': _nic(),
  'password': 'e2ePassw0rd',
  'role': role,
  'organizationName': org,
};

// Smallest valid PNG: the server checks the file content, not just the name.
final _png = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0,
  0,
  0,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0,
  0,
  0,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0xDA,
  0x63,
  0xFC,
  0xCF,
  0xC0,
  0x50,
  0x0F,
  0,
  0x04,
  0x85,
  0x01,
  0x80,
  0x84,
  0xA9,
  0x8C,
  0x21,
  0,
  0,
  0,
  0,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Matcher _apiError(int status, [String? text]) => isA<ApiException>()
    .having((e) => e.status, 'status', status)
    .having((e) => e.message, 'message', contains(text ?? ''));

void main() {
  setUpAll(() {
    // Fail loudly rather than test against the emulator address by mistake.
    expect(AppConfig.apiBaseUrl, startsWith('http://localhost'));
  });

  test(
    'community member: sign up, sign in, restore after reload, sign out',
    () async {
      final email = _email('citizen');
      final auth = AuthController(ApiClient());
      await auth.init();

      final reg = await auth.register(_person(email, 'CITIZEN'));
      expect(reg.token, isNotNull);
      expect(auth.user!.email, email);
      expect(auth.user!.role, 'CITIZEN');

      await auth.logout();
      expect(auth.isAuthenticated, isFalse);

      final user = await auth.login(email, 'e2ePassw0rd', true);
      expect(user.role, 'CITIZEN');
      expect(auth.api.token, isNotNull);

      // A page reload: a fresh controller restores the remembered session.
      final reloaded = AuthController(ApiClient());
      await reloaded.init();
      expect(reloaded.user?.email, email);
      await reloaded.logout();

      final afterLogout = AuthController(ApiClient());
      await afterLogout.init();
      expect(afterLogout.isAuthenticated, isFalse);
    },
  );

  test('a duplicate email is refused', () async {
    final email = _email('dup');
    final auth = AuthController(ApiClient());
    await auth.register(_person(email, 'CITIZEN'));
    await auth.logout();
    await expectLater(
      auth.register(_person(email, 'CITIZEN')),
      throwsA(_apiError(409, 'already uses that email')),
    );
  });

  test('a wrong password fails and leaves no session', () async {
    final email = _email('pw');
    final auth = AuthController(ApiClient());
    await auth.register(_person(email, 'CITIZEN'));
    await auth.logout();
    await expectLater(
      auth.login(email, 'not-the-password1', false),
      throwsA(_apiError(401, 'Email or password is incorrect')),
    );
    expect(auth.isAuthenticated, isFalse);
    expect(auth.api.token, isNull);
  });

  test('invalid input is rejected by the server', () async {
    final auth = AuthController(ApiClient());
    await expectLater(
      auth.register({..._person(_email('bad'), 'CITIZEN'), 'email': 'nope'}),
      throwsA(_apiError(400)),
    );
  });

  test(
    'administrator: proof is required; with proof the account waits for approval',
    () async {
      final auth = AuthController(ApiClient());
      await expectLater(
        auth.register(_person(_email('admin-noproof'), 'ADMIN', org: 'Ops')),
        throwsA(_apiError(400, 'proof of your appointment')),
      );

      final email = _email('admin');
      final reg = await auth.register(
        _person(email, 'ADMIN', org: 'Tideline operations team'),
        certificates: [
          http.MultipartFile.fromBytes(
            'certificates',
            _png,
            filename: 'staff-id.png',
          ),
        ],
      );
      expect(
        reg.token,
        isNull,
        reason: 'officials get no session until approved',
      );
      expect(reg.user.role, 'ADMIN');
      expect(auth.isAuthenticated, isFalse);

      await expectLater(
        auth.login(email, 'e2ePassw0rd', false),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'ACCOUNT_PENDING'),
        ),
      );
    },
  );
}
