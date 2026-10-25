import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/directory.dart';
import 'package:hr360_mobile/employee_detail.dart';

void main() {
  final sampleEmployeesList = {
    'items': [
      {
        'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
        'employeeCode': 'DEMO-E01',
        'firstName': 'Arun',
        'lastName': 'Kumar',
        'fullName': 'Arun Kumar',
        'email': 'employee@giraffai.in',
        'phone': null,
        'department': {
          'id': 'c87df81c-886c-4ea4-a4ee-e7c5f80d94e7',
          'name': 'Engineering',
        },
        'designation': {
          'id': '8944238c-7403-48de-9ff5-5d9f76d1b089',
          'title': 'Software Engineer',
        },
        'manager': {
          'id': '4e786537-67d0-4c4a-bb8d-758df45437e8',
          'fullName': 'Priya Raman',
        },
        'teams': [
          {
            'id': '0e29dcc3-db9e-4125-94ce-e9c369d4f04b',
            'name': 'Platform Team',
          }
        ],
        'joiningDate': '2024-02-01',
        'employmentType': 'FULL_TIME',
        'status': 'ACTIVE',
      },
      {
        'id': '3e658d68-ec6b-46c8-b9b6-16ab10941349',
        'employeeCode': 'DEMO-E02',
        'firstName': 'Divya',
        'lastName': 'Lakshmi',
        'fullName': 'Divya Lakshmi',
        'email': 'divya@giraffai.in',
        'phone': null,
        'department': {
          'id': 'c87df81c-886c-4ea4-a4ee-e7c5f80d94e7',
          'name': 'Engineering',
        },
        'designation': {
          'id': '8944238c-7403-48de-9ff5-5d9f76d1b089',
          'title': 'Software Engineer',
        },
        'manager': {
          'id': '4e786537-67d0-4c4a-bb8d-758df45437e8',
          'fullName': 'Priya Raman',
        },
        'teams': [
          {
            'id': '0e29dcc3-db9e-4125-94ce-e9c369d4f04b',
            'name': 'Platform Team',
          }
        ],
        'joiningDate': '2024-02-01',
        'employmentType': 'FULL_TIME',
        'status': 'ACTIVE',
      },
    ],
    'page': 1,
    'pageSize': 20,
    'totalItems': 2,
    'totalPages': 1,
  };

  final sampleEmployeeDetail = {
    'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
    'employeeCode': 'DEMO-E01',
    'firstName': 'Arun',
    'lastName': 'Kumar',
    'fullName': 'Arun Kumar',
    'email': 'employee@giraffai.in',
    'phone': null,
    'joiningDate': '2024-02-01',
    'employmentType': 'FULL_TIME',
    'workLocation': null,
    'status': 'ACTIVE',
    'department': {
      'id': 'c87df81c-886c-4ea4-a4ee-e7c5f80d94e7',
      'name': 'Engineering',
    },
    'designation': {
      'id': '8944238c-7403-48de-9ff5-5d9f76d1b089',
      'title': 'Software Engineer',
    },
    'manager': {
      'id': '4e786537-67d0-4c4a-bb8d-758df45437e8',
      'employeeCode': 'DEMO-M01',
      'fullName': 'Priya Raman',
      'email': 'manager@giraffai.in',
      'status': 'ACTIVE',
      'designation': 'Manager',
    },
    'teams': [
      {
        'id': '0e29dcc3-db9e-4125-94ce-e9c369d4f04b',
        'name': 'Platform Team',
        'code': 'DEMO-PLATFORM',
      }
    ],
    'directReportCount': 0,
    'account': {
      'userId': 'd2b172a8-127b-4625-866d-43999c7f8d99',
      'status': 'ACTIVE',
      'lastLoginAt': '2026-10-25T09:09:06.274Z',
    },
    'taskSummary': {
      'todo': 10,
      'inProgress': 0,
      'completed': 0,
      'overdue': 5,
    },
    'leaveBalances': [
      {
        'leaveType': {
          'id': '25eecca1-ee3e-4cb3-a728-07e35ca461d6',
          'code': 'CL',
          'name': 'Casual Leave',
          'color': '#3b82f6',
          'isPaid': true,
        },
        'year': 2026,
        'entitled': 10,
        'carriedForward': 0,
        'adjustments': 0,
        'used': 1,
        'balance': 9,
        'pending': 2,
        'available': 7,
      },
      {
        'leaveType': {
          'id': '607085bb-0ffb-4e0d-9ac6-89939e63f73b',
          'code': 'SL',
          'name': 'Sick Leave',
          'color': '#ef4444',
          'isPaid': true,
        },
        'year': 2026,
        'entitled': 8,
        'carriedForward': 0,
        'adjustments': 0,
        'used': 0,
        'balance': 8,
        'pending': 1,
        'available': 7,
      },
    ],
  };

  final sampleAttendanceData = {
    'employee': {
      'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
      'employeeCode': 'DEMO-E01',
      'fullName': 'Arun Kumar',
      'status': 'ACTIVE',
    },
    'totals': {
      'present': 14,
      'absent': 7,
      'late': 4,
      'totalNetMinutes': 4955,
    },
    'days': [
      {
        'date': '2026-10-25',
        'status': 'PRESENT',
        'firstInAt': '2026-10-25T10:19:42.117Z',
        'lastOutAt': '2026-10-25T10:27:06.855Z',
        'netMinutes': 7,
        'isLate': true,
        'lateMinutes': 379,
      },
    ],
  };

  final sampleLeaveRequests = {
    'items': [
      {
        'id': 'c6e30e8d-2c81-4e85-9bd8-7218acd91f43',
        'leaveType': {
          'code': 'SL',
          'name': 'Sick Leave',
          'color': '#ef4444',
          'isPaid': true,
        },
        'startDate': '2026-10-30',
        'endDate': '2026-10-30',
        'days': 1,
        'reason': 'Medical recovery',
        'status': 'PENDING',
      },
    ],
    'page': 1,
    'pageSize': 10,
    'totalItems': 1,
    'totalPages': 1,
  };

  final sampleTasks = {
    'items': [
      {
        'id': '12418dad-633a-41b0-b703-62e7e6751841',
        'code': 'TSK-00153',
        'title': 'Test for api',
        'status': 'TODO',
        'priority': 'MEDIUM',
        'dueAt': '2026-11-22T04:30:00.000Z',
        'isOverdue': false,
        'project': {
          'name': 'HRMS Rollout',
          'color': '#6366f1',
        },
      },
    ],
    'page': 1,
    'pageSize': 10,
    'totalItems': 1,
    'totalPages': 1,
  };

  Api createMockApi() {
    return Api(
      client: MockClient((request) async {
        final path = request.url.path;

        if (path.contains('/attendance/employees/')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleAttendanceData}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/leave-requests')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleLeaveRequests}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/tasks')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleTasks}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/employees/lookup')) {
          return http.Response(
            jsonEncode({'success': true, 'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == '/api/v1/employees/ffe7154f-ba0e-4988-84a5-320bbd6bac53' ||
            path.endsWith('/employees/ffe7154f-ba0e-4988-84a5-320bbd6bac53')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleEmployeeDetail}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/employees')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleEmployeesList}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{"success": true, "data": {}}', 200);
      }),
    );
  }

  testWidgets('EmployeesPage renders card UI and navigates to EmployeeDetailPage on tap', (
    tester,
  ) async {
    final api = createMockApi();

    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeesPage(api: api),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('HRMS / Employees'), findsOneWidget);
    expect(find.text('Employee directory with employment details, reporting lines and teams.'), findsOneWidget);

    // Verify Filters
    expect(find.text('Search name, email, code...'), findsOneWidget);
    expect(find.text('By Department'), findsOneWidget);
    expect(find.text('By Status'), findsOneWidget);
    expect(find.text('Manager: All'), findsOneWidget);

    // Verify Employee Cards
    expect(find.text('Arun Kumar'), findsOneWidget);
    expect(find.text('DEMO-E01'), findsOneWidget);
    expect(find.text('employee@giraffai.in'), findsOneWidget);
    expect(find.text('Software Engineer · Engineering'), findsWidgets);
    expect(find.text('Manager: Priya Raman'), findsWidgets);
    expect(find.text('Platform Team'), findsWidgets);

    expect(find.text('Divya Lakshmi'), findsOneWidget);
    expect(find.text('DEMO-E02'), findsOneWidget);

    // Verify Pagination Toolbar
    expect(find.text('1–2 of 2'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);

    // Tap on Arun Kumar's card to navigate to EmployeeDetailPage
    await tester.tap(find.text('Arun Kumar'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify EmployeeDetailPage is pushed
    expect(find.byType(EmployeeDetailPage), findsOneWidget);

    // Verify Header
    expect(find.text('DEMO-E01 · Software Engineer · Engineering'), findsOneWidget);

    // Verify 4 Segmented Tabs
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);

    // Verify Overview Tab content
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('To do'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Casual Leave'), findsOneWidget);
    expect(find.text('Sick Leave'), findsOneWidget);

    // Tap on Attendance tab
    await tester.tap(find.text('Attendance'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Daily Attendance Logs'), findsOneWidget);
    expect(find.text('Late (379m)'), findsOneWidget);

    // Tap on Leave tab
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Leave Requests (1)'), findsOneWidget);
    expect(find.text('Reason: Medical recovery'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);

    // Tap on Tasks tab
    await tester.tap(find.text('Tasks'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Assigned Tasks (1)'), findsOneWidget);
    expect(find.text('TSK-00153'), findsOneWidget);
    expect(find.text('Test for api'), findsOneWidget);
    expect(find.text('HRMS Rollout'), findsOneWidget);
  });
}
