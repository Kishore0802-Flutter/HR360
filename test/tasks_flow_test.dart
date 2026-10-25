import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr360_mobile/all_tasks.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/create_task.dart';

void main() {
  final sampleCategories = {
    'items': [
      {
        'id': 'b275986b-3f91-41a1-99f3-4343bd81ccfe',
        'code': 'AUDIT',
        'name': 'Audit',
        'appliesTo': 'OUTLET',
        'status': 'ACTIVE',
      },
      {
        'id': '7f7e7a26-00d8-4570-837c-af56be7a0e8c',
        'code': 'DEV',
        'name': 'Development',
        'appliesTo': 'GENERAL',
        'status': 'ACTIVE',
      },
    ],
    'page': 1,
    'pageSize': 200,
    'totalItems': 2,
    'totalPages': 1,
  };

  final sampleProjects = {
    'items': [
      {
        'id': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
        'code': 'DEMO-HRMS',
        'name': 'HRMS Rollout',
        'status': 'ACTIVE',
        'color': '#6366f1',
      },
    ],
    'page': 1,
    'pageSize': 50,
    'totalItems': 1,
    'totalPages': 1,
  };

  final sampleEmployees = [
    {
      'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
      'employeeCode': 'DEMO-E01',
      'fullName': 'Arun Kumar',
      'status': 'ACTIVE',
    },
    {
      'id': '3e658d68-ec6b-46c8-b9b6-16ab10941349',
      'employeeCode': 'DEMO-E02',
      'fullName': 'Divya Lakshmi',
      'status': 'ACTIVE',
    },
  ];

  final sampleTasksResponse = {
    'items': [
      {
        'id': '0ec4dc86-4dad-4313-a3c0-d690e58ff92e',
        'code': 'TSK-00149',
        'title': 'Test for api',
        'description': 'Test description instructions',
        'taskType': 'GENERAL',
        'status': 'TODO',
        'priority': 'MEDIUM',
        'startAt': '2026-10-25T03:30:00.000Z',
        'dueAt': '2026-10-25T04:30:00.000Z',
        'timezone': 'Asia/Kolkata',
        'durationMinutes': 60,
        'isOverdue': true,
        'project': {
          'id': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
          'code': 'DEMO-HRMS',
          'name': 'HRMS Rollout',
          'color': '#6366f1',
          'status': 'ACTIVE',
        },
        'category': {
          'id': 'b275986b-3f91-41a1-99f3-4343bd81ccfe',
          'name': 'Audit',
        },
        'assignees': [
          {
            'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
            'fullName': 'Arun Kumar',
            'employeeCode': 'DEMO-E01',
          },
        ],
        'watchers': [
          {
            'id': '3e658d68-ec6b-46c8-b9b6-16ab10941349',
            'fullName': 'Divya Lakshmi',
          },
        ],
        'scheduleId': 'ea1e9ac5-b530-40fc-ac4e-e1f75142db24',
        'schedule': {
          'summary': 'Every week on Sunday at 09:00 for 1h (Asia/Kolkata)',
        },
        'subtaskCount': 2,
        'subtaskCompleted': 1,
      },
      {
        'id': 'ac96a99f-c20d-4a0d-bc40-15fcaf4b015f',
        'code': 'TSK-00142',
        'title': 'Social media content plan',
        'description': 'Plan marketing content for sprint',
        'taskType': 'GENERAL',
        'status': 'IN_PROGRESS',
        'priority': 'HIGH',
        'startAt': '2026-10-23T10:33:00.000Z',
        'dueAt': null,
        'timezone': 'Asia/Kolkata',
        'durationMinutes': null,
        'isOverdue': false,
        'project': {
          'id': 'aeeda2fb-a590-470f-86b8-6fb42b6eec81',
          'code': 'DEMO-RETAIL',
          'name': 'Retail Excellence',
          'color': '#10b981',
          'status': 'ACTIVE',
        },
        'category': {
          'id': '7f7e7a26-00d8-4570-837c-af56be7a0e8c',
          'name': 'Development',
        },
        'assignees': [
          {
            'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
            'fullName': 'Arun Kumar',
            'employeeCode': 'DEMO-E01',
          },
        ],
        'watchers': [],
        'subtaskCount': 0,
        'subtaskCompleted': 0,
      },
    ],
    'page': 1,
    'pageSize': 20,
    'totalItems': 2,
    'totalPages': 1,
  };

  Api createMockApi({
    void Function(http.Request)? onPostTask,
    void Function(http.Request)? onGetTasks,
  }) {
    return Api(
      client: MockClient((request) async {
        final path = request.url.path;

        if (path.contains('/task-categories')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleCategories}),
            200,
          );
        }

        if (path.contains('/projects')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleProjects}),
            200,
          );
        }

        if (path.contains('/employees/lookup')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleEmployees}),
            200,
          );
        }

        if (path == '/api/v1/tasks' && request.method == 'POST') {
          onPostTask?.call(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'new-task-uuid',
                'title': 'Test for api',
              },
            }),
            201,
          );
        }

        if (path.contains('/tasks') && request.method == 'GET') {
          onGetTasks?.call(request);
          return http.Response(
            jsonEncode({'success': true, 'data': sampleTasksResponse}),
            200,
          );
        }

        return http.Response('{"success": true, "data": {}}', 200);
      }),
    );
  }

  testWidgets('CreateTaskPage renders form cards, toggles repeat, and validates input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = createMockApi();
    api.profile = {'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53', 'name': 'Arun Kumar'};

    await tester.pumpWidget(
      MaterialApp(
        home: CreateTaskPage(api: api),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 1. Verify Header and Cards
    expect(find.text('Create task'), findsWidgets);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);

    // Verify Title field
    expect(find.text('e.g. Prepare monthly sales report'), findsOneWidget);

    // Verify Repeat Switch initially off
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Task timezone', findRichText: true), findsOneWidget);

    // 2. Toggle Repeat switch on
    final repeatSwitch = find.byType(Switch);
    expect(repeatSwitch, findsOneWidget);
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      // ignore: avoid_print
      print('TEST1_OVERFLOW: ${details.toDiagnosticsNode().toStringDeep()}');
      oldHandler?.call(details);
    };
    await tester.tap(repeatSwitch);
    await tester.pumpAndSettle();
    FlutterError.onError = oldHandler;

    // Now recurrence controls and live preview should be visible
    expect(find.text('Repeats *', findRichText: true), findsOneWidget);
    expect(find.text('Every *', findRichText: true), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);

    // 3. Fill Title
    await tester.enterText(find.byType(TextFormField).first, 'Prepare Sales Deck');
    await tester.pumpAndSettle();

    // 4. Verify Create button label changes to "Create recurring task"
    expect(find.text('Create recurring task'), findsOneWidget);
  });

  testWidgets('CreateTaskPage submits POST /tasks and creates task', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool postCalled = false;
    Map<String, dynamic>? postedBody;

    final api = createMockApi(
      onPostTask: (req) {
        postCalled = true;
        postedBody = jsonDecode(req.body);
      },
    );
    api.profile = {'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53', 'name': 'Arun Kumar'};

    bool createdCallbackFired = false;

    await tester.pumpWidget(
      MaterialApp(
        home: CreateTaskPage(
          api: api,
          onCreated: () => createdCallbackFired = true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Enter title
    await tester.enterText(find.byType(TextFormField).first, 'Sprint Planning');
    await tester.pumpAndSettle();

    // Tap submit button with add_task_rounded icon
    await tester.tap(find.byIcon(Icons.add_task_rounded));
    await tester.pumpAndSettle();

    expect(postCalled, isTrue);
    expect(postedBody?['title'], 'Sprint Planning');
    expect(postedBody?['taskType'], 'GENERAL');
    expect(postedBody?['priority'], 'MEDIUM');
    expect(createdCallbackFired, isTrue);

    // Should navigate to AllTasksPage
    expect(find.byType(AllTasksPage), findsOneWidget);
  });

  testWidgets('AllTasksPage renders paginated tasks, search, filter pills, and task details sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = createMockApi();

    await tester.pumpWidget(
      MaterialApp(
        home: AllTasksPage(api: api),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Header & Summary
    expect(find.text('All tasks'), findsWidgets);
    expect(find.text('1–2 of 2'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);

    // Filter pills
    expect(find.text('All'), findsOneWidget);
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('In Progress'), findsWidgets);
    expect(find.text('Completed'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Overdue'), findsWidgets);

    // Task items
    expect(find.text('TSK-00149'), findsOneWidget);
    expect(find.text('Test for api'), findsOneWidget);
    expect(find.text('HRMS Rollout'), findsOneWidget);
    expect(find.text('TSK-00142'), findsOneWidget);
    expect(find.text('Social media content plan'), findsOneWidget);

    // Search filter test
    await tester.enterText(find.byType(TextField).first, 'Social');
    await tester.pumpAndSettle();

    expect(find.text('Social media content plan'), findsOneWidget);
    expect(find.text('Test for api'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Test for api'), findsOneWidget);

    // Tap a task card to open detailed sheet
    await tester.tap(find.text('Test for api'));
    await tester.pumpAndSettle();

    // Verify task detail sheet opened
    expect(find.text('Context'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Test description instructions'), findsOneWidget);
    expect(find.text('Every week on Sunday at 09:00 for 1h (Asia/Kolkata)'), findsOneWidget);
  });
}
