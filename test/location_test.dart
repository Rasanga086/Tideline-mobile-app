import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tideline_mobile/core/location.dart';
import 'package:tideline_mobile/core/places.dart';
import 'package:tideline_mobile/screens/create_report_screen.dart';
import 'package:tideline_mobile/screens/projects_screen.dart';

import 'helpers.dart';

void main() {
  final original = DeviceLocation.locate;
  tearDown(() => DeviceLocation.locate = original);

  test('the town list matches the website and finds the nearest town', () {
    expect(places, hasLength(63));
    final (town, km) = nearestPlace(6.0110, 80.2480)!;
    expect(town.name, 'Unawatuna');
    expect(town.district, 'Galle');
    expect(km, lessThan(1));
  });

  testWidgets(
    '"Use my current location" fills the coordinates and names the place',
    (tester) async {
      tallScreen(tester, height: 3000);
      DeviceLocation.locate = () async => (7.2085, 79.8360);
      final auth = signedIn(FakeApi({}));
      await tester.pumpWidget(
        MaterialApp(home: CreateReportScreen(auth: auth)),
      );

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();

      expect(find.text('7.208500'), findsOneWidget);
      expect(find.text('79.836000'), findsOneWidget);
      expect(find.text('Negombo'), findsWidgets); // location name
      expect(find.text('Gampaha'), findsOneWidget); // district
    },
  );

  testWidgets('a refused location says why and fills in nothing', (
    tester,
  ) async {
    tallScreen(tester, height: 3000);
    DeviceLocation.locate = () async =>
        throw LocationFailure('Tideline was not allowed to use your location.');
    final auth = signedIn(FakeApi({}));
    await tester.pumpWidget(MaterialApp(home: CreateReportScreen(auth: auth)));

    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tideline was not allowed to use your location.'),
      findsOneWidget,
    );
    expect(find.text('Negombo'), findsNothing, reason: 'no made-up position');
  });

  testWidgets(
    'a position far from Sri Lanka keeps the coordinates but names no town',
    (tester) async {
      tallScreen(tester, height: 3000);
      DeviceLocation.locate = () async => (51.5, -0.12);
      final auth = signedIn(FakeApi({}));
      await tester.pumpWidget(
        MaterialApp(home: CreateReportScreen(auth: auth)),
      );
      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      expect(find.text('51.500000'), findsOneWidget);
      expect(find.text('Negombo'), findsNothing);
    },
  );

  testWidgets('cleanups can be narrowed to one province', (tester) async {
    tallScreen(tester, height: 3000);
    Map<String, Object?> project(int id, String title, String province) => {
      'id': id,
      'reference': 'PRJ-$id',
      'title': title,
      'status': 'ACTIVE',
      'province': province,
      'resources': {'finalized': true},
    };
    final api = FakeApi({
      'GET /api/projects': (_) => json([
        project(1, 'Galle sweep', 'Southern Province'),
        project(2, 'Negombo sweep', 'Western Province'),
      ]),
    });
    await tester.pumpWidget(
      MaterialApp(home: ProjectsScreen(auth: signedIn(api))),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 cleanups'), findsOneWidget);

    await tester.tap(find.text('Every province'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Southern Province').last);
    await tester.pumpAndSettle();

    expect(find.text('Galle sweep'), findsOneWidget);
    expect(find.text('Negombo sweep'), findsNothing);
    expect(find.text('1 cleanup of 2'), findsOneWidget);
  });
}
