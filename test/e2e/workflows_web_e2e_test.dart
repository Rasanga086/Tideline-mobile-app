// End-to-end checks of the main workflows against a REAL running backend, from inside Chrome
// (so every request goes through the browser, CORS included), using the app's own ApiClient,
// AuthController and models. Not part of a plain `flutter test`.
//
// Run against a disposable backend with the demo data seeded, never your everyday database:
//   flutter test --platform chrome test/e2e \
//     --dart-define=API_BASE_URL=http://localhost:8093
//
// It signs in as the seeded demo accounts and adds a report, a comment and a vote.
@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/core/config.dart';
import 'package:tideline_mobile/models/models.dart';

// Password of the seeded demo accounts on your disposable test API: --dart-define=E2E_PASSWORD=...
const _password = String.fromEnvironment('E2E_PASSWORD');
const _diver = 'hiruna@example.lk';
const _admin = 'admin@tideline.lk';

// A real 1×1 PNG: the server checks file content, not just the name.
final _png = Uint8List.fromList([
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  2, //
  0,
  0,
  0,
  144,
  119,
  83,
  222,
  0,
  0,
  0,
  12,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  207,
  192,
  0,
  0,
  3,
  1, 1, 0, 201, 254, 146, 239, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

Matcher _status(int status) =>
    isA<ApiException>().having((e) => e.status, 'status', status);

Future<AuthController> _signIn(String email) async {
  final auth = AuthController(ApiClient());
  await auth.login(email, _password, false);
  return auth;
}

void main() {
  setUpAll(() {
    expect(
      const String.fromEnvironment('API_BASE_URL'),
      isNotEmpty,
      reason: 'pass --dart-define=API_BASE_URL=... for a disposable backend',
    );
    // ignore: avoid_print
    print('E2E against ${AppConfig.apiBaseUrl}');
  });

  test('a guest reads the public pages, but not the discussion', () async {
    final api = ApiClient();
    final summary = Summary.fromJson(
      await api.get('/api/analytics/summary', auth: false)
          as Map<String, dynamic>,
    );
    expect(summary.reportsByStatus, isNotEmpty);
    expect(summary.accountsAwaitingVerification, isNull);

    final page =
        await api.get('/api/reports', query: {'size': '5'}, auth: false)
            as Map<String, dynamic>;
    final reports = (page['content'] as List)
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(reports, isNotEmpty);

    final detail = ReportDetail.fromJson(
      await api.get('/api/reports/${reports.first.id}', auth: false)
          as Map<String, dynamic>,
    );
    expect(detail.report.id, reports.first.id);

    final projects = (await api.get('/api/projects', auth: false) as List)
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(projects, isNotEmpty);

    await expectLater(
      api.get('/api/reports/${reports.first.id}/comments', auth: false),
      throwsA(_status(401)),
    );
  });

  test('a member reports a site with a photo, comments and votes', () async {
    final auth = await _signIn(_diver);
    final api = auth.api;
    expect(auth.user!.role, 'DIVER');

    // Same body and parts as CreateReportScreen.
    final created = Report.fromJson(
      await api.postMultipart(
            '/api/reports',
            json: {
              'title': 'E2E plastic at the river mouth',
              'description': 'Bottles and nets caught on the rocks.',
              'severity': 'MEDIUM',
              'locationName': 'Negombo',
              'province': 'Western Province',
              'district': 'Gampaha',
              'latitude': 7.2083,
              'longitude': 79.8358,
              'willLeadCleanup': false,
            },
            files: [
              http.MultipartFile.fromBytes(
                'evidence',
                _png,
                filename: 'site.png',
              ),
            ],
          )
          as Map<String, dynamic>,
    );
    expect(created.status, 'PENDING');

    final detail = ReportDetail.fromJson(
      await api.get('/api/reports/${created.id}') as Map<String, dynamic>,
    );
    expect(detail.evidence, isNotEmpty, reason: 'the photo was stored');

    await api.post(
      '/api/reports/${created.id}/comments',
      body: {'body': 'E2E: still there this morning.', 'parentId': null},
    );
    final comments =
        (await api.get('/api/reports/${created.id}/comments') as List)
            .map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList();
    expect(
      comments.map((c) => c.body),
      contains('E2E: still there this morning.'),
    );

    // Vote on someone else's open report; voting the same way again takes the vote back.
    final page =
        await api.get('/api/reports', query: {'size': '30'})
            as Map<String, dynamic>;
    final others = (page['content'] as List)
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .where((r) => r.status == 'PENDING' || r.status == 'VERIFYING')
        .toList();
    for (final r in others) {
      final d = ReportDetail.fromJson(
        await api.get('/api/reports/${r.id}') as Map<String, dynamic>,
      );
      if (d.reporter?.id == auth.user!.id || d.myVote != null) continue;
      final voted = ReportDetail.fromJson(
        await api.post('/api/reports/${r.id}/votes', body: {'confirmed': true})
            as Map<String, dynamic>,
      );
      expect(voted.myVote, isTrue);
      break;
    }
  });

  test('a member reads alerts, opportunities and their profile', () async {
    final auth = await _signIn(_diver);
    final api = auth.api;
    final alerts = (await api.get('/api/alerts') as List)
        .map((e) => AppAlert.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(alerts, isA<List<AppAlert>>());
    expect(
      (await api.get('/api/alerts/unread-count') as Map)['count'],
      isA<num>(),
    );

    final opportunities = (await api.get('/api/opportunities') as List)
        .map((e) => Opportunity.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(opportunities, isA<List<Opportunity>>());
    final mine = (await api.get('/api/opportunities/applications/mine') as List)
        .map((e) => Application.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(mine, isA<List<Application>>());

    await auth.refresh();
    expect(auth.user!.email, _diver);
  });

  test(
    'administrator tools are refused to members and work for administrators',
    () async {
      final member = await _signIn(_diver);
      await expectLater(
        member.api.get('/api/admin/users'),
        throwsA(_status(403)),
      );
      await expectLater(
        member.api.get('/api/admin/verifications'),
        throwsA(_status(403)),
      );

      final admin = await _signIn(_admin);
      expect(admin.user!.isOfficial, isTrue);
      final users = (await admin.api.get('/api/admin/users') as List)
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(users, isNotEmpty);
      final reviews = (await admin.api.get('/api/admin/verifications') as List)
          .map((e) => AccountReview.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(reviews, isA<List<AccountReview>>());

      final summary = Summary.fromJson(
        await admin.api.get(
              '/api/analytics/summary',
              query: {'district': 'Galle'},
            )
            as Map<String, dynamic>,
      );
      expect(summary.district, 'Galle');
      expect(summary.province, 'Southern Province');
      expect(summary.accountsAwaitingVerification, isNotNull);
    },
  );

  test(
    'a rejected token signs the app out instead of failing silently',
    () async {
      final auth = await _signIn(_diver);
      await auth.api.setToken('not.a.real.token', remember: false);
      await expectLater(auth.api.get('/api/users/me'), throwsA(_status(401)));
      expect(auth.isAuthenticated, isFalse);
    },
  );
}
