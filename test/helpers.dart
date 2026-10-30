import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/models/models.dart';

typedef Handler = http.Response Function(http.Request request);

/// A fake API: routes are keyed "METHOD /path". Every request is recorded in [log]
/// (as "METHOD /path") with its decoded JSON body in [bodies] when it had one.
class FakeApi {
  FakeApi(this.routes);
  final Map<String, Handler> routes;
  final List<String> log = [];
  final List<Object?> bodies = [];

  MockClient get client => MockClient((req) async {
    final key = '${req.method} ${req.url.path}';
    log.add(key);
    Object? body;
    if (req.body.isNotEmpty) {
      try {
        body = jsonDecode(req.body);
      } catch (_) {
        body = req.body;
      }
    }
    bodies.add(body);
    final handler = routes[key];
    if (handler == null) {
      return http.Response('{"message":"Unhandled $key"}', 404);
    }
    return handler(req);
  });

  int count(String key) => log.where((l) => l == key).length;
}

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, Object?> userJson({
  String role = 'CITIZEN',
  int id = 1,
  String name = 'Hiruna Perera',
}) => {
  'id': id,
  'fullName': name,
  'firstName': name.split(' ').first,
  'lastName': name.split(' ').last,
  'email': 'user$id@example.lk',
  'role': role,
  'accountStatus': 'APPROVED',
  'province': 'Western Province',
  'city': 'Colombo',
};

AuthController signedIn(FakeApi api, {String role = 'CITIZEN', int id = 1}) {
  FlutterSecureStorage.setMockInitialValues({});
  final auth = AuthController(ApiClient(client: api.client));
  auth.user = AppUser.fromJson(userJson(role: role, id: id));
  return auth;
}

/// Tall viewport so lazy lists build everything the test taps.
void tallScreen(WidgetTester tester, {double height = 2400}) {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Map<String, Object?> reportJson({
  int id = 5,
  String status = 'VERIFIED',
  String title = 'Oil on the beach',
  String? adminDecision,
}) => {
  'id': id,
  'reference': 'TL-$id',
  'title': title,
  'description': 'Black oil washing ashore',
  'severity': 'HIGH',
  'status': status,
  'locationName': 'Negombo',
  'province': 'Western Province',
  'latitude': 7.2,
  'longitude': 79.8,
  'reporter': {'id': 2, 'fullName': 'Reporter One'},
  'photoUrls': <String>[],
  'evidence': <Object>[],
  'confirmVotes': 5,
  'disputeVotes': 0,
  'trustPercentage': 100,
  'thresholdPercent': 75,
  'minimumConfirmations': 5,
  'adminDecision': adminDecision,
};
