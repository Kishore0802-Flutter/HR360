import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/tasks.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);
  final sampleIssuesResponse = {
    'items': [
      {
        'id': '7bb3ca04-182a-4917-9057-185bb86e95bf',
        'code': 'ISS-00003',
        'title': 'Testing issues',
        'description': 'Sample issue description',
        'category': 'GENERAL',
        'priority': 'MEDIUM',
        'status': 'OPEN',
        'reporter': {
          'id': 'c130d721-2996-4044-b0e0-b8acead02a5b',
          'employeeCode': 'FC-001',
          'fullName': 'Prathap P',
          'email': 'prathap@fc.com',
          'status': 'ACTIVE',
        },
        'assignee': {
          'id': 'd115f367-7b6e-4d8b-86be-a7b3ca2a0ec7',
          'employeeCode': 'CG34R34',
          'fullName': 'Manager',
          'email': 'manager@gmail.com',
          'status': 'ACTIVE',
        },
        'project': {
          'id': 'cbf8c128-1133-46e8-9b58-8ea05750e161',
          'name': 'CRM',
          'code': 'PROJECT_1',
        },
        'outlet': {
          'id': '01cdd85a-1ad5-4ef2-82df-50c7d6361f5a',
          'name': 'Anna Nagar Store',
          'code': 'DEMO-ANNA',
        },
        'task': {
          'id': 'a57d2515-2471-49cf-b53e-de0873245f20',
          'title': 'testing',
          'status': 'TODO',
        },
        'resolutionNote': null,
        'resolvedBy': null,
        'resolvedAt': null,
        'reopenCount': 0,
        'createdAt': '2026-10-23T14:01:10.456Z',
        'updatedAt': '2026-10-23T14:01:10.456Z',
      },
      {
        'id': '563f97d1-8293-4742-b906-3e4e3a6bc60b',
        'code': 'ISS-00001',
        'title': 'Billing printer not working',
        'description': 'Printer at counter 2 shows paper jam error.',
        'category': 'EQUIPMENT',
        'priority': 'HIGH',
        'status': 'OPEN',
        'reporter': {
          'id': '05b73711-b209-4f64-a1bd-c110581d1e69',
          'employeeCode': 'DEMO-E06',
          'fullName': 'Anitha Devi',
          'email': 'anitha@giraffai.in',
          'status': 'ACTIVE',
        },
        'assignee': {
          'id': '42bc8eb5-bd7d-4f71-960f-7eac570e6fd7',
          'employeeCode': 'DEMO-M02',
          'fullName': 'Karthik Subramanian',
          'email': 'ops.manager@giraffai.in',
          'status': 'ACTIVE',
        },
        'project': {
          'id': 'aeeda2fb-a590-470f-86b8-6fb42b6eec81',
          'name': 'Retail Excellence',
          'code': 'DEMO-RETAIL',
        },
        'outlet': {
          'id': 'f6a3e93e-304a-49ae-9955-f7cb13973794',
          'name': 'T. Nagar Store',
          'code': 'DEMO-TNAGAR',
        },
        'task': null,
        'resolutionNote': null,
        'resolvedBy': null,
        'resolvedAt': null,
        'reopenCount': 0,
        'createdAt': '2026-10-22T14:03:38.357Z',
        'updatedAt': '2026-10-22T14:03:38.357Z',
      },
      {
        'id': '8ed0d28a-921a-4617-8b9e-63a268a3d123',
        'code': 'ISS-00002',
        'title': 'VPN access for new joiners',
        'description': null,
        'category': 'IT',
        'priority': 'MEDIUM',
        'status': 'IN_PROGRESS',
        'reporter': {
          'id': '3e658d68-ec6b-46c8-b9b6-16ab10941349',
          'employeeCode': 'DEMO-E02',
          'fullName': 'Divya Lakshmi',
          'email': 'divya@giraffai.in',
          'status': 'ACTIVE',
        },
        'assignee': {
          'id': '4e786537-67d0-4c4a-bb8d-758df45437e8',
          'employeeCode': 'DEMO-M01',
          'fullName': 'Priya Raman',
          'email': 'manager@giraffai.in',
          'status': 'ACTIVE',
        },
        'project': {
          'id': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
          'name': 'HRMS Rollout',
          'code': 'DEMO-HRMS',
        },
        'outlet': null,
        'task': null,
        'resolutionNote': null,
        'resolvedBy': null,
        'resolvedAt': null,
        'reopenCount': 0,
        'createdAt': '2026-10-22T14:03:38.357Z',
        'updatedAt': '2026-10-22T14:03:38.357Z',
      },
    ],
    'page': 1,
    'pageSize': 20,
    'totalItems': 3,
    'totalPages': 1,
  };

  Api createMockApi({List<http.Request>? recordedRequests}) {
    final client = MockClient((request) async {
      recordedRequests?.add(request);
      final path = request.url.path;

      if (path.contains('/issues')) {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': sampleIssuesResponse,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'new-issue-1234',
                'code': 'ISS-00004',
                'title': payload['title'],
                'description': payload['description'],
                'category': payload['category'] ?? 'GENERAL',
                'priority': payload['priority'] ?? 'MEDIUM',
                'status': 'OPEN',
                'createdAt': DateTime.now().toUtc().toIso8601String(),
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'PATCH') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': '7bb3ca04-182a-4917-9057-185bb86e95bf',
                'status': payload['status'],
                'resolutionNote': payload['resolutionNote'],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      }

      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    return Api(client: client);
  }

  Widget buildTestScreen(Api api) {
    return MaterialApp(
      home: Scaffold(
        body: IssuesPage(api: api),
      ),
    );
  }

  testWidgets('IssuesPage fetches GET /issues with pagination and sort params', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<http.Request> requests = [];
    final api = createMockApi(recordedRequests: requests);

    await tester.pumpWidget(buildTestScreen(api));
    await tester.pumpAndSettle();

    expect(find.text('Testing issues'), findsOneWidget);
    expect(find.text('Billing printer not working'), findsOneWidget);
    expect(find.text('VPN access for new joiners'), findsOneWidget);

    // Verify GET request query parameters
    final initialGet = requests.firstWhere((r) => r.method == 'GET' && r.url.path.contains('/issues'));
    expect(initialGet.url.queryParameters['page'], '1');
    expect(initialGet.url.queryParameters['pageSize'], '20');
    expect(initialGet.url.queryParameters['sortDir'], 'desc');
    expect(initialGet.url.queryParameters['sortBy'], 'createdAt');
  });

  testWidgets('IssuesPage opens details modal sheet on card tap and shows metadata', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = createMockApi();

    await tester.pumpWidget(buildTestScreen(api));
    await tester.pumpAndSettle();

    // Tap on the first issue card
    await tester.tap(find.text('Testing issues'));
    await tester.pumpAndSettle();

    // Should display details in modal bottom sheet
    expect(find.text('ISS-00003'), findsWidgets);
    expect(find.text('Prathap P (FC-001)'), findsOneWidget);
    expect(find.text('Manager (CG34R34)'), findsOneWidget);
    expect(find.text('testing (TODO)'), findsOneWidget);
    expect(find.text('Start Progress'), findsOneWidget);
    expect(find.text('Resolve Issue'), findsOneWidget);
  });

  testWidgets('IssuesPage status transition sends PATCH /issues/:id', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<http.Request> requests = [];
    final api = createMockApi(recordedRequests: requests);

    await tester.pumpWidget(buildTestScreen(api));
    await tester.pumpAndSettle();

    // Tap on the first issue card
    await tester.tap(find.text('Testing issues'));
    await tester.pumpAndSettle();

    // Tap Start Progress
    await tester.tap(find.text('Start Progress'));
    await tester.pumpAndSettle();

    final patchReq = requests.firstWhere((r) => r.method == 'PATCH');
    expect(patchReq.url.path, '/api/v1/issues/7bb3ca04-182a-4917-9057-185bb86e95bf');
    final body = jsonDecode(patchReq.body) as Map<String, dynamic>;
    expect(body['status'], 'IN_PROGRESS');
  });

  testWidgets('IssuesPage can create a new issue via POST /issues', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<http.Request> requests = [];
    final api = createMockApi(recordedRequests: requests);

    await tester.pumpWidget(buildTestScreen(api));
    await tester.pumpAndSettle();

    // Tap plus icon button in header
    final addBtn = find.byIcon(Icons.add_rounded);
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.text('Report New Issue'), findsOneWidget);

    // Enter title into the dialog's title TextField (hint: 'e.g. Printer at counter 2 jammed')
    final titleField = find.widgetWithText(TextField, 'e.g. Printer at counter 2 jammed');
    expect(titleField, findsOneWidget);
    await tester.enterText(titleField, 'Faulty AC unit');
    await tester.pumpAndSettle();

    // Tap Submit Issue
    await tester.tap(find.text('Submit Issue'));
    await tester.pumpAndSettle();

    final postReq = requests.firstWhere((r) => r.method == 'POST');
    expect(postReq.url.path, '/api/v1/issues');
    final body = jsonDecode(postReq.body) as Map<String, dynamic>;
    expect(body['title'], 'Faulty AC unit');
    expect(body['category'], 'GENERAL');
    expect(body['priority'], 'MEDIUM');
  });
}
