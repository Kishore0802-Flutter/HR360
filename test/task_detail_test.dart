import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/task_detail_sheet.dart';

void main() {
  final sampleDetail = {
    'id': '4d6552b8-4f0e-40d1-ad5b-baea0ad51b75',
    'code': 'TSK-00191',
    'title': 'Test from mobile',
    'description': 'Test vtest test',
    'taskType': 'GENERAL',
    'status': 'TODO',
    'priority': 'MEDIUM',
    'startAt': null,
    'dueAt': null,
    'timezone': 'Asia/Kolkata',
    'durationMinutes': null,
    'isOverdue': false,
    'assignmentMode': 'SINGLE',
    'project': {
      'id': 'cbf8c128-1133-46e8-9b58-8ea05750e161',
      'code': 'PROJECT_1',
      'name': 'CRM',
      'color': '#6366f1',
      'status': 'ACTIVE',
    },
    'category': {
      'id': '7f7e7a26-00d8-4570-837c-af56be7a0e8c',
      'name': 'Development',
    },
    'creator': {
      'id': 'a3c1d986-335d-43d0-b52f-c3cc7832739b',
      'fullName': 'System Administrator',
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
    'comments': [
      {
        'id': 'e32e4101-b5e4-4cd1-9aef-c6c9c7abb6c4',
        'body': '3e5',
        'createdAt': '2026-11-01T17:58:18.769Z',
        'author': {
          'id': 'a3c1d986-335d-43d0-b52f-c3cc7832739b',
          'fullName': 'System Administrator',
        },
      },
    ],
    'activity': [
      {
        'id': 'cd011a64-0d6d-4566-82c3-ca58735e7760',
        'type': 'CREATED',
        'data': {'scheduleId': null, 'assigneeIds': []},
        'createdAt': '2026-11-01T17:33:49.916Z',
        'actor': {
          'id': 'a3c1d986-335d-43d0-b52f-c3cc7832739b',
          'fullName': 'System Administrator',
        },
      },
    ],
    'permissions': {
      'canEdit': true,
      'canDelete': true,
      'canAssign': true,
      'canUpdateStatus': true,
      'canReopen': true,
      'canAddSubtask': true,
      'canComment': true,
    },
  };

  testWidgets('TaskDetailSheet calls GET /tasks/:id, renders details, and updates status with POST /tasks/:id/status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool getTaskCalled = false;
    bool postStatusCalled = false;
    Map<String, dynamic>? postedStatusBody;

    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path;

        if (path == '/api/v1/tasks/4d6552b8-4f0e-40d1-ad5b-baea0ad51b75' && request.method == 'GET') {
          getTaskCalled = true;
          return http.Response(
            jsonEncode({'success': true, 'data': sampleDetail}),
            200,
          );
        }

        if (path == '/api/v1/tasks/4d6552b8-4f0e-40d1-ad5b-baea0ad51b75/status' && request.method == 'POST') {
          postStatusCalled = true;
          postedStatusBody = jsonDecode(request.body) as Map<String, dynamic>;
          final updated = Map<String, dynamic>.from(sampleDetail);
          updated['status'] = postedStatusBody!['status'];
          return http.Response(
            jsonEncode({'success': true, 'data': updated}),
            200,
          );
        }

        return http.Response(jsonEncode({'success': true}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => TaskDetailSheet.show(
                ctx,
                task: sampleDetail,
                api: api,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(getTaskCalled, isTrue);

    // Verify task details are visible
    expect(find.text('TSK-00191'), findsOneWidget);
    expect(find.text('Test from mobile'), findsOneWidget);
    expect(find.text('Test vtest test'), findsOneWidget);
    expect(find.text('CRM'), findsWidgets);
    expect(find.text('Development'), findsWidgets);
    expect(find.text('System Administrator'), findsWidgets);
    expect(find.text('Arun Kumar'), findsOneWidget);

    // Status transition: tap "Start task"
    expect(find.text('Start task'), findsOneWidget);
    await tester.tap(find.text('Start task'));
    await tester.pumpAndSettle();

    expect(postStatusCalled, isTrue);
    expect(postedStatusBody?['status'], 'IN_PROGRESS');
  });

  testWidgets('TaskDetailSheet completes task via POST /tasks/:id/complete with comment', (tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool completeCalled = false;
    Map<String, dynamic>? completeBody;

    final inProgressTask = Map<String, dynamic>.from(sampleDetail);
    inProgressTask['status'] = 'IN_PROGRESS';

    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path;

        if (path == '/api/v1/tasks/4d6552b8-4f0e-40d1-ad5b-baea0ad51b75' && request.method == 'GET') {
          return http.Response(
            jsonEncode({'success': true, 'data': inProgressTask}),
            200,
          );
        }

        if (path == '/api/v1/tasks/4d6552b8-4f0e-40d1-ad5b-baea0ad51b75/complete' && request.method == 'POST') {
          completeCalled = true;
          completeBody = jsonDecode(request.body) as Map<String, dynamic>;
          final completed = Map<String, dynamic>.from(inProgressTask);
          completed['status'] = 'COMPLETED';
          return http.Response(
            jsonEncode({'success': true, 'data': completed}),
            200,
          );
        }

        return http.Response(jsonEncode({'success': true}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => TaskDetailSheet.show(
                ctx,
                task: inProgressTask,
                api: api,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Complete button
    expect(find.text('Complete'), findsOneWidget);
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Complete TSK-00191?'), findsOneWidget);
    expect(find.text('Completion note (optional, added as a comment)'), findsOneWidget);

    // Enter completion note
    await tester.enterText(find.byType(TextField).last, '3e5');
    await tester.pumpAndSettle();

    // Tap "Mark completed"
    await tester.tap(find.text('Mark completed'));
    await tester.pumpAndSettle();

    expect(completeCalled, isTrue);
    expect(completeBody?['comment'], '3e5');
  });

  testWidgets('TaskDetailSheet reopens task via POST /tasks/:id/reopen with reason', (tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool reopenCalled = false;
    Map<String, dynamic>? reopenBody;

    final completedTask = Map<String, dynamic>.from(sampleDetail);
    completedTask['status'] = 'COMPLETED';

    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path;

        if (path == '/api/v1/tasks/4d6552b8-4f0e-40d1-ad5b-baea0ad51b75' && request.method == 'GET') {
          return http.Response(
            jsonEncode({'success': true, 'data': completedTask}),
            200,
          );
        }

        if (path == '/api/v1/tasks/4d6552b8-4f0e-40d1-ad5b-baea0ad51b75/reopen' && request.method == 'POST') {
          reopenCalled = true;
          reopenBody = jsonDecode(request.body) as Map<String, dynamic>;
          final reopened = Map<String, dynamic>.from(completedTask);
          reopened['status'] = 'TODO';
          return http.Response(
            jsonEncode({'success': true, 'data': reopened}),
            200,
          );
        }

        return http.Response(jsonEncode({'success': true}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => TaskDetailSheet.show(
                ctx,
                task: completedTask,
                api: api,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Reopen task button
    expect(find.text('Reopen task'), findsOneWidget);
    await tester.tap(find.text('Reopen task'));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Reopen TSK-00191?'), findsOneWidget);

    // Enter reason
    await tester.enterText(find.byType(TextField).last, '2442');
    await tester.pumpAndSettle();

    // Confirm
    await tester.tap(find.text('Reopen task').last);
    await tester.pumpAndSettle();

    expect(reopenCalled, isTrue);
    expect(reopenBody?['reason'], '2442');
  });

  testWidgets('TaskDetailSheet edits task with PATCH /tasks/:id', (tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool patchCalled = false;
    Map<String, dynamic>? patchBody;

    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path;

        if (path == '/api/v1/tasks/4d6552b8-4f0e-40d1-ad5b-baea0ad51b75' && request.method == 'GET') {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleDetail}),
            200,
          );
        }

        if (path == '/api/v1/tasks/4d6552b8-4f0e-40d1-ad5b-baea0ad51b75' && request.method == 'PATCH') {
          patchCalled = true;
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          final updated = Map<String, dynamic>.from(sampleDetail);
          updated['title'] = patchBody!['title'];
          return http.Response(
            jsonEncode({'success': true, 'data': updated}),
            200,
          );
        }

        return http.Response(jsonEncode({'success': true}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => TaskDetailSheet.show(
                ctx,
                task: sampleDetail,
                api: api,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Edit button
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget);

    // Change title
    final dialogTextFields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(dialogTextFields.first, 'Test from mobile23');
    await tester.pumpAndSettle();

    // Tap Save changes
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(patchCalled, isTrue);
    expect(patchBody?['title'], 'Test from mobile23');
  });
}
