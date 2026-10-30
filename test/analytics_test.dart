import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tideline_mobile/models/models.dart';
import 'package:tideline_mobile/screens/analytics_screen.dart';
import 'package:tideline_mobile/widgets/common.dart';

import 'helpers.dart';

/// A response shaped like AnalyticsDtos.SummaryResponse.
Map<String, Object?> summaryJson({String? district, int? accounts = 3}) => {
  'generatedAt': DateTime.now().toUtc().toIso8601String(),
  'district': district,
  'province': district == null ? null : 'Southern Province',
  'reportedSites': 41,
  'verifiedIncidents': 2,
  'communityVerified': 17,
  'escalatedReports': 4,
  'activeProjects': 6,
  'completedProjects': 9,
  'registeredVolunteers': 120,
  'wasteRemovedKg': 312.5,
  'peopleJoined': 58,
  'awaitingResources': 1,
  'readyToRun': 2,
  'accountsAwaitingVerification': ?accounts,
  'reportsByStatus': {'PENDING': 5, 'VERIFIED': 2, 'ESCALATED': 4},
  'projectsByStage': {
    'Waiting for resources': 1,
    'Gathering people': 3,
    'Ready to run': 2,
    'Completed': 9,
  },
  'helpCallAnswers': {'Joined': 7, 'Ignored': 2, 'No answer yet': 1},
  // Place names as typed (kept for older clients) …
  'topLocations': [
    {'name': 'Galle Fort', 'count': 1},
    {'name': 'Galle Town', 'count': 1},
    {'name': 'Negombo beach', 'count': 3},
  ],
  // … and the same reports per recorded district, which the chart shows.
  'districtBreakdown': [
    {'name': 'Gampaha', 'count': 3},
    {'name': 'Galle', 'count': 2},
  ],
  'reportsWithoutDistrict': 1,
  'provinceBreakdown': [
    {'name': 'Southern Province', 'count': 23},
  ],
};

Widget _app(Widget child) => MaterialApp(home: child);

