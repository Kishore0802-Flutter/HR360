import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/shell.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  final userStatusPayload = {
    'success': true,
    'data': {
      'workDate': '2026-10-25',
      'timezone': 'Asia/Kolkata',
      'serverTime': '2026-10-25T13:54:06.944Z',
      'isCheckedIn': true,
      'openSince': '2026-10-25T13:52:57.938Z',
      'nextAction': 'CHECK_OUT',
      'canCheckIn': false,
      'sessionsToday': 2,
      'today': {
        'date': '2026-10-25',
        'status': 'CHECKED_IN',
        'leaveType': null,
        'holiday': null,
        'firstInAt': '2026-10-25T10:19:42.117Z',
        'lastOutAt': '2026-10-25T10:27:06.855Z',
        'sessionsCount': 2,
        'completedSessions': 1,
        'grossMinutes': 7,
        'netMinutes': 7,
        'breakMinutes': 0,
        'overtimeMinutes': 0,
        'isLate': true,
        'lateMinutes': 379,
        'hasOpenSession': true,
        'exceptions': ['LATE_ARRIVAL'],
        'adjusted': false,
      },
      'events': [
        {
          'id': 'ca7ce030-4bb1-412d-8c12-5f23b8b9add1',
          'employeeId': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
          'eventType': 'CHECK_IN',
          'serverTime': '2026-10-25T10:19:42.117Z',
          'workDate': '2026-10-25',
          'timezone': 'Asia/Kolkata',
          'deviceTime': '2026-10-25T10:19:41.067Z',
          'latitude': 12.999925611010317,
          'longitude': 80.20803833195853,
          'accuracy': 36.333333333333336,
          'source': 'WEB',
          'flags': [],
          'flagReasons': [],
          'reviewStatus': 'NOT_REQUIRED',
          'hasPhoto': true,
          'photo': null,
        },
        {
          'id': '3146824c-fe54-420d-a13c-b169475cba42',
          'employeeId': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
          'eventType': 'CHECK_OUT',
          'serverTime': '2026-10-25T10:27:06.855Z',
          'workDate': '2026-10-25',
          'timezone': 'Asia/Kolkata',
          'deviceTime': '2026-10-25T10:27:05.797Z',
          'latitude': 12.999940760917882,
          'longitude': 80.20833658856084,
          'accuracy': 42.0,
          'source': 'WEB',
          'flags': [],
          'flagReasons': [],
          'reviewStatus': 'NOT_REQUIRED',
          'hasPhoto': true,
          'photo': null,
        },
        {
          'id': '590d3c51-97ce-4a02-9143-43afb8fab2af',
          'employeeId': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
          'eventType': 'CHECK_IN',
          'serverTime': '2026-10-25T13:52:57.938Z',
          'workDate': '2026-10-25',
          'timezone': 'Asia/Kolkata',
          'deviceTime': '2026-10-25T13:52:51.716Z',
          'latitude': 37.4219983,
          'longitude': -122.084,
          'accuracy': 5.0,
          'source': 'WEB',
          'flags': [],
          'flagReasons': [],
          'reviewStatus': 'NOT_REQUIRED',
          'hasPhoto': true,
          'photo': null,
        },
      ],
      'pendingMissingCheckout': null,
      'requirements': {
        'photo': true,
        'location': true,
        'accuracyThresholdMeters': 200,
      },
    },
  };

  testWidgets('displays Today Activity & Punches container above Apply Leave when activity exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/attendance/status')) {
          return http.Response(jsonEncode(userStatusPayload), 200);
        }
        if (path.contains('/reports/hrms/dashboard')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'today': {
                  'status': 'PRESENT',
                  'firstInAt': '2026-10-25T10:19:42.117Z',
                  'lastOutAt': '2026-10-25T10:27:06.855Z',
                  'grossMinutes': 7,
                  'netMinutes': 7,
                  'sessionsCount': 2,
                },
                'summary': {'totalGrossMinutes': 7, 'totalNetMinutes': 7},
                'leave': {'balances': [], 'upcoming': [], 'pending': 0},
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'items': []},
          }),
          200,
        );
      }),
    );

    api.profile = {
      'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
      'name': 'Kishore Kumar',
      'email': 'kishore@example.com',
      'role': 'EMPLOYEE',
      'permissions': ['attendance:create', 'leave:create'],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            api: api,
            onTab: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify See Today's Activities single container is rendered
    expect(find.text("See Today's Activities"), findsOneWidget);
    expect(find.text('Clocked In'), findsWidgets);
    expect(find.textContaining('2 sessions • 3 punches'), findsOneWidget);

    // Verify source and accuracy indicators and individual punch session tags
    // are NOT cluttering the home page card
    expect(find.text('Session 1'), findsNothing);
    expect(find.text('Session 2'), findsNothing);
    expect(find.text('WEB'), findsNothing);
    expect(find.text('±36m'), findsNothing);
    expect(find.text('±42m'), findsNothing);
    expect(find.text('±5m'), findsNothing);

    // Tap "See Today's Activities" card to open bottom sheet
    await tester.tap(find.text("See Today's Activities"));
    await tester.pumpAndSettle();

    // Verify bottom sheet modal displays title, punch activity timeline, and session badges
    expect(find.text("Today's Activity & Punches"), findsOneWidget);
    expect(find.text('Punch Activity Timeline'), findsOneWidget);
    expect(find.text('Session 1'), findsNWidgets(2)); // Check-in and check-out
    expect(find.text('Session 2'), findsOneWidget); // Check-in

    // Inside the timeline, punch cards are clean (no WEB or ±36m badges)
    expect(find.text('WEB'), findsNothing);
    expect(find.text('±36m'), findsNothing);

    // Tap a punch event in the timeline to view deep punch details
    await tester.tap(find.text('Session 1').first);
    await tester.pumpAndSettle();

    // Verify detailed punch sheet displays Location, GPS, and Audit
    expect(find.text('Check In Details'), findsOneWidget);
    expect(find.text('Location & GPS Details'), findsOneWidget);
    expect(find.text('Verification & Audit'), findsOneWidget);
    expect(find.text('WEB'), findsOneWidget);
    expect(find.text('±36m'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Close punch details bottom sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Close timeline bottom sheet
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Verify Apply Leave and Raise a Request exist
    final activityFinder = find.text("See Today's Activities");
    final applyLeaveFinder = find.text('Apply Leave');
    final raiseRequestFinder = find.text('Raise a Request');

    expect(applyLeaveFinder, findsOneWidget);
    expect(raiseRequestFinder, findsOneWidget);

    // CRITICAL: verify Today's Activity container sits ABOVE Apply Leave
    final activityTop = tester.getTopLeft(activityFinder).dy;
    final applyLeaveTop = tester.getTopLeft(applyLeaveFinder).dy;
    expect(
      activityTop < applyLeaveTop,
      isTrue,
      reason: "Today's Activity container must be positioned above Apply Leave row",
    );
  });

  testWidgets('hides Today Activity container completely when no check-in/out activity exists today', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final emptyPayload = {
      'success': true,
      'data': {
        'workDate': '2026-10-25',
        'timezone': 'Asia/Kolkata',
        'isCheckedIn': false,
        'sessionsToday': 0,
        'canCheckIn': true,
        'today': {
          'date': '2026-10-25',
          'status': 'ABSENT',
          'sessionsCount': 0,
          'completedSessions': 0,
          'grossMinutes': 0,
          'netMinutes': 0,
          'firstInAt': null,
          'lastOutAt': null,
          'hasOpenSession': false,
        },
        'events': [],
      },
    };

    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/attendance/status')) {
          return http.Response(jsonEncode(emptyPayload), 200);
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'today': {'sessionsCount': 0},
              'summary': {},
              'leave': {'balances': [], 'upcoming': [], 'pending': 0},
            },
          }),
          200,
        );
      }),
    );

    api.profile = {
      'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
      'name': 'Kishore Kumar',
      'role': 'EMPLOYEE',
      'permissions': ['attendance:create', 'leave:create'],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            api: api,
            onTab: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Today's Activity container is NOT rendered
    expect(find.text("See Today's Activities"), findsNothing);

    // Apply Leave & Raise a Request row are still rendered cleanly
    expect(find.text('Apply Leave'), findsOneWidget);
    expect(find.text('Raise a Request'), findsOneWidget);
  });
}
