import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/all_tasks.dart';
import 'package:hr360_mobile/projects.dart';

void main() {
  final sampleEmployees = [
    {
      'id': '05b73711-b209-4f64-a1bd-c110581d1e69',
      'employeeCode': 'DEMO-E06',
      'fullName': 'Priya Raman',
      'designation': 'HR Manager',
      'department': 'Human Resources',
      'status': 'ACTIVE',
    },
    {
      'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
      'employeeCode': 'DEMO-E01',
      'fullName': 'Karthik Subramanian',
      'designation': 'Retail Lead',
      'department': 'Retail',
      'status': 'ACTIVE',
    },
  ];

  final sampleProjectsData = {
    'items': [
      {
        'id': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
        'code': 'DEMO-HRMS',
        'name': 'HRMS Rollout',
        'description': 'Roll out the unified HRMS platform',
        'status': 'ACTIVE',
        'owner': {'fullName': 'Priya Raman'},
        'startDate': '2026-09-22',
        'endDate': '2026-12-21',
        'taskCounts': {
          'total': 10,
          'completed': 0,
          'overdue': 6,
          'completionPercent': 0,
        },
      },
      {
        'id': 'aeeda2fb-a590-470f-86b8-6fb42b6eec81',
        'code': 'DEMO-RETAIL',
        'name': 'Retail Excellence',
        'description': 'Store operations quality programme',
        'status': 'ACTIVE',
        'owner': {'fullName': 'Karthik Subramanian'},
        'startDate': null,
        'endDate': null,
        'taskCounts': {
          'total': 30,
          'completed': 0,
          'overdue': 4,
          'completionPercent': 0,
        },
      },
    ],
    'page': 1,
    'pageSize': 20,
    'totalItems': 2,
    'totalPages': 1,
  };

  Api createMockApi() {
    final client = MockClient((request) async {
      final path = request.url.path;

      if (path.contains('/employees/lookup')) {
        return http.Response(
          jsonEncode({'success': true, 'data': sampleEmployees}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/projects')) {
        return http.Response(
          jsonEncode({'success': true, 'data': sampleProjectsData}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/tasks')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [],
              'total': 0,
              'page': 1,
              'pageSize': 20,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/task-categories') ||
          path.contains('/task-templates') ||
          path.contains('/teams') ||
          path.contains('/outlets')) {
        return http.Response(
          jsonEncode({'success': true, 'data': {'items': []}}),
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

    final api = Api(
      client: client,
    );
    api.token = 'test-token';
    api.role = 'ADMIN';
    return api;
  }

  testWidgets('ProjectsPage renders projects, cards, badges, and filters', (tester) async {
    final api = createMockApi();

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsPage(api: api),
      ),
    );

    // Initial pump and wait for API responses
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Projects'), findsWidgets);
    expect(
      find.text('Group related tasks, track completion and overdue work per project.'),
      findsOneWidget,
    );

    // Verify Filter controls
    expect(find.text('Search name or code...'), findsOneWidget);
    expect(find.text('By Status'), findsOneWidget);
    expect(find.text('By Owner'), findsOneWidget);
    expect(find.text('Include archived'), findsOneWidget);
    expect(find.textContaining('Sort:'), findsOneWidget);

    // Verify First Project Card: DEMO-HRMS
    expect(find.text('DEMO-HRMS'), findsOneWidget);
    expect(find.text('HRMS Rollout'), findsOneWidget);
    expect(find.text('Roll out the unified HRMS platform'), findsOneWidget);
    expect(find.text('Owner: Priya Raman'), findsOneWidget);
    expect(find.textContaining('6 overdue'), findsOneWidget);
    expect(find.text('0/10'), findsOneWidget);

    // Verify Second Project Card: DEMO-RETAIL
    expect(find.text('DEMO-RETAIL'), findsOneWidget);
    expect(find.text('Retail Excellence'), findsOneWidget);
    expect(find.text('Store operations quality programme'), findsOneWidget);
    expect(find.text('Owner: Karthik Subramanian'), findsOneWidget);
    expect(find.text('No dates'), findsOneWidget);
    expect(find.textContaining('4 overdue'), findsOneWidget);
    expect(find.text('0/30'), findsOneWidget);

    // Verify Pagination Bar
    expect(find.textContaining('1–2 of 2'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);

    // Toggle to List view
    final listIconFinder = find.byIcon(Icons.view_headline_rounded);
    if (listIconFinder.evaluate().isNotEmpty) {
      await tester.tap(listIconFinder);
      await tester.pumpAndSettle();
      expect(find.text('HRMS Rollout'), findsOneWidget);
    }
  });

  testWidgets('Tapping a project card opens AllTasksPage with initialProjectId', (tester) async {
    final api = createMockApi();

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsPage(api: api),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Tap on the HRMS Rollout card
    final hrmsCard = find.text('HRMS Rollout');
    expect(hrmsCard, findsOneWidget);
    await tester.tap(hrmsCard);
    await tester.pumpAndSettle();

    // Should push AllTasksPage
    expect(find.byType(AllTasksPage), findsOneWidget);
  });
}