void main() {
  test('Summary reads every figure the endpoint returns', () {
    final s = Summary.fromJson(summaryJson(district: 'Galle'));
    expect(s.district, 'Galle');
    expect(s.province, 'Southern Province');
    expect(s.accountsAwaitingVerification, 3);
    expect(s.wasteRemovedKg, 312.5);
    expect(s.projectsByStage.keys.first, 'Waiting for resources');
    expect(s.helpCallAnswers['Joined'], 7);
    expect(s.provinceBreakdown.single.count, 23);
  });

  test('a withheld account queue is null, not a made-up zero', () {
    final s = Summary.fromJson(summaryJson(accounts: null));
    expect(s.accountsAwaitingVerification, isNull);
  });

  testWidgets('shows the same sections as the website', (tester) async {
    tallScreen(tester, height: 4000);
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json(summaryJson()),
    });
    await tester.pumpWidget(
      _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open reports'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('312.5 kg'), findsOneWidget);
    expect(find.text('Registered members'), findsOneWidget);
    expect(find.text('Accounts waiting to be verified'), findsOneWidget);
    expect(find.text('Cleanup projects'), findsOneWidget);
    expect(find.text('Gathering people'), findsOneWidget);
    expect(
      find.text('10 sent to people living near a cleanup.'),
      findsOneWidget,
    );
    expect(find.text('Reports by province'), findsOneWidget);
    expect(find.text('Galle district'), findsOneWidget);
  });

  testWidgets('leaves out the account queue when the server withholds it', (
    tester,
  ) async {
    tallScreen(tester, height: 4000);
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json(summaryJson(accounts: null)),
    });
    await tester.pumpWidget(_app(AnalyticsScreen(auth: signedIn(api))));
    await tester.pumpAndSettle();
    expect(find.text('Accounts waiting to be verified'), findsNothing);
    expect(find.text('Reports waiting for an administrator'), findsOneWidget);
  });

  testWidgets('choosing a district asks the server for that district', (
    tester,
  ) async {
    tallScreen(tester, height: 4000);
    final districts = <String?>[];
    final api = FakeApi({
      'GET /api/analytics/summary': (http.Request req) {
        final d = req.url.queryParameters['district'];
        districts.add(d);
        return json(summaryJson(district: d));
      },
    });
    await tester.pumpWidget(
      _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Every district'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galle district').last);
    await tester.pumpAndSettle();

    expect(districts, [null, 'Galle']);
    expect(find.textContaining('counted for Galle district'), findsOneWidget);
    expect(find.textContaining('Southern Province'), findsWidgets);
  });

  testWidgets(
    'a failed first load offers Try again; a failed refresh keeps the figures',
    (tester) async {
      tallScreen(tester, height: 4000);
      var fail = true;
      final api = FakeApi({
        'GET /api/analytics/summary': (_) => fail
            ? json({'message': 'Database is busy.'}, 500)
            : json(summaryJson()),
      });
      await tester.pumpWidget(
        _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Database is busy.'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('41'), findsOneWidget);

      fail = true;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(
        find.text('41'),
        findsOneWidget,
        reason: 'old figures stay visible',
      );
      expect(find.textContaining('Could not refresh'), findsOneWidget);
    },
  );

  testWidgets('refreshes itself every minute', (tester) async {
    tallScreen(tester, height: 4000);
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json(summaryJson()),
    });
    await tester.pumpWidget(
      _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
    );
    await tester.pumpAndSettle();
    expect(api.count('GET /api/analytics/summary'), 1);

    await tester.pump(AnalyticsScreen.refreshEvery);
    await tester.pumpAndSettle();
    expect(api.count('GET /api/analytics/summary'), 2);
  });

  testWidgets('fits a narrow phone screen without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json(summaryJson(district: 'Galle')),
    });
    await tester.pumpWidget(
      _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('With the government officer'), findsOneWidget);
  });

  testWidgets(
    'Reports by location shows one row per district, never place names',
    (tester) async {
      tallScreen(tester, height: 4000);
      final api = FakeApi({
        'GET /api/analytics/summary': (_) => json(summaryJson()),
      });
      await tester.pumpWidget(
        _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gampaha district'), findsOneWidget);
      expect(find.text('Galle district'), findsOneWidget);
      expect(find.text('District not recorded'), findsOneWidget);
      for (final place in [
        'Galle Fort',
        'Galle Town',
        'Negombo beach',
        'Negombo',
      ]) {
        expect(
          find.text(place),
          findsNothing,
          reason: '$place is not a district',
        );
      }

      // Bars are scaled to the biggest district: Gampaha 3 → full, Galle 2 → 2/3, unknown 1 → 1/3.
      double bar(String label) {
        final row = find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first;
        final indicator = tester.widget<LinearProgressIndicator>(
          find.descendant(
            of: row,
            matching: find.byType(LinearProgressIndicator),
          ),
        );
        return indicator.value!;
      }

      expect(bar('Gampaha district'), 1.0);
      expect(bar('Galle district'), closeTo(2 / 3, 1e-9));
      expect(bar('District not recorded'), closeTo(1 / 3, 1e-9));
    },
  );

  test('district totals are read from the summary', () {
    final s = Summary.fromJson(summaryJson());
    expect(s.districtBreakdown.map((d) => (d.name, d.count)), [
      ('Gampaha', 3),
      ('Galle', 2),
    ]);
    expect(s.reportsWithoutDistrict, 1);
    // A mostly-empty but correctly shaped response is fine.
    expect(Summary.fromJson({'reportedSites': 0}).districtBreakdown, isEmpty);
  });

  testWidgets('lays out on a tablet without overflowing', (tester) async {
    tester.view.physicalSize = const Size(1024, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json(summaryJson(district: 'Galle')),
    });
    await tester.pumpWidget(
      _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Four stat cards fit on the first row at this width; the fifth starts a new row.
    double cardTop(String label) => tester
        .getTopLeft(
          find
              .ancestor(of: find.text(label), matching: find.byType(TLCard))
              .first,
        )
        .dy;
    final first = cardTop('Open reports');
    expect(cardTop('With the government officer'), first);
    expect(cardTop('Registered members'), greaterThan(first));
  });

  testWidgets('every section is empty-safe when the district has no data', (
    tester,
  ) async {
    tallScreen(tester, height: 4000);
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json({
        'reportedSites': 0,
        'reportsByStatus': {'PENDING': 0, 'VERIFIED': 0},
        'projectsByStage': {'Completed': 0},
        'helpCallAnswers': {'Joined': 0, 'Ignored': 0, 'No answer yet': 0},
        'districtBreakdown': [],
        'provinceBreakdown': [],
        'topLocations': [],
        'reportsWithoutDistrict': 0,
      }),
    });
    await tester.pumpWidget(
      _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No reports recorded yet.'), findsNWidgets(2));
    expect(find.text('No calls for help have gone out yet.'), findsOneWidget);
  });

  group('Open reports by status (vertical columns)', () {
    FakeApi api0() => FakeApi({
      'GET /api/analytics/summary': (_) => json({
        ...summaryJson(),
        'reportsByStatus': {
          'PENDING': 5,
          'VERIFYING': 0,
          'VERIFIED': 2,
          'ESCALATED': 4,
          'REJECTED': 0,
        },
      }),
    });

    double barHeight(WidgetTester tester, String label) =>
        tester.getSize(find.byKey(ValueKey('status-bar-$label'))).height;

    testWidgets('bars are scaled to the tallest status; a zero keeps a stub', (
      tester,
    ) async {
      tallScreen(tester, height: 4000);
      await tester.pumpWidget(
        _app(AnalyticsScreen(auth: signedIn(api0(), role: 'ADMIN'))),
      );
      await tester.pumpAndSettle();

      expect(barHeight(tester, 'Pending'), 100); // 5 of 5
      expect(barHeight(tester, 'With government officer'), 80); // 4 of 5
      expect(barHeight(tester, 'Verified'), 40); // 2 of 5
      expect(
        barHeight(tester, 'Verifying'),
        6,
      ); // 0 still drawn, as on the website
      expect(barHeight(tester, 'Rejected'), 6);
      // The counts sit above the bars and the labels below.
      for (final label in ['Pending', 'Verifying', 'Verified', 'Rejected']) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('With government officer'), findsOneWidget);
    });

    testWidgets('all-zero data draws stubs rather than dividing by zero', (
      tester,
    ) async {
      tallScreen(tester, height: 4000);
      final api = FakeApi({
        'GET /api/analytics/summary': (_) => json({
          ...summaryJson(),
          'reportsByStatus': {'PENDING': 0, 'VERIFIED': 0},
        }),
      });
      await tester.pumpWidget(
        _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(barHeight(tester, 'Pending'), 6);
      expect(barHeight(tester, 'Verified'), 6);
    });

    testWidgets('five columns fit the narrowest phone without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(AnalyticsScreen(auth: signedIn(api0(), role: 'ADMIN'))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Neighbouring labels do not overlap.
      final a = tester.getRect(find.text('Pending').last);
      final b = tester.getRect(find.text('Verifying').last);
      expect(a.right, lessThanOrEqualTo(b.left));
    });

    testWidgets('no statuses at all shows the empty message', (tester) async {
      tallScreen(tester, height: 4000);
      final api = FakeApi({
        'GET /api/analytics/summary': (_) =>
            json({...summaryJson(), 'reportsByStatus': <String, Object?>{}}),
      });
      await tester.pumpWidget(
        _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('No reports recorded yet.'), findsOneWidget);
    });
  });

  testWidgets('header has the district filter and a labelled Refresh button', (
    tester,
  ) async {
    tallScreen(tester, height: 4000);
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json(summaryJson()),
    });
    await tester.pumpWidget(
      _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administrator console'), findsOneWidget);
    expect(find.text('Every district'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Refresh'), findsOneWidget);
    expect(api.count('GET /api/analytics/summary'), 1);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Refresh'));
    await tester.pumpAndSettle();
    expect(api.count('GET /api/analytics/summary'), 2);
  });

  testWidgets('officers see their own console name', (tester) async {
    tallScreen(tester, height: 4000);
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json(summaryJson(accounts: null)),
    });
    await tester.pumpWidget(
      _app(AnalyticsScreen(auth: signedIn(api, role: 'AUTHORITY'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Government officer console'), findsOneWidget);
  });

  testWidgets('waste removed shows the number with its kg unit', (
    tester,
  ) async {
    tallScreen(tester, height: 4000);
    final api = FakeApi({
      'GET /api/analytics/summary': (_) => json(summaryJson()),
    });
    await tester.pumpWidget(
      _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Waste removed'), findsOneWidget);
    expect(find.text('312.5 kg'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets(
    'an analytics response in the wrong shape is an error with retry, never zeros',
    (tester) async {
      tallScreen(tester, height: 4000);
      // What an older backend sends: no reportedSites, a different structure.
      final api = FakeApi({
        'GET /api/analytics/summary': (_) => json({
          'totals': {'reports': 0, 'projects': 0},
          'reportStages': [],
        }),
      });
      await tester.pumpWidget(
        _app(AnalyticsScreen(auth: signedIn(api, role: 'ADMIN'))),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('unexpected format'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(
        find.text('Open reports'),
        findsNothing,
        reason: 'no cards of zeros',
      );
    },
  );

  test('Summary refuses a response without the core figures', () {
    expect(() => Summary.fromJson({}), throwsFormatException);
    expect(
      () => Summary.fromJson({'reportedSites': 'many'}),
      throwsFormatException,
    );
  });
}
