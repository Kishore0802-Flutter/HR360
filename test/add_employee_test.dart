import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/directory.dart';
import 'package:hr360_mobile/employee_detail.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final createdEmployeeResponse = {
    'success': true,
    'data': {
      'id': '94adac0d-5726-4b54-99cf-cef857fc89cc',
      'employeeCode': 'EM01',
      'firstName': 'Kk',
      'lastName': 'Ku',
      'fullName': 'Kk Ku',
      'email': 'kis@252.com',
      'phone': '252 262 2622',
      'joiningDate': '2026-10-25',
      'employmentType': 'FULL_TIME',
      'workLocation': null,
      'status': 'ACTIVE',
      'department': {
        'id': '474a8d8f-3a6c-4ee4-ba72-78401295caf7',
        'name': 'Human Resources'
      },
      'designation': {
        'id': 'a1817bfd-ffd5-48c3-94d9-16776c7ab64a',
        'title': 'Manager'
      },
      'account': {
        'userId': '4e3358a1-1bd5-4ccf-b2af-d33fdd9038e2',
        'status': 'ACTIVE',
        'roles': [
          {
            'id': 'e49cc17f-10a6-4e14-82f5-7c927ef7f660',
            'code': 'EMPLOYEE',
            'name': 'Employee'
          }
        ]
      },
    },
  };

  testWidgets('EmployeesPage shows Add employee button for Admin / Super Admin and navigates to AddEmployeePage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/employees')) {
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
      'id': 'super-admin-id',
      'name': 'Super Admin',
      'email': 'admin@fc.com',
      'is_super_admin': true,
      'role': 'SUPER_ADMIN',
      'roles': [
        {'code': 'SUPER_ADMIN', 'name': 'Super Admin'}
      ],
      'permissions': ['employees:create', 'roles:manage'],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeesPage(api: api),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Add employee button is visible
    final addBtn = find.text('Add employee');
    expect(addBtn, findsWidgets);

    // Tap Add employee button
    await tester.tap(addBtn.first);
    await tester.pumpAndSettle();

    // Verify AddEmployeePage rendered
    expect(find.byType(AddEmployeePage), findsOneWidget);
    expect(find.text('Employees / New'), findsOneWidget);
    expect(find.text('Basic details'), findsOneWidget);
    expect(find.text('Employment'), findsOneWidget);
    expect(find.text('Login account'), findsOneWidget);
    expect(find.text('Create employee'), findsOneWidget);
  });

  testWidgets('EmployeesPage hides Add employee button for regular Employee', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = Api(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'items': [], 'total': 0},
          }),
          200,
        );
      }),
    );

    api.profile = {
      'id': 'regular-emp-id',
      'name': 'Regular Employee',
      'email': 'emp@fc.com',
      'is_super_admin': false,
      'role': 'EMPLOYEE',
      'roles': [
        {'code': 'EMPLOYEE', 'name': 'Employee'}
      ],
      'permissions': ['attendance:create'],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeesPage(api: api),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Add employee button is NOT visible for regular employee
    expect(find.text('Add employee'), findsNothing);
  });

  testWidgets('AddEmployeePage validates required fields and submits POST /employees', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Map<String, dynamic>? submittedBody;

    final api = Api(
      client: MockClient((request) async {
        if (request.method == 'POST' && request.url.path.contains('/employees')) {
          submittedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(createdEmployeeResponse), 201);
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
      'id': 'admin-id',
      'name': 'Admin User',
      'is_super_admin': true,
      'role': 'ADMIN',
    };

    bool didPopWithSuccess = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                final res = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEmployeePage(api: api),
                  ),
                );
                if (res == true) didPopWithSuccess = true;
              },
              child: const Text('Open Add'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Add'));
    await tester.pumpAndSettle();

    // Verify initial role cards
    expect(find.text('Admin · Organisation data'), findsOneWidget);
    expect(find.text('Employee · Own data'), findsOneWidget);
    expect(find.text('Manager · Team data'), findsOneWidget);
    expect(find.text('Super Admin · Organisation data'), findsOneWidget);

    // Fill form matching user request
    final codeField = find.widgetWithText(TextFormField, 'e.g. EM01');
    final firstField = find.widgetWithText(TextFormField, 'e.g. John');
    final lastField = find.widgetWithText(TextFormField, 'e.g. Doe');
    final emailField = find.widgetWithText(TextFormField, 'e.g. john.doe@company.com');
    final phoneField = find.widgetWithText(TextFormField, 'e.g. 252 262 2622');

    await tester.enterText(codeField, 'EM01');
    await tester.enterText(firstField, 'Kk');
    await tester.enterText(lastField, 'Ku');
    await tester.enterText(emailField, 'Kis@252.com');
    await tester.enterText(phoneField, '252 262 2622');

    // Tap Create employee
    await tester.tap(find.text('Create employee'));
    await tester.pumpAndSettle();

    // Verify API POST body
    expect(submittedBody, isNotNull);
    expect(submittedBody!['employeeCode'], equals('EM01'));
    expect(submittedBody!['firstName'], equals('Kk'));
    expect(submittedBody!['lastName'], equals('Ku'));
    expect(submittedBody!['email'], equals('Kis@252.com'));
    expect(submittedBody!['phone'], equals('252 262 2622'));
    expect(submittedBody!['employmentType'], equals('FULL_TIME'));
    expect(submittedBody!['createAccount'], isTrue);
    expect((submittedBody!['roleIds'] as List), isNotEmpty);

    // Verify popped with success
    expect(didPopWithSuccess, isTrue);
  });

  testWidgets('EditEmployeePage pre-populates data and submits PATCH /employees/:id with exact payload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final employeeToEditData = {
      'id': 'a3c1d986-335d-43d0-b52f-c3cc7832739b',
      'employeeCode': 'ADM001',
      'firstName': 'System',
      'lastName': 'Administrator',
      'fullName': 'System Administrator',
      'email': 'admin@giraffai.in',
      'phone': null,
      'joiningDate': '2024-01-01',
      'employmentType': 'FULL_TIME',
      'workLocation': null,
      'status': 'ACTIVE',
      'department': {
        'id': '474a8d8f-3a6c-4ee4-ba72-78401295caf7',
        'name': 'Human Resources',
      },
      'designation': {
        'id': '4984cbab-f225-4662-a56b-e7613a7ce0da',
        'title': 'HR Executive',
      },
      'manager': null,
      'teams': <dynamic>[],
      'account': {
        'userId': 'efe247ea-17b4-40e6-a307-35a2edd9655a',
        'status': 'ACTIVE',
        'roles': [
          {
            'id': '9d2ce184-29dd-410b-aa19-8abe47c7c966',
            'code': 'SUPER_ADMIN',
            'name': 'Super Admin',
          }
        ],
      },
    };

    String? interceptedMethod;
    String? interceptedPath;
    Map<String, dynamic>? submittedPatchBody;

    final api = Api(
      client: MockClient((request) async {
        interceptedMethod = request.method;
        interceptedPath = request.url.path;
        if (request.method == 'PATCH' && request.url.path.contains('/employees/a3c1d986-335d-43d0-b52f-c3cc7832739b')) {
          submittedPatchBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': employeeToEditData,
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
      'id': 'admin-id',
      'name': 'Admin User',
      'is_super_admin': true,
      'role': 'SUPER_ADMIN',
    };

    dynamic popResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                final res = await Navigator.push<dynamic>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditEmployeePage(
                      api: api,
                      employee: employeeToEditData,
                    ),
                  ),
                );
                popResult = res;
              },
              child: const Text('Open Edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Edit'));
    await tester.pumpAndSettle();

    // Verify Edit Mode Titles & Breadcrumbs
    expect(find.text('Employees / Edit'), findsOneWidget);
    expect(find.text('Edit employee'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    // Verify Pre-populated text controllers
    expect(find.text('ADM001'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('admin@giraffai.in'), findsOneWidget);

    // Verify pre-selected role (Super Admin)
    expect(find.text('Super Admin · Organisation data'), findsOneWidget);

    // Tap Save changes
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // Verify Method and Path
    expect(interceptedMethod, equals('PATCH'));
    expect(interceptedPath, contains('/employees/a3c1d986-335d-43d0-b52f-c3cc7832739b'));

    // Verify exact Payload structure requested by user
    expect(submittedPatchBody, isNotNull);
    expect(submittedPatchBody!['employeeCode'], equals('ADM001'));
    expect(submittedPatchBody!['firstName'], equals('System'));
    expect(submittedPatchBody!['lastName'], equals('Administrator'));
    expect(submittedPatchBody!['email'], equals('admin@giraffai.in'));
    expect(submittedPatchBody!['phone'], isNull);
    expect(submittedPatchBody!['departmentId'], equals('474a8d8f-3a6c-4ee4-ba72-78401295caf7'));
    expect(submittedPatchBody!['designationId'], equals('4984cbab-f225-4662-a56b-e7613a7ce0da'));
    expect(submittedPatchBody!['managerId'], isNull);
    expect(submittedPatchBody!['teamIds'], equals([]));
    expect(submittedPatchBody!['joiningDate'], equals('2024-01-01'));
    expect(submittedPatchBody!['employmentType'], equals('FULL_TIME'));
    expect(submittedPatchBody!['workLocation'], isNull);
    expect(
      (submittedPatchBody!['roleIds'] as List),
      contains('9d2ce184-29dd-410b-aa19-8abe47c7c966'),
    );

    // Verify popped with data
    expect(popResult, isNotNull);
  });

  testWidgets('EmployeeDetailPage shows Edit button for Admin and triggers edit flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final empData = {
      'id': 'a3c1d986-335d-43d0-b52f-c3cc7832739b',
      'employeeCode': 'ADM001',
      'firstName': 'System',
      'lastName': 'Administrator',
      'fullName': 'System Administrator',
      'email': 'admin@giraffai.in',
      'phone': null,
      'joiningDate': '2024-01-01',
      'employmentType': 'FULL_TIME',
      'workLocation': null,
      'status': 'ACTIVE',
      'department': {
        'id': '474a8d8f-3a6c-4ee4-ba72-78401295caf7',
        'name': 'Human Resources',
      },
      'designation': {
        'id': '4984cbab-f225-4662-a56b-e7613a7ce0da',
        'title': 'HR Executive',
      },
      'manager': null,
      'teams': <dynamic>[],
      'account': {
        'userId': 'efe247ea-17b4-40e6-a307-35a2edd9655a',
        'status': 'ACTIVE',
        'roles': [
          {
            'id': '9d2ce184-29dd-410b-aa19-8abe47c7c966',
            'code': 'SUPER_ADMIN',
            'name': 'Super Admin',
          }
        ],
      },
      'leaveBalances': <dynamic>[],
      'taskSummary': {'todo': 0, 'inProgress': 0, 'completed': 0, 'overdue': 0},
    };

    final api = Api(
      client: MockClient((request) async {
        if (request.url.path.contains('/employees/a3c1d986-335d-43d0-b52f-c3cc7832739b')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': empData,
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
      'id': 'admin-id',
      'name': 'Admin User',
      'is_super_admin': true,
      'role': 'SUPER_ADMIN',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeDetailPage(
          api: api,
          employeeId: 'a3c1d986-335d-43d0-b52f-c3cc7832739b',
          initialData: empData,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify employee name and details
    expect(find.text('System Administrator'), findsWidgets);

    // Verify edit icon in AppBar and Edit text in Details card
    final editIcon = find.byTooltip('Edit employee');
    expect(editIcon, findsOneWidget);

    // Tap edit button
    await tester.tap(editIcon);
    await tester.pumpAndSettle();

    // Verify AddEmployeePage rendered in edit mode
    expect(find.byType(AddEmployeePage), findsOneWidget);
    expect(find.text('Edit employee'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });
}
