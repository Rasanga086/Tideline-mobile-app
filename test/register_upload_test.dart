import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/core/uploads.dart';
import 'package:tideline_mobile/screens/register_screen.dart';

import 'helpers.dart';

final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _proofMissing = 'Attach proof of your appointment';

PickedUpload _file(String name, {int size = 1000, List<int>? bytes}) =>
    PickedUpload(
      name: name,
      size: size,
      bytes: Uint8List.fromList(bytes ?? const [0x89, 0x50, 0x4E, 0x47, 1, 2]),
    );

/// Records every request as "METHOD /path" and keeps the raw multipart body of each.
class _Api {
  final log = <String>[];
  final bodies = <String>[];
}

Future<_Api> _openAdminForm(
  WidgetTester tester,
  Future<List<PickedUpload>> Function() pick,
) async {
  tallScreen(tester, height: 3600);
  FlutterSecureStorage.setMockInitialValues({});
  final api = _Api();
  final auth = AuthController(
    ApiClient(
      client: MockClient.streaming((req, body) async {
        api.log.add('${req.method} ${req.url.path}');
        api.bodies.add(latin1.decode(await body.expand((c) => c).toList()));
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'user': userJson(role: 'ADMIN'),
                'expiresInSeconds': 3600,
              }),
            ),
          ),
          201,
        );
      }),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: RegisterScreen(auth: auth, pickFiles: pick),
    ),
  );
  await tester.tap(find.text('Administrator'));
  await tester.pump();
  for (final (label, value) in [
    ('First name', 'Asha'),
    ('Last name', 'Silva'),
    ('Email', 'asha@example.lk'),
    ('NIC number', '991234567V'),
    ('Password', 'password1'),
    ('Department or agency', 'Tideline operations team'),
  ]) {
    await tester.enterText(find.widgetWithText(TextFormField, label), value);
  }
  return api;
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  // The multipart stream is real async work, so give it real time to finish.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _addFiles(WidgetTester tester) async {
  await tester.tap(find.textContaining('Add'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'administrator with no proof attached is stopped before any request',
    (tester) async {
      final api = await _openAdminForm(tester, () async => []);
      await _submit(tester);
      expect(find.textContaining(_proofMissing), findsOneWidget);
      expect(api.log, isEmpty);
    },
  );

  testWidgets(
    'a picked image is listed at once and sent as a certificates part',
    (tester) async {
      final api = await _openAdminForm(
        tester,
        () async => [_file('staff-id.png')],
      );
      await _addFiles(tester);
      expect(find.text('staff-id.png'), findsOneWidget);
      await _submit(tester);
      expect(find.textContaining(_proofMissing), findsNothing);
      expect(api.log, ['POST /api/auth/register']);
      final body = api.bodies.single;
      expect(body, contains('name="certificates"'));
      expect(body, contains('filename="staff-id.png"'));
      expect(body, contains('"role":"ADMIN"'));
    },
  );

  testWidgets('a picked PDF is accepted too', (tester) async {
    final api = await _openAdminForm(
      tester,
      () async => [
        _file('letter.pdf', bytes: [0x25, 0x50, 0x44, 0x46]),
      ],
    );
    await _addFiles(tester);
    await _submit(tester);
    expect(api.bodies.single, contains('filename="letter.pdf"'));
  });

  testWidgets(
    'a wrong file type or a file over 5 MB is rejected, not attached',
    (tester) async {
      final api = await _openAdminForm(
        tester,
        () async => [
          _file('notes.txt'),
          _file('huge.png', size: 5 * 1024 * 1024 + 1),
        ],
      );
      await _addFiles(tester);
      expect(
        find.textContaining('notes.txt is not a PDF, JPG or PNG'),
        findsOneWidget,
      );
      expect(
        find.textContaining('huge.png is larger than 5 MB'),
        findsOneWidget,
      );
      await _submit(tester);
      expect(find.textContaining(_proofMissing), findsOneWidget);
      expect(api.log, isEmpty);
    },
  );

  testWidgets('at most five files can be attached', (tester) async {
    final api = await _openAdminForm(
      tester,
      () async => [for (var i = 0; i < 7; i++) _file('proof$i.png')],
    );
    await _addFiles(tester);
    expect(find.textContaining('up to 5'), findsWidgets);
    await _submit(tester);
    final body = api.bodies.single;
    expect(RegExp('name="certificates"').allMatches(body).length, 5);
  });

  testWidgets(
    'files stay attached when switching to another role that needs them',
    (tester) async {
      final api = await _openAdminForm(
        tester,
        () async => [_file('staff-id.png')],
      );
      await _addFiles(tester);
      await tester.tap(find.text('Government officer'));
      await tester.pump();
      expect(find.text('staff-id.png'), findsOneWidget);
      await _submit(tester);
      expect(api.bodies.single, contains('filename="staff-id.png"'));
    },
  );

  testWidgets(
    'the required-file message clears as soon as a valid file is attached, and returns after Remove',
    (tester) async {
      final api = await _openAdminForm(
        tester,
        () async => [_file('staff-id.png')],
      );
      await _submit(tester);
      expect(find.textContaining(_proofMissing), findsOneWidget);

      await _addFiles(tester);
      expect(find.text('staff-id.png'), findsOneWidget);
      expect(
        find.textContaining(_proofMissing),
        findsNothing,
      ); // no resubmit needed

      await tester.tap(find.byTooltip('Remove staff-id.png'));
      await tester.pumpAndSettle();
      expect(find.text('staff-id.png'), findsNothing);
      await _submit(tester);
      expect(find.textContaining(_proofMissing), findsOneWidget);
      expect(api.log, isEmpty);
    },
  );

  testWidgets('a PDF shows a PDF icon and a photo shows a thumbnail', (
    tester,
  ) async {
    await _openAdminForm(
      tester,
      () async => [
        _file('letter.pdf', bytes: [0x25, 0x50, 0x44, 0x46]),
        PickedUpload(name: 'id.png', size: 70, bytes: _tinyPng),
      ],
    );
    await _addFiles(tester);
    expect(find.text('letter.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(find.text('id.png'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a file that cannot be read is reported, not silently dropped', (
    tester,
  ) async {
    await _openAdminForm(
      tester,
      () async =>
          throw PickFailure('Could not read id.png. Try picking it again.'),
    );
    await _addFiles(tester);
    expect(find.textContaining('Could not read id.png'), findsOneWidget);
  });

  testWidgets('changing role drops the stale required-file message', (
    tester,
  ) async {
    await _openAdminForm(tester, () async => []);
    await _submit(tester);
    expect(find.textContaining(_proofMissing), findsOneWidget);
    await tester.tap(find.text('Community member'));
    await tester.pump();
    expect(find.textContaining(_proofMissing), findsNothing);
  });

  test('a name with no extension is typed from the file content', () {
    expect(sniffDocumentExtension([0xFF, 0xD8, 0xFF, 0xE0]), 'jpg');
    expect(sniffDocumentExtension([0x25, 0x50, 0x44, 0x46, 0x2D]), 'pdf');
    expect(sniffDocumentExtension([0x89, 0x50, 0x4E, 0x47]), 'png');
    expect(sniffDocumentExtension([0x47, 0x49, 0x46]), isNull);
  });
}
