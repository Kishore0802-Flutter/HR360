import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/clock_in.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('Location Name & Clock In', () {
    test('resolveLocationName falls back cleanly to coordinate format if geocoding unavailable in test', () async {
      final name = await resolveLocationName(12.999925, 80.208038);
      expect(name, isNotEmpty);
      expect(name.contains('12.9999° N') || name.contains('Chennai'), isTrue);
    });

    test('resolveLocationName matches office site when within radius', () async {
      final rules = {
        'sites': [
          {
            'name': 'Chennai Tech Park',
            'latitude': 12.9999,
            'longitude': 80.2080,
            'radiusMeters': 200,
          }
        ]
      };
      final name = await resolveLocationName(12.99992, 80.20803, rules: rules);
      expect(name, equals('Chennai Tech Park'));
    });

    testWidgets('ClockInPage mounts and displays title without error', (tester) async {
      final api = Api(offline: true);
      await tester.pumpWidget(
        MaterialApp(
          home: ClockInPage(api: api, action: 'in'),
        ),
      );
      await tester.pump();
      // Should show either permissions gate or camera screen
      expect(find.byType(ClockInPage), findsOneWidget);
    });
  });
}
