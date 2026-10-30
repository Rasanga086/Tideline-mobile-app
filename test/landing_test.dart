import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/main.dart';
import 'package:tideline_mobile/screens/landing_screen.dart';
import 'package:tideline_mobile/screens/projects_screen.dart';
import 'package:tideline_mobile/screens/report_detail_screen.dart';
import 'package:tideline_mobile/screens/reset_password_screen.dart';

import 'helpers.dart';

Map<String, Object?> _project() => {
  'id': 7,
  'reference': 'PRJ-7',
  'title': 'Mount Lavinia sweep',
  'description': 'Beach cleanup',
  'status': 'ACTIVE',
  'completionPercentage': 40,
  'owner': {'id': 99, 'fullName': 'Owner'},
  'resources': {'finalized': true},
};

/// The public endpoints the front page reads; no token is involved.
FakeApi _publicApi({bool summaryFails = false}) => FakeApi({
  'GET /api/analytics/summary': (_) => summaryFails
      ? json({'message': 'down'}, 500)
      : json({
          'reportedSites': 41,
          'activeProjects': 6,
          'completedProjects': 9,
          'registeredVolunteers': 120,
        }),
  'GET /api/reports': (_) => json({
    'content': [reportJson()],
    'last': true,
    'totalElements': 1,
  }),
  'GET /api/reports/5': (_) => json(reportJson()),
  'GET /api/projects': (_) => json([_project()]),
  'GET /api/projects/7': (_) => json(_project()),
});

AuthController _guest(FakeApi api) {
  FlutterSecureStorage.setMockInitialValues({});
  return AuthController(ApiClient(client: api.client))..ready = true;
}

