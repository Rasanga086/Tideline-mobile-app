import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tideline_mobile/screens/console_queue_screen.dart';
import 'package:tideline_mobile/screens/feed_screen.dart';

import 'helpers.dart';

/// The API cannot bind status=all to its ReportStatus enum, so "all" must be left out
/// of the query (the website's query() helper does the same).
void main() {
  testWidgets(
    'feed omits status and severity for "all", and sends a real status',
    (tester) async {
      tallScreen(tester, height: 3000);
      final queries = <Map<String, String>>[];
      final api = FakeApi({
        'GET /api/reports': (req) {
          queries.add(req.url.queryParameters);
          return json({'content': [], 'last': true, 'totalElements': 0});
        },
      });
      await tester.pumpWidget(
        MaterialApp(home: FeedScreen(auth: signedIn(api))),
      );
      await tester.pumpAndSettle();
      expect(queries.first.containsKey('status'), isFalse);
      expect(queries.first.containsKey('severity'), isFalse);
      expect(queries.first['sort'], 'newest');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Pending'));
      await tester.pumpAndSettle();
      expect(queries.last['status'], 'PENDING');
    },
  );

  testWidgets(
    'review queue omits status for "all" and always asks for the review queue',
    (tester) async {
      tallScreen(tester, height: 3000);
      final queries = <Map<String, String>>[];
      final api = FakeApi({
        'GET /api/reports': (req) {
          queries.add(req.url.queryParameters);
          return json({'content': [], 'last': true, 'totalElements': 0});
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ConsoleQueueScreen(auth: signedIn(api, role: 'ADMIN')),
        ),
      );
      await tester.pumpAndSettle();
      expect(queries.first.containsKey('status'), isFalse);
      expect(queries.first['reviewQueue'], 'true');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Waiting for approval'));
      await tester.pumpAndSettle();
      expect(queries.last['status'], 'VERIFIED');
      expect(queries.last['reviewQueue'], 'true');
    },
  );

  testWidgets(
    'an officer starts on the escalated queue and can list cleanups awaiting resources',
    (tester) async {
      tallScreen(tester, height: 3000);
      final queries = <Map<String, String>>[];
      final api = FakeApi({
        'GET /api/reports': (req) {
          queries.add(req.url.queryParameters);
          return json({'content': [], 'last': true, 'totalElements': 0});
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ConsoleQueueScreen(auth: signedIn(api, role: 'AUTHORITY')),
        ),
      );
      await tester.pumpAndSettle();
      expect(queries.first['status'], 'ESCALATED');

      final chip = find.widgetWithText(
        ChoiceChip,
        'Waiting for resource assigning',
      );
      await tester.ensureVisible(
        chip,
      ); // it sits off-screen in the horizontal chip row
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(queries.last['awaitingResources'], 'true');
      expect(queries.last.containsKey('status'), isFalse);
    },
  );
}
