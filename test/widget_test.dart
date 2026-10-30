import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('signed-out users land on the front page and can open Sign in', (
    tester,
  ) async {
    tallScreen(tester, height: 6000);
    FlutterSecureStorage.setMockInitialValues({});
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json({'reportedSites': 7}),
      'GET /api/reports': (_) => json({'content': [], 'last': true}),
      'GET /api/projects': (_) => json([]),
      'GET /api/auth/demo-accounts': (_) => json([]),
    });
    final auth = AuthController(ApiClient(client: api.client));
    await auth.init();

    await tester.pumpWidget(TidelineApp(auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('Join Tideline'), findsWidgets);
    await tester.tap(find.text('Sign in').first);
    await tester.pumpAndSettle();
    // The sign-in form is shown. The Demo Accounts list comes from the server, so with none
    // offered it says so; no email addresses or shared password are built into the app.
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.text('Demo Accounts'), findsOneWidget);
    expect(find.text('No demo accounts available.'), findsOneWidget);
    expect(find.textContaining('password123'), findsNothing);
    expect(find.text('hiruna@example.lk'), findsNothing);
    expect(find.text('admin@tideline.lk'), findsNothing);
  });
}
