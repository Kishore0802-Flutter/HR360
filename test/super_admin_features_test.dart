import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/directory.dart';
import 'package:hr360_mobile/roles.dart';
import 'package:hr360_mobile/leave_policies.dart';
import 'package:hr360_mobile/shell.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Super Admin Features & Quick Actions Tests', () {
    testWidgets('ProfilePage shows Quick Actions ONLY for Super Admin', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // 1. Regular Employee Api
      final regularApi = Api(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      );
      regularApi.role = 'employee';
      regularApi.profile = {
        'name': 'Arun Kumar',
        'email': 'employee@giraffai.in',
        'role': 'employee',
        'role_name': 'Employee',
        'is_super_admin': false,
        'office': {'name': 'Headquarters', 'timezone': 'Asia/Kolkata'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePage(api: regularApi),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should NOT show Super Admin Quick Actions
      expect(find.text('Quick actions'), findsNothing);
      expect(find.text('Roles & permissions'), findsNothing);
      expect(find.text('Leave types & policies'), findsNothing);

      // 2. Super Admin Api
      final superAdminApi = Api(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      );
      superAdminApi.role = 'admin';
      superAdminApi.profile = {
        'name': 'Super Administrator',
        'email': 'superadmin@giraffai.in',
        'role': 'super_admin',
        'role_name': 'Super Admin',
        'is_super_admin': true,
        'office': {'name': 'Headquarters', 'timezone': 'Asia/Kolkata'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePage(api: superAdminApi),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Super Admin should see Quick actions with Roles and Leave policies
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('Roles & permissions'), findsOneWidget);
      expect(find.text('Leave types & policies'), findsOneWidget);
      expect(find.text('Employees directory'), findsOneWidget);
    });

    testWidgets('EmployeesPage shows "+ Add employee" button ONLY for Super Admin', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // 1. Employee
      final regularApi = Api(
        client: MockClient((request) async {
          if (request.url.path.contains('/employees')) {
            return http.Response(jsonEncode({'success': true, 'data': {'items': [], 'totalItems': 0}}), 200);
          }
          return http.Response(jsonEncode({'success': true, 'data': {'items': []}}), 200);
        }),
      );
      regularApi.role = 'employee';
      regularApi.profile = {'is_super_admin': false};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeesPage(api: regularApi),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add employee'), findsNothing);

      // 2. Super Admin
      final superAdminApi = Api(
        client: MockClient((request) async {
          if (request.url.path.contains('/employees')) {
            return http.Response(jsonEncode({'success': true, 'data': {'items': [], 'totalItems': 0}}), 200);
          }
          return http.Response(jsonEncode({'success': true, 'data': {'items': []}}), 200);
        }),
      );
      superAdminApi.profile = {'is_super_admin': true};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeesPage(api: superAdminApi),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add employee'), findsOneWidget);

      // Tap Add employee opens modal
      await tester.tap(find.text('Add employee'));
      await tester.pumpAndSettle();
      expect(find.text('Add New Employee'), findsOneWidget);
    });

    testWidgets('RolesPage renders roles cards, search and details', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final rolesApi = Api(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/roles')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'role-1',
                    'code': 'ADMIN',
                    'name': 'Admin',
                    'description': 'Organisation-wide administration of HRMS',
                    'scope': 'ALL',
                    'permissions': ['p1', 'p2'],
                    'isSystem': true,
                    'isProtected': false,
                    'status': 'ACTIVE',
                    'userCount': 0,
                  },
                  {
                    'id': 'role-2',
                    'code': 'SUPER_ADMIN',
                    'name': 'Super Admin',
                    'description': 'Full access to every module',
                    'scope': 'ALL',
                    'permissions': ['p1', 'p2', 'p3'],
                    'isSystem': true,
                    'isProtected': true,
                    'status': 'ACTIVE',
                    'userCount': 1,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      );
      rolesApi.profile = {'is_super_admin': true};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RolesPage(api: rolesApi),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Roles & permissions'), findsWidgets);
      expect(find.text('New role'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Super Admin'), findsOneWidget);

      // Tap View on Super Admin
      expect(find.text('View'), findsOneWidget);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('Permissions List'), findsOneWidget);
    });

    testWidgets('LeavePoliciesPage renders cards, top action buttons and policy details', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final policiesApi = Api(
        client: MockClient((request) async {
          if (request.url.path.contains('/leave-policies')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'pol-1',
                    'code': 'CL',
                    'name': 'Casual Leave',
                    'color': '#3b82f6',
                    'isPaid': true,
                    'entitlement': 12,
                    'accrualFrequency': 'Monthly accrual',
                    'carryForwardLimit': 0,
                    'halfDayAllowed': true,
                    'departmentScope': 'all departments',
                    'status': 'ACTIVE',
                  },
                  {
                    'id': 'pol-2',
                    'code': 'EL',
                    'name': 'Earned Leave',
                    'color': '#10b981',
                    'isPaid': true,
                    'entitlement': 15,
                    'accrualFrequency': 'Yearly accrual',
                    'carryForwardLimit': 10,
                    'halfDayAllowed': true,
                    'departmentScope': 'all departments',
                    'status': 'ACTIVE',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeavePoliciesPage(api: policiesApi),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top action buttons
      expect(find.text('View ledger'), findsOneWidget);
      expect(find.text('Adjust balance'), findsOneWidget);
      expect(find.text('Run accrual now'), findsOneWidget);
      expect(find.text('New leave type'), findsOneWidget);

      // Leave cards
      expect(find.text('Casual Leave'), findsOneWidget);
      expect(find.text('Earned Leave'), findsOneWidget);
      expect(find.text('Paid'), findsWidgets);
      expect(find.text('Active'), findsWidgets);

      // Tap View ledger
      await tester.tap(find.text('View ledger'));
      await tester.pumpAndSettle();
      expect(find.text('Auditable Leave Ledger'), findsOneWidget);
    });

    testWidgets('RolesPage creates role with POST /roles and deletes custom role with DELETE /roles/:id', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Map<String, dynamic>? postedRoleBody;
      String? deletedRoleId;

      final rolesApi = Api(
        client: MockClient((request) async {
          if (request.method == 'GET' && request.url.path.contains('/roles')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'role-custom-1',
                    'code': 'TEST',
                    'name': 'Test Role',
                    'description': 'Custom test role',
                    'scope': 'SELF',
                    'permissions': ['attendance:view', 'leave:view'],
                    'isSystem': false,
                    'isProtected': false,
                    'status': 'ACTIVE',
                    'userCount': 0,
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'POST' && request.url.path.contains('/roles')) {
            postedRoleBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'role-custom-2',
                  'code': postedRoleBody!['code'],
                  'name': postedRoleBody!['name'],
                  'description': postedRoleBody!['description'],
                  'scope': postedRoleBody!['scope'],
                  'permissions': postedRoleBody!['permissions'],
                  'isSystem': false,
                  'isProtected': false,
                  'status': 'ACTIVE',
                },
              }),
              201,
            );
          }
          if (request.method == 'DELETE' && request.url.path.contains('/roles/')) {
            deletedRoleId = request.url.pathSegments.last;
            return http.Response(
              jsonEncode({'success': true, 'data': {'deleted': true}}),
              200,
            );
          }
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      );
      rolesApi.profile = {'is_super_admin': true};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RolesPage(api: rolesApi),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom role displays with Edit button and delete icon
      expect(find.text('Test Role'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // 1. Test Create Role
      await tester.tap(find.text('New role'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Role'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Test'), 'Auditor');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Role'));
      await tester.pumpAndSettle();

      expect(postedRoleBody, isNotNull);
      expect(postedRoleBody!['name'], equals('Auditor'));
      expect(postedRoleBody!['code'], equals('AUDITOR'));
      expect(postedRoleBody!['scope'], equals('SELF'));
      expect(postedRoleBody!['permissions'], isNotEmpty);

      // 2. Test Delete Role
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete Test Role?'), findsOneWidget);
      await tester.tap(find.text('Delete Role'));
      await tester.pumpAndSettle();

      expect(deletedRoleId, equals('role-custom-1'));
    });

    testWidgets('LeavePoliciesPage displays No policy badge and creates policy with POST /leave-policies and edits with PATCH', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Map<String, dynamic>? postedLeaveType;
      Map<String, dynamic>? postedPolicy;
      Map<String, dynamic>? patchedPolicy;

      final policiesApi = Api(
        client: MockClient((request) async {
          if (request.method == 'GET' && request.url.path.contains('/leave-types')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'type-1',
                    'code': 'WGVW',
                    'name': 'wjhbw',
                    'description': 'dcc',
                    'color': '#6366f1',
                    'isPaid': true,
                    'status': 'ACTIVE',
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'GET' && request.url.path.contains('/leave-policies')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [], // initially no policy for wjhbw
              }),
              200,
            );
          }
          if (request.method == 'GET' && request.url.path.contains('/departments')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': '474a8d8f-3a6c-4ee4-ba72-78401295caf7',
                    'name': 'Engineering',
                    'code': 'ENG',
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'POST' && request.url.path.contains('/leave-types')) {
            postedLeaveType = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'type-new',
                  ...postedLeaveType!,
                },
              }),
              201,
            );
          }
          if (request.method == 'POST' && request.url.path.contains('/leave-policies')) {
            postedPolicy = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'pol-new-123',
                  ...postedPolicy!,
                },
              }),
              201,
            );
          }
          if (request.method == 'PATCH' && request.url.path.contains('/leave-policies/')) {
            patchedPolicy = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'pol-new-123',
                  ...patchedPolicy!,
                },
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeavePoliciesPage(api: policiesApi),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify wjhbw is rendered without policy
      expect(find.text('wjhbw'), findsOneWidget);
      expect(find.text('No policy — not available to employees'), findsOneWidget);
      expect(find.text('Create policy'), findsOneWidget);

      // 2. Tap Create policy
      await tester.tap(find.text('Create policy'));
      await tester.pumpAndSettle();

      expect(find.text('Create wjhbw policy'), findsOneWidget);
      expect(find.text('Entitlement & accrual'), findsOneWidget);
      expect(find.text('Request rules'), findsOneWidget);

      // Tap Create policy submit button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create policy'));
      await tester.pumpAndSettle();

      expect(postedPolicy, isNotNull);
      expect(postedPolicy!['leaveTypeId'], equals('type-1'));
      expect(postedPolicy!['name'], equals('wjhbw policy'));
      expect(postedPolicy!['entitlementDays'], equals(12));
      expect(postedPolicy!['accrualFrequency'], equals('YEARLY'));
      expect(postedPolicy!['status'], equals('ACTIVE'));

      // 3. Test New leave type flow
      await tester.ensureVisible(find.text('New leave type'));
      await tester.tap(find.text('New leave type'));
      await tester.pumpAndSettle();

      expect(find.text('New Leave Type'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Parental Leave or wjhbw'), 'Maternity Leave');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Leave Type'));
      await tester.pumpAndSettle();

      expect(postedLeaveType, isNotNull);
      expect(postedLeaveType!['name'], equals('Maternity Leave'));
      expect(postedLeaveType!['isPaid'], isTrue);
    });
  });
}

