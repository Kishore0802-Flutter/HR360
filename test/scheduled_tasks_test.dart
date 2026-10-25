import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/scheduled_tasks.dart';
import 'package:hr360_mobile/task_dashboard.dart';

void main() {
  final sampleProjects = {
    'items': [
      {
        'id': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
        'code': 'DEMO-HRMS',
        'name': 'HRMS Rollout',
        'status': 'ACTIVE',
      },
      {
        'id': 'p2-2222-3333-4444-555555555555',
        'code': 'DEMO-OPS',
        'name': 'Operations Growth',
        'status': 'ACTIVE',
      },
    ],
    'page': 1,
    'pageSize': 100,
    'totalItems': 2,
    'totalPages': 1,
  };

  final sampleSchedulesResponse = {
    'items': [
      {
        'id': 'ea1e9ac5-b530-40fc-ac4e-e1f75142db24',
        'title': 'Test for api',
        'description': 'Test description for recurring task',
        'projectId': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
        'project': {
          'id': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
          'name': 'HRMS Rollout',
          'code': 'DEMO-HRMS',
        },
        'taskType': 'GENERAL',
        'priority': 'MEDIUM',
        'frequency': 'WEEKLY',
        'interval': 1,
        'byWeekday': [7],
        'byMonthDay': [],
        'startDate': '2026-10-25',
        'startTime': '09:00',
        'durationMinutes': 60,
        'timezone': 'Asia/Kolkata',
        'endType': 'NEVER',
        'status': 'ACTIVE',
        'creatorId': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
        'creator': {
          'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
          'fullName': 'Arun Kumar',
        },
        'summary': 'Every week on Sunday at 09:00 for 1h (Asia/Kolkata)',
        'nextOccurrences': [
          {
            'date': '2026-10-25',
            'startAt': '2026-10-25T03:30:00.000Z',
            'endAt': '2026-10-25T04:30:00.000Z',
          },
          {
            'date': '2026-11-01',
            'startAt': '2026-11-01T03:30:00.000Z',
            'endAt': '2026-11-01T04:30:00.000Z',
          },
        ],
      },
    ],
    'page': 1,
    'pageSize': 20,
    'totalItems': 1,
    'totalPages': 1,
  };

  Api createMockApi({List<Uri>? recordedUris}) {
    final client = MockClient((request) async {
      recordedUris?.add(request.url);
      final path = request.url.path;

      if (path.contains('/task-schedules')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': sampleSchedulesResponse,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/projects')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': sampleProjects,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode({'success': true, 'data': {}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = Api(client: client);
    api.scope = 'ALL';
    api.profile = {
      'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
      'fullName': 'Arun Kumar',
    };
    return api;
  }

  testWidgets('ScheduledTasksPage renders table, headers, filters and pagination', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final recordedUris = <Uri>[];
    final api = createMockApi(recordedUris: recordedUris);

    await tester.pumpWidget(
      MaterialApp(
        home: ScheduledTasksPage(api: api),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Verify Title & Header
    expect(find.text('Scheduled tasks'), findsWidgets);
    expect(find.text('Create Task'), findsWidgets);

    // Verify Filter Row Elements
    expect(find.text('Search schedule title...'), findsOneWidget);
    expect(find.text('By Status'), findsOneWidget);
    expect(find.text('By Frequency'), findsOneWidget);
    expect(find.text('By Project'), findsOneWidget);

    // Verify Table Headers
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Repeats'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Next occurrence'), findsOneWidget);
    expect(find.text('Starts'), findsOneWidget);
    expect(find.text('Created by'), findsOneWidget);

    // Verify Schedule row data
    expect(find.text('Test for api'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('HRMS Rollout'), findsOneWidget);
    expect(find.text('Arun Kumar'), findsOneWidget);
    expect(find.text('Every week on Sunday at 09:00 for 1h (Asia/Kolkata)'), findsOneWidget);

    // Verify Pagination Bar
    expect(find.text('1–1 of 1'), findsOneWidget);
    expect(find.text('Rows'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);

    // Verify API was called with proper query params
    final scheduleCalls = recordedUris.where((u) => u.path.contains('/task-schedules')).toList();
    expect(scheduleCalls.isNotEmpty, isTrue);
    expect(scheduleCalls.first.queryParameters['page'], '1');
    expect(scheduleCalls.first.queryParameters['pageSize'], '20');
    expect(scheduleCalls.first.queryParameters['sortDir'], 'desc');
    expect(scheduleCalls.first.queryParameters['sortBy'], 'createdAt');
  });

  testWidgets('ScheduledTasksPage Status and Frequency filter sheets open and select options', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final recordedUris = <Uri>[];
    final api = createMockApi(recordedUris: recordedUris);

    await tester.pumpWidget(
      MaterialApp(
        home: ScheduledTasksPage(api: api),
      ),
    );

    await tester.pumpAndSettle();

    // Tap 'By Status'
    await tester.tap(find.text('By Status'));
    await tester.pumpAndSettle();

    // Verify Screenshot 4 options: Active, Ended, Cancelled
    expect(find.text('Filter by Status'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Ended'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);

    // Select Active
    await tester.tap(find.text('Active').last);
    await tester.pumpAndSettle();

    // Tap 'By Frequency'
    await tester.tap(find.text('By Frequency'));
    await tester.pumpAndSettle();

    // Verify Screenshot 3 options: Daily, Weekly, Monthly, Yearly
    expect(find.text('Filter by Frequency'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);

    // Select Weekly
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();

    // Verify filter parameters were included in query
    final lastCall = recordedUris.last;
    expect(lastCall.queryParameters['status'], 'ACTIVE');
    expect(lastCall.queryParameters['frequency'], 'WEEKLY');
  });

  testWidgets('ScheduledTasksPage opens detailed bottom sheet on row tap', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = createMockApi();

    await tester.pumpWidget(
      MaterialApp(
        home: ScheduledTasksPage(api: api),
      ),
    );

    await tester.pumpAndSettle();

    // Tap the item to open details sheet
    await tester.tap(find.text('Test for api'));
    await tester.pumpAndSettle();

    // Verify details sheet contents
    expect(find.text('Schedule Configuration'), findsOneWidget);
    expect(find.text('Next 5 Occurrences'), findsOneWidget);
    expect(find.text('Test description for recurring task'), findsOneWidget);
    expect(find.text('Asia/Kolkata'), findsOneWidget);
    expect(find.text('60 min'), findsOneWidget);
  });

  testWidgets('TaskDashboard renders Administration & Operations quick actions for admin', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = createMockApi();
    api.role = 'admin';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskDashboard(
            api: api,
            onTab: (_) {},
            profileTab: 4,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Admin header and badge
    expect(find.text('Administration & Operations'), findsOneWidget);
    expect(find.text('OPERATIONS'), findsOneWidget);
    expect(find.text('ADMINISTRATION'), findsOneWidget);

    // Verify OPERATIONS quick actions
    expect(find.text('Outlet Tasks'), findsOneWidget);
    expect(find.text('Outlets'), findsOneWidget);
    expect(find.text('Issues'), findsWidgets);
    expect(find.text('Calendar'), findsOneWidget);

    // Verify ADMINISTRATION quick actions
    expect(find.text('Categories & Templates'), findsOneWidget);
    expect(find.text('Scheduled Tasks'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
  });
}
