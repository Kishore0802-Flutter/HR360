import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/attendance.dart';
import 'package:hr360_mobile/design.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('AttendancePage renders new API totals, filter, calendar and logs', (
    tester,
  ) async {
    tz.initializeTimeZones();
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final apiPayload = {
      'employee': {
        'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
        'employeeCode': 'DEMO-E01',
        'fullName': 'Arun Kumar',
        'email': 'employee@giraffai.in',
        'status': 'ACTIVE',
      },
      'from': '2026-09-24',
      'to': '2026-10-23',
      'days': [
        {
          'date': '2026-10-23',
          'status': 'PRESENT',
          'leaveType': null,
          'holiday': null,
          'firstInAt': '2026-10-23T10:02:22.308Z',
          'lastOutAt': '2026-10-23T10:03:24.778Z',
          'sessionsCount': 1,
          'completedSessions': 1,
          'grossMinutes': 1,
          'netMinutes': 1,
          'breakMinutes': 0,
          'overtimeMinutes': 0,
          'isLate': true,
          'lateMinutes': 362,
          'hasOpenSession': false,
          'exceptions': ['LATE_ARRIVAL'],
          'adjusted': false,
        },
        {
          'date': '2026-10-22',
          'status': 'PRESENT',
          'leaveType': null,
          'holiday': null,
          'firstInAt': '2026-10-22T14:08:22.802Z',
          'lastOutAt': '2026-10-22T14:10:02.178Z',
          'sessionsCount': 1,
          'completedSessions': 1,
          'grossMinutes': 1,
          'netMinutes': 1,
          'breakMinutes': 0,
          'overtimeMinutes': 0,
          'isLate': true,
          'lateMinutes': 608,
          'hasOpenSession': false,
          'exceptions': ['LATE_ARRIVAL'],
          'adjusted': false,
        },
        {
          'date': '2026-10-02',
          'status': 'HOLIDAY',
          'holiday': 'Gandhi Jayanti',
          'firstInAt': null,
          'lastOutAt': null,
          'netMinutes': 0,
          'isLate': false,
        },
      ],
      'totals': {
        'present': 12,
        'absent': 9,
        'onLeave': 0,
        'halfDayLeave': 0,
        'holidays': 1,
        'weekends': 8,
        'late': 2,
        'missingCheckout': 0,
        'totalNetMinutes': 4947,
        'averageNetMinutes': 412,
        'overtimeMinutes': 0,
      },
    };

    final api = Api(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/attendance') ||
            request.url.path.contains('/attendance/me')) {
          return http.Response(jsonEncode(apiPayload), 200);
        }
        if (request.url.path.contains('/home') ||
            request.url.path.contains('/attendance/status')) {
          return http.Response(
            jsonEncode({'today': '2026-10-23', 'active': null}),
            200,
          );
        }
        if (request.url.path.contains('/leave-requests') ||
            request.url.path.contains('/requests')) {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        return http.Response(jsonEncode({}), 200);
      }),
    );
    api.profile = {
      'name': 'Arun Kumar',
      'email': 'employee@giraffai.in',
      'office': {'name': 'Headquarters'},
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: AttendancePage(api: api),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify employee name
    expect(find.textContaining('Arun Kumar'), findsOneWidget);

    // Verify 1st requirement: Totals cards
    expect(find.text('Present'), findsWidgets);
    expect(find.text('12'), findsWidgets);

    expect(find.text('Absent'), findsWidgets);
    expect(find.text('9'), findsWidgets);

    expect(find.text('Late'), findsWidgets);
    expect(find.text('2'), findsWidgets);

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('21'), findsWidgets);

    // Verify Net Hours (4947 min -> 82h 27m) and Average (412 min -> 6h 52m) and Holidays (1)
    expect(find.text('Net hours'), findsWidgets);
    expect(find.text('82h 27m'), findsOneWidget);
    expect(find.textContaining('6h 52m'), findsOneWidget);
    expect(find.textContaining('1 holiday'), findsOneWidget);

    // Verify By Date Filter button exists
    expect(find.byType(PopupMenuButton<AttendanceFilter>), findsOneWidget);
    expect(find.text('By Date'), findsOneWidget);

    // Verify 2nd requirement: Calendar & Logs table
    expect(find.text('362 min'), findsOneWidget);
    expect(find.text('608 min'), findsOneWidget);
  });
}
