import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tideline_mobile/core/alerts_controller.dart';
import 'package:tideline_mobile/main.dart';
import 'package:tideline_mobile/screens/alerts_screen.dart';
import 'package:tideline_mobile/screens/console_shell.dart';
import 'package:tideline_mobile/screens/edit_profile_screen.dart';
import 'package:tideline_mobile/screens/feed_screen.dart';
import 'package:tideline_mobile/screens/login_screen.dart';
import 'package:tideline_mobile/screens/opportunities_screen.dart';
import 'package:tideline_mobile/screens/register_screen.dart';
import 'package:tideline_mobile/screens/report_detail_screen.dart';
import 'package:tideline_mobile/screens/report_review_screen.dart';

import 'helpers.dart';

Widget _app(Widget child) => MaterialApp(home: child);

void main() {
  group('registration', () {
    testWidgets(
      'login screen opens registration; an empty form is rejected without a request',
      (tester) async {
        tallScreen(tester, height: 3200);
        final api = FakeApi({});
        final auth = signedIn(api)..user = null;
        await tester.pumpWidget(_app(LoginScreen(auth: auth)));
        await tester.tap(find.text('Create account'));
        await tester.pumpAndSettle();

        expect(find.text('I am joining as'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await tester.pump();
        expect(find.text('Enter your first name.'), findsOneWidget);
        expect(find.text('Enter your email.'), findsOneWidget);
        expect(find.text('Enter your NIC number.'), findsOneWidget);
        // Opening sign-in reads the demo-accounts list; nothing is submitted to create an account.
        expect(
          api.log.where((l) => l != 'GET /api/auth/demo-accounts'),
          isEmpty,
        );
      },
    );

    testWidgets('a diver must attach a certificate before anything is sent', (
      tester,
    ) async {
      tallScreen(tester, height: 3200);
      final api = FakeApi({});
      final auth = signedIn(api)..user = null;
      await tester.pumpWidget(_app(RegisterScreen(auth: auth)));

      await tester.tap(find.text('Volunteer diver'));
      await tester.pump();
      expect(find.text('Diving certificates'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'),
        'Hiruna',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last name'),
        'Perera',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'h@example.lk',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'NIC number'),
        '991234567V',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password1',
      );
      // Certification level is required for divers.
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Certification level',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rescue Diver').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();

      expect(
        find.textContaining('Attach at least one diving certificate'),
        findsOneWidget,
      );
      expect(api.log, isEmpty);
    });
  });

  group('feed', () {
    testWidgets(
      'loads a page, "Load more" fetches the next one and filters reset the list',
      (tester) async {
        tallScreen(tester, height: 4000);
        final api = FakeApi({
          'GET /api/reports': (req) {
            final page = req.url.queryParameters['page'];
            return json({
              'content': [
                reportJson(
                  id: page == '0' ? 1 : 2,
                  title: page == '0' ? 'First' : 'Second',
                ),
              ],
              'last': page != '0',
              'totalElements': 2,
            });
          },
        });
        final auth = signedIn(api);
        await tester.pumpWidget(_app(FeedScreen(auth: auth)));
        await tester.pumpAndSettle();

        expect(find.text('First'), findsOneWidget);
        expect(find.text('Load more'), findsOneWidget);
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('Load more'), findsNothing);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Verified'));
        await tester.pumpAndSettle();
        expect(api.log.where((l) => l == 'GET /api/reports').length, 3);
        expect(find.text('Second'), findsNothing); // list restarted from page 0
      },
    );
  });

  group('report detail', () {
    testWidgets('reply sends parentId and a reaction posts the chosen type', (
      tester,
    ) async {
      tallScreen(tester, height: 4000);
      final api = FakeApi({
        'GET /api/reports/5': (_) => json(reportJson()),
        'GET /api/reports/5/comments': (_) => json([
          {
            'id': 11,
            'author': {'id': 2, 'fullName': 'Reporter One'},
            'body': 'Saw this too',
            'official': false,
            'likeCount': 0,
            'heartCount': 0,
          },
        ]),
        'POST /api/reports/5/comments': (_) => json({'id': 12}, 201),
        'POST /api/reports/5/comments/11/reactions': (_) => json({'id': 11}),
      });
      final auth = signedIn(api);
      await tester.pumpWidget(
        _app(ReportDetailScreen(auth: auth, reportId: 5)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reply'));
      await tester.pump();
      expect(find.text('Replying to Reporter One'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Write a reply').first,
        'Agreed',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      final i = api.log.indexOf('POST /api/reports/5/comments');
      expect(api.bodies[i], {'body': 'Agreed', 'parentId': 11});

      await tester.tap(find.text('Heart'));
      await tester.pumpAndSettle();
      final j = api.log.indexOf('POST /api/reports/5/comments/11/reactions');
      expect(api.bodies[j], {'type': 'HEART'});
    });
  });

  group('alerts', () {
    testWidgets(
      'lists alerts, marks one read on tap and all on request; badge follows',
      (tester) async {
        tallScreen(tester);
        final api = FakeApi({
          'GET /api/alerts': (_) => json([
            {
              'id': 1,
              'type': 'NEW_REPORT_NEARBY',
              'title': 'New report nearby',
              'body': 'Oil',
              'read': false,
              'critical': false,
            },
            {
              'id': 2,
              'type': 'ACCOUNT_REVIEW',
              'title': 'Verified',
              'body': 'Yes',
              'read': true,
              'critical': false,
            },
          ]),
          'GET /api/alerts/unread-count': (_) => json({'count': 1}),
          'POST /api/alerts/read-all': (_) => json({'marked': 1}),
        });
        final auth = signedIn(api);
        final alerts = AlertsController(auth.api);
        await tester.pumpWidget(_app(AlertsScreen(auth: auth, alerts: alerts)));
        await tester.pumpAndSettle();

        expect(find.text('New report nearby'), findsOneWidget);
        expect(alerts.unread, 1);
        await tester.tap(find.text('Mark all read'));
        await tester.pumpAndSettle();
        expect(api.count('POST /api/alerts/read-all'), 1);
        alerts.dispose(); // stop its polling timer before the test ends
      },
    );
  });

  group('opportunities', () {
    final opportunity = {
      'id': 3,
      'title': 'Reef survey',
      'description': 'Survey the reef',
      'region': 'Southern Province',
      'paid': true,
      'open': true,
      'organizationId': 50,
      'organizationName': 'Blue Org',
    };

    testWidgets(
      'a diver applies with a message and sees the application status',
      (tester) async {
        tallScreen(tester);
        var applied = false;
        final api = FakeApi({
          'GET /api/opportunities': (_) => json([opportunity]),
          'GET /api/opportunities/applications/mine': (_) => json(
            applied
                ? [
                    {
                      'id': 9,
                      'opportunityId': 3,
                      'opportunityTitle': 'Reef survey',
                      'status': 'PENDING',
                      'diver': {'fullName': 'Hiruna'},
                    },
                  ]
                : [],
          ),
          'POST /api/opportunities/3/applications': (_) {
            applied = true;
            return json({'id': 9}, 201);
          },
        });
        final auth = signedIn(api, role: 'DIVER');
        await tester.pumpWidget(_app(OpportunitiesScreen(auth: auth)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        final i = api.log.indexOf('POST /api/opportunities/3/applications');
        expect(api.bodies[i], {'message': 'Available for this assignment.'});
        expect(find.text('Application: Pending'), findsOneWidget);
      },
    );

    testWidgets('a community member sees the list but no apply button', (
      tester,
    ) async {
      tallScreen(tester);
      final api = FakeApi({
        'GET /api/opportunities': (_) => json([opportunity]),
      });
      await tester.pumpWidget(_app(OpportunitiesScreen(auth: signedIn(api))));
      await tester.pumpAndSettle();
      expect(find.text('Reef survey'), findsOneWidget);
      expect(find.text('Apply'), findsNothing);
      expect(
        find.textContaining('Register as a volunteer diver'),
        findsOneWidget,
      );
    });
  });

  group('console', () {
    FakeApi consoleApi() => FakeApi({
      'GET /api/reports': (_) => json({
        'content': [reportJson()],
        'last': true,
        'totalElements': 1,
      }),
      'GET /api/projects': (_) => json([]),
      'GET /api/alerts': (_) => json([]),
      'GET /api/alerts/unread-count': (_) => json({'count': 0}),
      'GET /api/analytics/summary': (_) =>
          json({'reportedSites': 12, 'wasteRemovedKg': 30}),
    });

    testWidgets('administrators see Verifications and Users under More', (
      tester,
    ) async {
      tallScreen(tester);
      final auth = signedIn(consoleApi(), role: 'ADMIN');
      await tester.pumpWidget(_app(ConsoleShell(auth: auth)));
      await tester.pumpAndSettle();
      expect(find.text('Oil on the beach'), findsOneWidget); // queue
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Verifications'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
    });

    testWidgets('government officers do not get the administrator tools', (
      tester,
    ) async {
      tallScreen(tester);
      final auth = signedIn(consoleApi(), role: 'AUTHORITY');
      await tester.pumpWidget(_app(ConsoleShell(auth: auth)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Verifications'), findsNothing);
      expect(find.text('Users'), findsNothing);
      expect(find.text('Community app'), findsOneWidget);
    });

    testWidgets('analytics shows the summary figures', (tester) async {
      tallScreen(tester);
      final auth = signedIn(consoleApi(), role: 'ADMIN');
      await tester.pumpWidget(_app(ConsoleShell(auth: auth)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();
      expect(find.text('12'), findsOneWidget);
      expect(find.text('30 kg'), findsOneWidget);
    });

    testWidgets('an administrator approves a verified report via /moderation', (
      tester,
    ) async {
      tallScreen(tester, height: 4000);
      final api = FakeApi({
        'GET /api/reports/5': (_) => json(reportJson(status: 'VERIFIED')),
        'GET /api/reports/5/info-requests': (_) => json([]),
        'POST /api/reports/5/moderation': (_) =>
            json(reportJson(status: 'ESCALATED', adminDecision: 'APPROVED')),
      });
      final auth = signedIn(api, role: 'ADMIN');
      await tester.pumpWidget(
        _app(ReportReviewScreen(auth: auth, reportId: 5)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve and send to officer'));
      await tester.pumpAndSettle();
      final i = api.log.indexOf('POST /api/reports/5/moderation');
      expect(api.bodies[i], {'decision': 'APPROVED', 'comment': null});
      expect(
        find.textContaining('The report is with the government officer'),
        findsOneWidget,
      );
    });

    testWidgets(
      'an officer cannot decide without a comment, and uses /authority-decision',
      (tester) async {
        tallScreen(tester, height: 4000);
        final api = FakeApi({
          'GET /api/reports/5': (_) => json(reportJson(status: 'ESCALATED')),
          'GET /api/reports/5/info-requests': (_) => json([]),
          'POST /api/reports/5/authority-decision': (_) => json({
            ...reportJson(status: 'ESCALATED'),
            'adminDecision': 'APPROVED',
          }),
        });
        final auth = signedIn(api, role: 'AUTHORITY');
        await tester.pumpWidget(
          _app(ReportReviewScreen(auth: auth, reportId: 5)),
        );
        await tester.pumpAndSettle();

        final approve = find.widgetWithText(
          FilledButton,
          'Approve and create project',
        );
        expect(tester.widget<FilledButton>(approve).onPressed, isNull);
        await tester.enterText(
          find.widgetWithText(TextField, 'Official comment'),
          'Approved.',
        );
        await tester.pump();
        expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
        await tester.tap(approve);
        await tester.pumpAndSettle();
        final i = api.log.indexOf('POST /api/reports/5/authority-decision');
        expect(api.bodies[i], {'decision': 'APPROVED', 'comment': 'Approved.'});
        expect(api.count('POST /api/reports/5/moderation'), 0);
      },
    );
  });

  group('profile editing', () {
    testWidgets('saving sends the edited fields to PUT /api/users/me', (
      tester,
    ) async {
      tallScreen(tester, height: 3000);
      Object? sent;
      final api = FakeApi({
        'PUT /api/users/me': (req) =>
            json({...userJson(), 'city': 'Galle', 'availableForAlerts': true}),
      });
      final auth = signedIn(api);
      await tester.pumpWidget(_app(EditProfileScreen(auth: auth)));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Town or city'),
        'Galle',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      sent = api.bodies[api.log.indexOf('PUT /api/users/me')];
      expect((sent as Map)['city'], 'Galle');
      expect(sent['firstName'], 'Hiruna');
      expect(auth.user!.city, 'Galle');
    });

    testWidgets('a bad latitude blocks the save', (tester) async {
      tallScreen(tester, height: 3000);
      final api = FakeApi({});
      await tester.pumpWidget(_app(EditProfileScreen(auth: signedIn(api))));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Latitude'),
        '123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pump();
      expect(find.textContaining('Latitude must be between'), findsOneWidget);
      expect(api.log, isEmpty);
    });
  });

  group('app routing', () {
    testWidgets(
      'officials land on the console; signing out closes pushed screens',
      (tester) async {
        tallScreen(tester);
        final api = FakeApi({
          'GET /api/reports': (_) =>
              json({'content': [], 'last': true, 'totalElements': 0}),
          'GET /api/alerts/unread-count': (_) => json({'count': 0}),
          'GET /api/analytics/summary': (_) => json({}),
          'GET /api/projects': (_) => json([]),
        });
        final auth = signedIn(api, role: 'ADMIN')..ready = true;
        await tester.pumpWidget(TidelineApp(auth: auth));
        await tester.pumpAndSettle();
        expect(find.text('Review queue'), findsOneWidget);

        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Users'));
        await tester.pumpAndSettle();
        expect(find.text('Search by name or email'), findsOneWidget);

        await auth.logout();
        await tester.pumpAndSettle();
        expect(find.text('Sign in'), findsWidgets);
        expect(find.text('Search by name or email'), findsNothing);
      },
    );
  });
}
