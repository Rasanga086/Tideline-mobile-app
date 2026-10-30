import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/models/models.dart';
import 'package:tideline_mobile/screens/projects_screen.dart';

const _user = {
  'id': 1,
  'fullName': 'Hiruna Perera',
  'email': 'hiruna@example.lk',
  'role': 'DIVER',
};

Map<String, Object?> _project({
  bool joined = false,
  bool finalized = true,
  int volunteers = 3,
}) => {
  'id': 7,
  'reference': 'PRJ-7',
  'title': 'Mount Lavinia sweep',
  'description': 'Beach cleanup',
  'status': 'ACTIVE',
  'completionPercentage': 40,
  'volunteerCount': volunteers,
  'diverCount': 1,
  'joined': joined,
  'owner': {'id': 99, 'fullName': 'Owner'},
  'resources': {'finalized': finalized},
};

Future<void> _open(WidgetTester tester, MockClient client) async {
  FlutterSecureStorage.setMockInitialValues({});
  final auth = AuthController(ApiClient(client: client))
    ..user = AppUser.fromJson(_user);
  await tester.pumpWidget(
    MaterialApp(home: ProjectDetailScreen(auth: auth, projectId: 7)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'join posts to the participants endpoint and shows the joined state',
    (tester) async {
      final posts = <String>[];
      await _open(
        tester,
        MockClient((req) async {
          if (req.method == 'POST') {
            posts.add(req.url.path);
            return http.Response(
              jsonEncode(_project(joined: true, volunteers: 4)),
              200,
            );
          }
          return http.Response(jsonEncode(_project()), 200);
        }),
      );

      await tester.tap(find.text('Join this cleanup'));
      await tester.pumpAndSettle();

      expect(posts, ['/api/projects/7/participants']);
      expect(find.text('Join this cleanup'), findsNothing);
      expect(find.text('You have joined this cleanup.'), findsWidgets);
    },
  );

  testWidgets('join failure shows the server message and keeps the button', (
    tester,
  ) async {
    await _open(
      tester,
      MockClient((req) async {
        if (req.method == 'POST') {
          return http.Response(
            '{"message":"This cleanup already has everyone it needs."}',
            409,
          );
        }
        return http.Response(jsonEncode(_project()), 200);
      }),
    );

    await tester.tap(find.text('Join this cleanup'));
    await tester.pumpAndSettle();

    expect(
      find.text('This cleanup already has everyone it needs.'),
      findsOneWidget,
    );
    expect(find.text('Join this cleanup'), findsOneWidget);
  });

  testWidgets('join is closed until the officer has finalized resources', (
    tester,
  ) async {
    await _open(
      tester,
      MockClient(
        (_) async => http.Response(jsonEncode(_project(finalized: false)), 200),
      ),
    );
    expect(find.text('Join this cleanup'), findsNothing);
    expect(find.textContaining('Not open yet'), findsOneWidget);
  });

  testWidgets(
    'already-joined project shows the joined notice instead of a button',
    (tester) async {
      await _open(
        tester,
        MockClient(
          (_) async => http.Response(jsonEncode(_project(joined: true)), 200),
        ),
      );
      expect(find.text('Join this cleanup'), findsNothing);
      expect(find.text('You have joined this cleanup.'), findsOneWidget);
    },
  );
}
