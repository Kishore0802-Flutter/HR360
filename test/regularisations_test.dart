import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/regularisations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('RegularisationsPage renders list and navigates to AttendanceDayDetailPage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final regularisationsPayload = {
      'success': true,
      'data': {
        'items': [
          {
            'id': 'e7d9cc3f-032d-469a-ae40-4aaee529d01a',
            'employeeId': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
            'employee': {
              'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
              'employeeCode': 'DEMO-E01',
              'fullName': 'Arun Kumar',
              'email': 'employee@giraffai.in',
              'status': 'ACTIVE',
              'department': 'Engineering',
            },
            'workDate': '2026-10-25',
            'type': 'ADD_SESSION',
            'requestedCheckIn': '2026-10-25T11:02:00.000Z',
            'requestedCheckOut': '2026-10-25T11:03:00.000Z',
            'reason': 'Test hshs',
            'attachmentId': '6c794b13-2a14-4837-99ed-ea2941f2fc12',
            'status': 'PENDING',
            'createdAt': '2026-10-25T11:03:46.906Z',
          },
        ],
        'page': 1,
        'pageSize': 20,
        'totalItems': 1,
        'totalPages': 1,
      },
    };

    final dayDetailPayload = {
      'success': true,
      'data': {
        'employee': {
          'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
          'employeeCode': 'DEMO-E01',
          'fullName': 'Arun Kumar',
          'email': 'employee@giraffai.in',
          'status': 'ACTIVE',
        },
        'from': '2026-10-25',
        'to': '2026-10-25',
        'day': {
          'date': '2026-10-25',
          'status': 'PRESENT',
          'firstInAt': '2026-10-25T10:19:42.117Z',
          'lastOutAt': '2026-10-25T10:27:06.855Z',
          'sessionsCount': 1,
          'completedSessions': 1,
          'grossMinutes': 7,
          'netMinutes': 7,
          'breakMinutes': 0,
          'overtimeMinutes': 0,
          'isLate': true,
          'lateMinutes': 379,
          'hasOpenSession': false,
          'exceptions': ['LATE_ARRIVAL'],
        },
        'sessions': [
          {
            'checkIn': '2026-10-25T10:19:42.117Z',
            'checkOut': '2026-10-25T10:27:06.855Z',
            'minutes': 7,
          },
        ],
        'events': [
          {
            'id': 'ca7ce030-4bb1-412d-8c12-5f23b8b9add1',
            'eventType': 'CHECK_IN',
            'serverTime': '2026-10-25T10:19:42.117Z',
            'deviceTime': '2026-10-25T10:19:41.067Z',
            'latitude': 12.99993,
            'longitude': 80.20804,
            'accuracy': 36.3,
            'hasPhoto': true,
            'photo': {
              'url':
                  '/api/v1/files/8998e39d-b016-4dd0-90d2-6958fda81b29/content',
            },
          },
        ],
        'regularisations': [
          {
            'id': 'e7d9cc3f-032d-469a-ae40-4aaee529d01a',
            'workDate': '2026-10-25',
            'type': 'ADD_SESSION',
            'requestedCheckIn': '2026-10-25T11:02:00.000Z',
            'requestedCheckOut': '2026-10-25T11:03:00.000Z',
            'reason': 'Test hshs',
            'status': 'PENDING',
          },
        ],
      },
    };

    final api = Api(
      client: MockClient((request) async {
        if (request.url.path.contains('/attendance/days/')) {
          return http.Response(jsonEncode(dayDetailPayload), 200);
        }
        if (request.url.path.endsWith('/regularisations')) {
          return http.Response(jsonEncode(regularisationsPayload), 200);
        }
        return http.Response(jsonEncode({}), 200);
      }),
    );
    api.profile = {
      'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
      'name': 'Arun Kumar',
      'employee_code': 'DEMO-E01',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: RegularisationsPage(api: api),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Regularisations list item exists
    expect(find.text('Regularisation Requests'), findsOneWidget);
    expect(find.text('Add missing session'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Reason: Test hshs'), findsOneWidget);

    // 2. Tap the regularisation request card
    await tester.tap(find.text('Reason: Test hshs'));
    await tester.pumpAndSettle();

    // 3. Verify AttendanceDayDetailPage opened with full view details
    expect(find.text('Attendance Details'), findsOneWidget);
    expect(find.textContaining('Arun Kumar'), findsWidgets);
    expect(find.text('Day totals'), findsOneWidget);
    expect(find.text('Late arrival'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Raw events & evidence'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Raw events & evidence'), findsOneWidget);
    expect(find.textContaining('12.99993, 80.20804'), findsOneWidget);
  });
}
