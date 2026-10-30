import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/models/models.dart';
import 'package:tideline_mobile/screens/console_shell.dart';
import 'package:tideline_mobile/screens/home_shell.dart';

const _project = {
  'id': 7,
  'reference': 'PRJ-7',
  'title': 'Mount Lavinia sweep',
  'description': 'Beach cleanup',
  'status': 'ACTIVE',
  'completionPercentage': 40,
  'locationName': 'Mount Lavinia',
  'volunteerCount': 3,
  'diverCount': 1,
};

/// Reports and projects answer; anything else is a server error, which the screens show inline.
AuthController _auth({String? role}) {
  FlutterSecureStorage.setMockInitialValues({});
  final auth = AuthController(
    ApiClient(
      client: MockClient((req) async {
        final body = switch (req.url.path) {
          '/api/reports' => {'content': []},
          '/api/projects' => [_project],
          _ => null,
        };
        return body == null
            ? http.Response('{"message":"Server down"}', 500)
            : http.Response(jsonEncode(body), 200);
      }),
    ),
  );
  if (role != null) {
    auth.user = AppUser.fromJson({
      'id': 1,
      'fullName': 'Hiruna Perera',
      'email': 'hiruna@example.lk',
      'role': role,
      'province': 'Western Province',
      'city': 'Colombo',
    });
  }
  return auth;
}

int _tab(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Finder get _cleanupsBack => find.descendant(
  of: find.widgetWithText(AppBar, 'Cleanups'),
  matching: find.byType(BackButton),
);

/// The Android back key and the browser's back button both arrive as a route pop.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('member: Cleanups app bar back arrow returns to the Feed', (
    tester,
  ) async {
    await _open(tester, HomeShell(auth: _auth(role: 'DIVER')));
    expect(_cleanupsBack, findsNothing);

    await _tapTab(tester, 'Cleanups');
    expect(_tab(tester), 1);
    expect(_cleanupsBack, findsOneWidget);

    await tester.tap(_cleanupsBack);
    await tester.pumpAndSettle();
    expect(_tab(tester), 0);
    expect(_cleanupsBack, findsNothing);
  });

  testWidgets(
    'member: system/browser back walks the visited tabs without repeats',
    (tester) async {
      await _open(tester, HomeShell(auth: _auth(role: 'DIVER')));
      await _tapTab(tester, 'Cleanups'); // 1
      await _tapTab(tester, 'Profile'); // 4
      await _tapTab(tester, 'Cleanups'); // 1 again: not stacked twice
      await _tapTab(tester, 'Cleanups'); // same tab: ignored

      await _systemBack(tester);
      expect(_tab(tester), 4);
      await _systemBack(tester);
      expect(_tab(tester), 0);
      // Nothing earlier: the shell stays (at the root the platform handles it, as before).
      await _systemBack(tester);
      expect(_tab(tester), 0);
      expect(find.byType(HomeShell), findsOneWidget);
    },
  );

  testWidgets('member: Cleanups filter survives leaving and coming back', (
    tester,
  ) async {
    await _open(tester, HomeShell(auth: _auth(role: 'DIVER')));
    await _tapTab(tester, 'Cleanups');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Feed');
    await _systemBack(tester);
    expect(_tab(tester), 1);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Completed'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets(
    'member: back on a cleanup\'s detail page closes only that page',
    (tester) async {
      await _open(tester, HomeShell(auth: _auth(role: 'DIVER')));
      await _tapTab(tester, 'Cleanups');
      await tester.tap(find.text('Mount Lavinia sweep'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);

      await _systemBack(tester);
      expect(_tab(tester), 1);
      expect(find.text('Mount Lavinia sweep'), findsOneWidget);
    },
  );

  testWidgets('console: Cleanups back returns to the review queue', (
    tester,
  ) async {
    await _open(tester, ConsoleShell(auth: _auth(role: 'ADMIN')));
    await _tapTab(tester, 'Cleanups');
    expect(_cleanupsBack, findsOneWidget);
    await tester.tap(_cleanupsBack);
    await tester.pumpAndSettle();
    expect(_tab(tester), 0);

    await _tapTab(tester, 'Cleanups');
    await _systemBack(tester);
    expect(_tab(tester), 0);
  });

  testWidgets('guest: Cleanups opened from the front page goes back to it', (
    tester,
  ) async {
    final auth = _auth();
    await _open(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GuestShell(auth: auth, initialTab: 1),
              ),
            ),
            child: const Text('Front page'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Front page'));
    await tester.pumpAndSettle();
    expect(_tab(tester), 1);

    // Straight back from where the guest arrived: the front page.
    await _systemBack(tester);
    expect(find.byType(GuestShell), findsNothing);
    await tester.tap(find.text('Front page'));
    await tester.pumpAndSettle();

    // Feed, then Cleanups again: back returns to the Feed tab first, then the front page.
    // (Cleanups is listed once in the history, so it is not repeated.)
    await _tapTab(tester, 'Feed');
    await _tapTab(tester, 'Cleanups');
    await tester.tap(_cleanupsBack);
    await tester.pumpAndSettle();
    expect(_tab(tester), 0);
    await _systemBack(tester);
    expect(find.byType(GuestShell), findsNothing);
    expect(find.text('Front page'), findsOneWidget);
  });
}
