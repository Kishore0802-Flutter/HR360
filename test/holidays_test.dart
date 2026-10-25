import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/holidays.dart';

void main() {
  final sampleHolidaysData = {
    'items': [
      {
        'id': '83d9961e-9660-434b-a763-b8244508e9af',
        'date': '2026-01-14',
        'name': 'Pongal',
        'isOptional': false,
        'createdAt': '2026-10-22T14:03:38.357Z',
      },
      {
        'id': '296c57ce-0992-49b3-9480-d337f5c434ba',
        'date': '2026-01-26',
        'name': 'Republic Day',
        'isOptional': false,
        'createdAt': '2026-10-22T14:03:38.357Z',
      },
      {
        'id': '99454c7e-c6a5-4dfb-95c8-b12ad1afbef8',
        'date': '2026-08-15',
        'name': 'Independence Day',
        'isOptional': false,
        'createdAt': '2026-10-22T14:03:38.357Z',
      },
      {
        'id': '369f5d0b-ce80-4e24-b0da-bc3db62eb645',
        'date': '2026-10-02',
        'name': 'Gandhi Jayanti',
        'isOptional': false,
        'createdAt': '2026-10-22T14:03:38.357Z',
      },
      {
        'id': '0a6d317a-4cc7-446b-baa9-29638e0a624a',
        'date': '2026-12-25',
        'name': 'Christmas',
        'isOptional': false,
        'createdAt': '2026-10-22T14:03:38.357Z',
      },
    ],
    'page': 1,
    'pageSize': 500,
    'totalItems': 5,
    'totalPages': 1,
  };

  Api createMockApi() {
    return Api(
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/holidays')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleHolidaysData}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success": true, "data": {}}', 200);
      }),
    );
  }

  testWidgets('HolidaysPage renders holidays in card UI with year and search', (tester) async {
    final api = createMockApi();

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HolidaysPage(api: api, initialYear: 2026),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('HRMS / Holidays'), findsOneWidget);
    expect(find.text('Holidays'), findsWidgets); // Header & AppBar
    expect(
      find.text('Company holidays are excluded from leave duration (unless a policy counts them) and are not marked absent. Optional holidays are informational.'),
      findsOneWidget,
    );

    // Verify Controls
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('By Holiday Name'), findsOneWidget);
    expect(find.text('5 holidays in 2026'), findsOneWidget);

    // Verify Holiday Cards
    expect(find.text('Pongal'), findsOneWidget);
    expect(find.text('Republic Day'), findsOneWidget);
    expect(find.text('Independence Day'), findsOneWidget);
    expect(find.text('Gandhi Jayanti'), findsOneWidget);
    expect(find.text('Christmas'), findsOneWidget);

    // Verify Date details
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Company holiday'), findsNWidgets(5));

    // Test Search filter
    await tester.enterText(find.byType(TextField), 'Christmas');
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == 'Christmas'),
      findsOneWidget,
    );
    expect(find.text('Pongal'), findsNothing);
    expect(find.text('1 holidays in 2026'), findsOneWidget);
  });
}
