import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/models/models.dart';
import 'package:tideline_mobile/screens/home_shell.dart';

const _user = {
  'id': 1,
  'fullName': 'Hiruna Perera',
  'email': 'hiruna@example.lk',
  'role': 'DIVER',
  'province': 'Western Province',
  'city': 'Colombo',
};
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

/// A signed-in controller whose API answers from [routes] (path -> JSON body).
AuthController _auth(Map<String, Object> routes) {
  FlutterSecureStorage.setMockInitialValues({});
  final auth = AuthController(
    ApiClient(
      client: MockClient((req) async {
        final body = routes[req.url.path];
        if (body == null) {
          return http.Response('{"message":"Server down"}', 500);
        }
        return http.Response(jsonEncode(body), 200);
      }),
    ),
  );
  auth.user = AppUser.fromJson(_user);
  return auth;
}

void main() {
  testWidgets(
    'tabs switch, cleanups load from the API, profile shows the user and signs out',
    (tester) async {
      final auth = _auth({
        '/api/reports': {'content': []},
        '/api/projects': [_project],
      });
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: HomeShell(auth: auth)));
      await tester.pumpAndSettle();
      expect(find.text('Nearby reports'), findsOneWidget);

      await tester.tap(find.text('Cleanups'));
      await tester.pumpAndSettle();
      expect(find.text('Mount Lavinia sweep'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Hiruna Perera'), findsOneWidget);
      expect(find.text('hiruna@example.lk'), findsOneWidget);

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Sign out'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isFalse);
    },
  );

  testWidgets('cleanups error shows a retry button', (tester) async {
    final auth = _auth({
      '/api/reports': {'content': []},
    });
    await tester.pumpWidget(MaterialApp(home: HomeShell(auth: auth)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleanups'));
    await tester.pumpAndSettle();
    expect(find.text('Server down'), findsOneWidget);
    expect(find.text('Try again'), findsWidgets);
  });

  testWidgets('empty cleanups list shows the empty state', (tester) async {
    final auth = _auth({
      '/api/reports': {'content': []},
      '/api/projects': [],
    });
    await tester.pumpWidget(MaterialApp(home: HomeShell(auth: auth)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleanups'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No cleanups here yet'), findsOneWidget);
  });
}
