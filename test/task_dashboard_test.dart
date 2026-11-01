import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/task_dashboard.dart';

void main() {
  final sampleDashboardData = {
    'scope': 'SELF',
    'from': '2026-09-26',
    'to': '2026-10-25',
    'counts': {
      'total': 5,
      'todo': 5,
      'inProgress': 0,
      'completed': 0,
      'overdue': 4,
      'dueSoon': 0,
      'atRisk': 0,
      'unassigned': 0,
      'completionPercent': 0,
    },
    'trend': [
      {'period': '2026-10-22', 'created': 3, 'completed': 0},
      {'period': '2026-10-23', 'created': 2, 'completed': 0},
    ],
    'byPriority': [
      {'key': 'HIGH', 'total': 2, 'completed': 0, 'overdue': 1},
      {'key': 'URGENT', 'total': 2, 'completed': 0, 'overdue': 2},
      {'key': 'LOW', 'total': 1, 'completed': 0, 'overdue': 1},
    ],
    'byType': [
      {'key': 'GENERAL', 'total': 5, 'completed': 0, 'overdue': 4},
    ],
    'byProject': [
      {'key': 'HRMS Rollout', 'total': 4, 'completed': 0, 'overdue': 4},
      {'key': 'Retail Excellence', 'total': 1, 'completed': 0, 'overdue': 0},
    ],
    'byTeam': [
      {'key': 'No team', 'total': 4, 'completed': 0, 'overdue': 3},
      {'key': 'Platform Team', 'total': 1, 'completed': 0, 'overdue': 1},
    ],
    'issues': {
      'total': 0,
      'open': 0,
      'inProgress': 0,
      'resolved': 0,
      'highPriorityOpen': 0,
    },
  };

  final sampleProjects = {
    'items': [
      {
        'id': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
        'code': 'DEMO-HRMS',
        'name': 'HRMS Rollout',
        'color': '#6366f1',
      },
      {
        'id': 'aeeda2fb-a590-470f-86b8-6fb42b6eec81',
        'code': 'DEMO-RETAIL',
        'name': 'Retail Excellence',
        'color': '#10b981',
      },
    ],
  };

  final sampleTeams = {
    'items': [
      {
        'id': '0e29dcc3-db9e-4125-94ce-e9c369d4f04b',
        'code': 'DEMO-PLATFORM',
        'name': 'Platform Team',
      },
    ],
  };

  final sampleEmployees = [
    {
      'id': '05b73711-b209-4f64-a1bd-c110581d1e69',
      'employeeCode': 'DEMO-E06',
      'fullName': 'Anitha Devi',
      'designation': 'Operations Executive',
      'department': 'Operations',
      'status': 'ACTIVE',
    },
    {
      'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
      'employeeCode': 'DEMO-E01',
      'fullName': 'Arun Kumar',
      'designation': 'Software Engineer',
      'department': 'Engineering',
      'status': 'ACTIVE',
    },
  ];

  Api createMockApi() {
    return Api(
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/reports/tasks/dashboard')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleDashboardData}),
            200,
          );
        }
        if (path.contains('/projects')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleProjects}),
            200,
          );
        }
        if (path.contains('/teams')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleTeams}),
            200,
          );
        }
        if (path.contains('/employees/lookup')) {
          return http.Response(
            jsonEncode({'success': true, 'data': sampleEmployees}),
            200,
          );
        }
        return http.Response('{"success": true, "data": {}}', 200);
      }),
    );
  }

  testWidgets('TaskDashboard renders header, filters, 10 stat cards and all charts without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = createMockApi();
    api.profile = {
      'name': 'Arun Kumar',
      'scope': 'SELF',
      'office': {'timezone': 'Asia/Kolkata'},
    };

    var selectedTab = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskDashboard(
            api: api,
            onTab: (tab) => selectedTab = tab,
            profileTab: 4,
            issuesTab: 2,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 1. Header
    expect(find.text('Task dashboard'), findsOneWidget);
    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('Create task'), findsOneWidget);

    // Tap "My tasks"
    await tester.tap(find.text('My tasks'));
    expect(selectedTab, 1);

    // 2. Filter Card
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('By Date'), findsOneWidget);
    expect(find.text('By Project'), findsOneWidget);
    expect(find.text('By Team'), findsOneWidget);
    expect(find.text('By Assignee Name...'), findsOneWidget);
    expect(find.text('By Status'), findsOneWidget);
    expect(find.text('By Priority'), findsOneWidget);
    expect(find.text('By Type'), findsOneWidget);

    // 3. 10 Stat Cards
    expect(find.text('Total tasks'), findsOneWidget);
    expect(find.text('To Do'), findsWidgets);
    expect(find.text('In Progress'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Completion'), findsOneWidget);
    expect(find.text('Overdue'), findsWidgets);
    expect(find.text('Due soon'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.text('At risk'), findsOneWidget);
    expect(find.text('Issues'), findsOneWidget);

    // 4. Verify charts & widgets from Status distribution downwards are removed
    expect(find.text('Status distribution'), findsNothing);
    expect(find.text('By priority'), findsNothing);
    expect(find.text('Issues by status'), findsNothing);
    expect(find.text('Created vs completed'), findsNothing);
    expect(find.text('By task type'), findsNothing);
    expect(find.text('By project'), findsNothing);
    expect(find.text('By team'), findsNothing);
    expect(find.text('Overdue by project'), findsNothing);

    // 5. Scroll back up and test Assignee Bottom Sheet with Search Field
    await tester.scrollUntilVisible(find.text('By Assignee Name...'), -300);
    await tester.tap(find.text('By Assignee Name...'));
    await tester.pumpAndSettle();
    expect(find.text('Select Assignee'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Anitha Devi'), findsOneWidget);
    expect(find.text('Arun Kumar'), findsWidgets);

    // Type in search field
    await tester.enterText(find.byType(TextField), 'Anitha');
    await tester.pumpAndSettle();
    expect(find.text('Anitha Devi'), findsOneWidget);
    expect(find.text('Arun Kumar'), findsNothing);

    // Select Anitha
    await tester.tap(find.text('Anitha Devi'));
    await tester.pumpAndSettle();
    expect(find.text('Anitha Devi'), findsOneWidget); // Filter button now shows selected name
    expect(find.text('Filters applied'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);

    // Clear filters
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('By Assignee Name...'), findsOneWidget);

    api.dispose();
  });
}