Future<void> _openLanding(WidgetTester tester, AuthController auth) async {
  await tester.pumpWidget(MaterialApp(home: LandingScreen(auth: auth)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the live figures and the latest report', (tester) async {
    tallScreen(tester, height: 7000);
    final api = _publicApi();
    await _openLanding(tester, _guest(api));

    expect(find.text('Our impact so far'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(
      find.text(
        '6 cleanup projects are looking for volunteers and divers right now.',
      ),
      findsOneWidget,
    );
    // In the phone preview and in the Latest list.
    expect(find.text('Oil on the beach'), findsNWidgets(2));
    expect(find.text('Nearby reports'), findsOneWidget);
    expect(find.text('How it works'.toUpperCase()), findsOneWidget);
  });

  testWidgets('figures that fail to load show a dash, never a number', (
    tester,
  ) async {
    tallScreen(tester, height: 7000);
    await _openLanding(tester, _guest(_publicApi(summaryFails: true)));
    expect(find.text('—'), findsNWidgets(4));
    expect(
      find.text('Live figures are unavailable right now.'),
      findsOneWidget,
    );
  });

  testWidgets('the Projects tab lists open cleanups', (tester) async {
    tallScreen(tester, height: 7000);
    await _openLanding(tester, _guest(_publicApi()));
    await tester.tap(find.text('Projects').first);
    await tester.pumpAndSettle();
    expect(find.text('Mount Lavinia sweep'), findsOneWidget);
  });

  testWidgets('reporting asks a guest to sign in and sends nothing', (
    tester,
  ) async {
    tallScreen(tester, height: 7000);
    final api = _publicApi();
    await _openLanding(tester, _guest(api));
    await tester.tap(find.text('Report a polluted site').last);
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(api.log.where((l) => l.startsWith('POST')), isEmpty);
  });

  testWidgets(
    'a guest can read a report, but voting and the discussion ask for sign-in',
    (tester) async {
      tallScreen(tester, height: 4000);
      final api = _publicApi();
      await tester.pumpWidget(
        MaterialApp(home: ReportDetailScreen(auth: _guest(api), reportId: 5)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Oil on the beach'), findsOneWidget);
      expect(
        find.text('Sign in to confirm or dispute this report.'),
        findsOneWidget,
      );
      expect(
        find.text('Sign in to read and join the discussion.'),
        findsOneWidget,
      );
      expect(find.text('Confirm'), findsNothing);
      expect(api.count('GET /api/reports/5/comments'), 0);
    },
  );

  testWidgets('a guest sees "Sign in to join this cleanup."', (tester) async {
    tallScreen(tester, height: 4000);
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDetailScreen(auth: _guest(_publicApi()), projectId: 7),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to join this cleanup.'), findsOneWidget);
    expect(find.text('Join this cleanup'), findsNothing);
  });

  testWidgets('signing in from a guest screen lands on the signed-in home', (
    tester,
  ) async {
    tallScreen(tester, height: 7000);
    final api = _publicApi();
    api.routes['POST /api/auth/login'] = (_) =>
        json({'token': 'tkn', 'user': userJson()});
    api.routes['GET /api/alerts/unread-count'] = (_) => json({'count': 0});
    final auth = _guest(api);
    await tester.pumpWidget(TidelineApp(auth: auth));
    await tester.pumpAndSettle();

    // Browse as a guest, then sign in from the bottom bar.
    await tester.tap(find.text('See all reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user1@example.lk',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isTrue);
    expect(find.text('Profile'), findsOneWidget); // the member tab bar
    expect(
      find.widgetWithText(TextFormField, 'Email'),
      findsNothing,
    ); // sign-in closed
  });

  group('password reset', () {
    test('accepts the emailed link or the bare code', () {
      expect(
        resetTokenFrom('http://localhost:5173/reset-password?token=abc123'),
        'abc123',
      );
      expect(resetTokenFrom('  abc123 '), 'abc123');
      expect(resetTokenFrom('https://example.lk/reset-password'), isNull);
      expect(resetTokenFrom(''), isNull);
    });

    testWidgets('sends the token and new password, then confirms', (
      tester,
    ) async {
      tallScreen(tester);
      Object? sent;
      final api = FakeApi({
        'POST /api/auth/reset-password': (http.Request req) {
          sent = req.body;
          return json({'message': 'Your password has been changed.'});
        },
      });
      await tester.pumpWidget(
        MaterialApp(home: ResetPasswordScreen(auth: _guest(api))),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reset link or code'),
        'http://localhost:5173/reset-password?token=xyz',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'newpass123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'newpass123',
      );
      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      expect(sent, contains('"token":"xyz"'));
      expect(find.text('Password changed'), findsOneWidget);
    });

    testWidgets('an expired link shows the server message', (tester) async {
      tallScreen(tester);
      final api = FakeApi({
        'POST /api/auth/reset-password': (_) => json({
          'message': 'This reset link has expired. Ask for a new one.',
        }, 400),
      });
      await tester.pumpWidget(
        MaterialApp(home: ResetPasswordScreen(auth: _guest(api))),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reset link or code'),
        'abc',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'newpass123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'newpass123',
      );
      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      expect(
        find.text('This reset link has expired. Ask for a new one.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the front page fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 7000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _openLanding(tester, _guest(_publicApi()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header menu reaches every public section', (tester) async {
    tallScreen(tester, height: 2000);
    await _openLanding(tester, _guest(_publicApi()));
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    for (final item in ['How it works', 'Impact', 'Latest', 'Projects']) {
      expect(find.text(item), findsWidgets);
    }
    await tester.tap(find.text('Impact').last);
    await tester.pumpAndSettle();
    expect(find.text('Our impact so far'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects').last);
    await tester.pumpAndSettle();
    expect(find.text('Mount Lavinia sweep'), findsOneWidget); // public Cleanups
  });

  testWidgets('the hero offers the slide action and How it works', (
    tester,
  ) async {
    tallScreen(tester, height: 7000);
    await _openLanding(tester, _guest(_publicApi()));
    expect(
      find.widgetWithText(FilledButton, 'Report a polluted site'),
      findsWidgets,
    );
    expect(find.widgetWithText(OutlinedButton, 'How it works'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'How it works'));
    await tester.pumpAndSettle();
    expect(find.text('From a photo to a clean coast'), findsOneWidget);
  });

  testWidgets('Join Tideline opens registration and Back returns', (
    tester,
  ) async {
    tallScreen(tester, height: 7000);
    await _openLanding(tester, _guest(_publicApi()));
    await tester.tap(find.text('Join Tideline').first);
    await tester.pumpAndSettle();
    expect(find.text('Our impact so far'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Our impact so far'), findsOneWidget);
  });

  testWidgets('signing out returns to the front page', (tester) async {
    tallScreen(tester, height: 7000);
    final api = _publicApi();
    api.routes['GET /api/alerts/unread-count'] = (_) => json({'count': 0});
    final auth = signedIn(api)..ready = true;
    await tester.pumpWidget(TidelineApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Our impact so far'), findsNothing);

    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('Our impact so far'), findsOneWidget);
  });
}
