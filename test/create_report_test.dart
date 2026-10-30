import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/core/uploads.dart';
import 'package:tideline_mobile/screens/create_report_screen.dart';

void main() {
  test('validators accept good input and reject bad input', () {
    expect(requiredText('  ', 'a title', 120), isNotNull);
    expect(requiredText('Oil on beach', 'a title', 120), isNull);
    expect(requiredText('x' * 121, 'a title', 120), isNotNull);
    expect(validateCoordinate('7.2', 'Latitude', 90), isNull);
    expect(validateCoordinate('91', 'Latitude', 90), isNotNull);
    expect(validateCoordinate('abc', 'Longitude', 180), isNotNull);
    expect(checkPhoto('a.JPG', 100), isNull);
    expect(checkPhoto('a.gif', 100), isNotNull);
    expect(checkPhoto('a.png', maxPhotoBytes + 1), isNotNull);
  });

  test('postMultipart sends token, JSON data part and evidence part', () async {
    FlutterSecureStorage.setMockInitialValues({});
    late http.BaseRequest seen;
    late String body;
    final api = ApiClient(
      client: MockClient.streaming((req, stream) async {
        seen = req;
        body = utf8.decode(await stream.expand((c) => c).toList());
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"id":1,"reference":"TL-1"}')),
          201,
        );
      }),
    );
    await api.setToken('t0ken', remember: false);

    final res = await api.postMultipart(
      '/api/reports',
      json: {'title': 'x'},
      files: [
        http.MultipartFile.fromBytes('evidence', [1, 2, 3], filename: 'a.png'),
      ],
    );

    expect(res['reference'], 'TL-1');
    expect(seen.headers['Authorization'], 'Bearer t0ken');
    expect(seen.headers['content-type'], startsWith('multipart/form-data'));
    expect(body, contains('name="data"'));
    expect(body, contains('application/json'));
    expect(body, contains('{"title":"x"}'));
    expect(body, contains('name="evidence"; filename="a.png"'));
  });

  testWidgets('empty form shows validation errors and sends nothing', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var calls = 0;
    final auth = AuthController(
      ApiClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 201);
        }),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: CreateReportScreen(auth: auth)));
    await tester.tap(find.text('Submit report'));
    await tester.pump();

    expect(find.text('Enter a title.'), findsOneWidget);
    expect(find.text('Enter a description.'), findsOneWidget);
    expect(find.text('Choose a severity.'), findsOneWidget);
    expect(calls, 0);
  });
}
