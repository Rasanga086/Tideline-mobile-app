import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tideline_mobile/models/models.dart';
import 'package:tideline_mobile/screens/login_screen.dart';

import 'helpers.dart';

Widget _login(FakeApi api) =>
    MaterialApp(home: LoginScreen(auth: signedIn(api)));

Future<void> _open(WidgetTester tester, FakeApi api) async {
  tallScreen(tester);
  await tester.pumpWidget(_login(api));
  await tester.pumpAndSettle();
}

TextEditingController _controller(WidgetTester tester, String label) {
  final field = tester.widget<TextFormField>(
    find.widgetWithText(TextFormField, label),
  );
  return field.controller!;
}

void main() {
  test('only a well-formed row becomes an account', () {
    final ok = DemoAccount.tryParse({'role': 'ADMIN', 'email': ' a@x.lk '})!;
    expect(ok.email, 'a@x.lk');
    expect(ok.roleText, 'Administrator');
    expect(DemoAccount.tryParse({'role': 'ADMIN'}), isNull);
    expect(DemoAccount.tryParse({'role': 'ADMIN', 'email': '  '}), isNull);
    expect(DemoAccount.tryParse('nope'), isNull);
    expect(DemoAccount.tryParse(null), isNull);
  });

  testWidgets(
    'shows each account the server returns, with its role and email',
    (tester) async {
      final api = FakeApi({
        'GET /api/auth/demo-accounts': (_) => json([
          {'role': 'ADMIN', 'email': 'admin@one.test'},
          {'role': 'CITIZEN', 'email': 'member@one.test'},
          {'role': 'AUTHORITY', 'email': 'officer@one.test'},
          {'role': 'ORGANIZATION'}, // malformed: no email, skipped
        ]),
      });
      await _open(tester, api);

      expect(find.text('Demo Accounts'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);
      expect(find.text('admin@one.test'), findsOneWidget);
      expect(find.text('Community member'), findsOneWidget);
      expect(find.text('Government officer'), findsOneWidget);
      expect(find.text('Use account'), findsNWidgets(3));
      expect(find.text('Organisation'), findsNothing);
    },
  );

  testWidgets('sits below the Sign in button and above Create account', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /api/auth/demo-accounts': (_) => json([
        {'role': 'ADMIN', 'email': 'admin@one.test'},
      ]),
    });
    await _open(tester, api);
    final signIn = tester
        .getTopLeft(find.widgetWithText(FilledButton, 'Sign in'))
        .dy;
    final heading = tester.getTopLeft(find.text('Demo Accounts')).dy;
    final create = tester.getTopLeft(find.text('Create account')).dy;
    expect(heading, greaterThan(signIn));
    expect(heading, lessThan(create));
  });

  testWidgets('Use account fills the email only, never a password', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /api/auth/demo-accounts': (_) => json([
        {'role': 'ADMIN', 'email': 'admin@one.test'},
        {'role': 'CITIZEN', 'email': 'member@one.test'},
      ]),
    });
    await _open(tester, api);
    expect(_controller(tester, 'Email').text, isEmpty);

    await tester.tap(find.text('Use account').last);
    await tester.pumpAndSettle();
    expect(_controller(tester, 'Email').text, 'member@one.test');
    expect(_controller(tester, 'Password').text, isEmpty);

    await tester.tap(find.text('Use account').first);
    await tester.pumpAndSettle();
    expect(_controller(tester, 'Email').text, 'admin@one.test');
    expect(_controller(tester, 'Password').text, isEmpty);
    expect(find.textContaining('password123'), findsNothing);
    // Nothing was submitted by tapping it.
    expect(api.log.where((l) => l.startsWith('POST')), isEmpty);
  });

  testWidgets('a person still has to type the password and sign in normally', (
    tester,
  ) async {
    Object? sent;
    final api = FakeApi({
      'GET /api/auth/demo-accounts': (_) => json([
        {'role': 'ADMIN', 'email': 'admin@one.test'},
      ]),
      'POST /api/auth/login': (http.Request r) {
        sent = r.body;
        return json({'token': 't', 'user': userJson(role: 'ADMIN')});
      },
    });
    await _open(tester, api);
    await tester.tap(find.text('Use account'));
    await tester.pumpAndSettle();
    expect(api.count('POST /api/auth/login'), 0);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'typed-by-user1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(sent, contains('"email":"admin@one.test"'));
    expect(sent, contains('"password":"typed-by-user1"'));
  });

  testWidgets('says so when no demo accounts are available', (tester) async {
    final api = FakeApi({'GET /api/auth/demo-accounts': (_) => json([])});
    await _open(tester, api);
    expect(find.text('No demo accounts available.'), findsOneWidget);
    expect(find.text('Use account'), findsNothing);
  });

  testWidgets('a failed request shows a small note and the form still works', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /api/auth/demo-accounts': (_) => json({'message': 'down'}, 500),
    });
    await _open(tester, api);
    expect(find.textContaining("couldn't be loaded"), findsOneWidget);
    // Nothing is invented to fill the gap.
    expect(find.text('No demo accounts available.'), findsNothing);
    expect(find.text('Use account'), findsNothing);
    // The form is untouched and usable.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'me@x.test',
    );
    expect(_controller(tester, 'Email').text, 'me@x.test');
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('Try again asks once more and can succeed', (tester) async {
    var ok = false;
    final api = FakeApi({
      'GET /api/auth/demo-accounts': (_) => ok
          ? json([
              {'role': 'ADMIN', 'email': 'admin@one.test'},
            ])
          : json({'message': 'down'}, 503),
    });
    await _open(tester, api);
    ok = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('admin@one.test'), findsOneWidget);
    expect(api.count('GET /api/auth/demo-accounts'), 2);
  });

  testWidgets('asks once, and not again when the form is used', (tester) async {
    final api = FakeApi({
      'GET /api/auth/demo-accounts': (_) => json([
        {'role': 'ADMIN', 'email': 'admin@one.test'},
      ]),
    });
    await _open(tester, api);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'x@y.test',
    );
    await tester.tap(find.text('Remember me'));
    await tester.pumpAndSettle();
    expect(api.count('GET /api/auth/demo-accounts'), 1);
  });

  testWidgets('fits a narrow phone with a long email', (tester) async {
    tester.view.physicalSize = const Size(320, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi({
      'GET /api/auth/demo-accounts': (_) => json([
        {
          'role': 'ORGANIZATION',
          'email':
              'a-very-long-organisation-address@community-cleanup.example.org',
        },
      ]),
    });
    await tester.pumpWidget(_login(api));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
