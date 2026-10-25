import 'dart:convert';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;
import 'package:hr360_mobile/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/offline.dart';
import 'package:hr360_mobile/design.dart';
import 'package:hr360_mobile/leave.dart';
import 'package:hr360_mobile/welcome.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('manager can navigate all five tabs and open leave tracking', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tz.initializeTimeZones();
    final fixtures =
        jsonDecode(File('test/fixtures.json').readAsStringSync())
            as Map<String, dynamic>;
    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path.replaceFirst(RegExp(r'^/api(/v1)?'), '');
        return http.Response(
          jsonEncode(fixtures[path] ?? {'items': [], 'has_more': false}),
          200,
        );
      }),
    );
    api.profile = Map<String, dynamic>.from(fixtures['/me']);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Shell(api: api),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    for (final tab in ['Attendance', 'Leave', 'Approvals', 'Profile', 'Home']) {
      await tester.tap(
        find
            .descendant(
              of: find.byType(NavigationBar),
              matching: find.text(tab),
            )
            .last,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: tab);
      if (tab == 'Approvals') {
        await tester.tap(find.byType(RequestTile).first);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  test('greeting follows the time of day', () {
    expect(dashMood(DateTime(2026, 10, 6, 8)).greeting, 'Good Morning');
    expect(dashMood(DateTime(2026, 10, 6, 8)).image, 'assets/dash_morning.png');
    expect(dashMood(DateTime(2026, 10, 6, 14)).greeting, 'Good Afternoon');
    expect(
      dashMood(DateTime(2026, 10, 6, 14)).image,
      'assets/dash_afternoon.png',
    );
    expect(dashMood(DateTime(2026, 10, 6, 19)).greeting, 'Good Evening');
    expect(dashMood(DateTime(2026, 10, 6, 2)).image, 'assets/dash_evening.png');
    expect(friendlyDay(DateTime(2026, 1, 25)), 'Sunday, January 25');
  });
  test('API reports server rejection instead of success', () async {
    final api = Api(
      client: MockClient(
        (_) async => http.Response('{"error":"Outside office radius"}', 403),
      ),
    );
    await expectLater(
      api.post('/location/check', {}),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 403)),
    );
    api.dispose();
  });
  test(
    'offline storage keeps sign-in, attendance, and leave on device',
    () async {
      tz.initializeTimeZones();
      final memory = <String, String>{};
      final store = OfflineStore(
        read: (key) async => memory[key],
        write: (key, value) async => memory[key] = value,
      );
      final session = await store.login('23322', 'secret');
      final id = session['profile']['id'] as String;
      await store.handle(
        method: 'POST',
        path: '/attendance/punch',
        userId: id,
        body: {
          'action': 'in',
          'latitude': 13.08,
          'longitude': 80.27,
          'accuracy': 10,
        },
      );
      final home = await store.handle(method: 'GET', path: '/home', userId: id);
      expect(home['active']['status'], 'Working');
      var day = DateTime.now().add(const Duration(days: 7));
      while (day.weekday > DateTime.friday) {
        day = day.add(const Duration(days: 1));
      }
      final leave = await store.handle(
        method: 'POST',
        path: '/leave',
        userId: id,
        body: {
          'type_id': 'cl',
          'start': dateOnly(day),
          'end': dateOnly(day),
          'reason': 'Family commitment',
        },
      );
      expect(leave['status'], 'Pending');
      final again = await store.login('23322', 'secret');
      expect(again['profile']['name'], 'Employee 23322');
      final kept = await store.handle(method: 'GET', path: '/home', userId: id);
      expect(kept['active']['status'], 'Working');
      expect((kept['balances'] as List).first['reserved'], 1);
      await expectLater(
        store.login('23322', 'wrong'),
        throwsA(isA<OfflineFailure>()),
      );
    },
  );
  test('duration displays full hours and clamps negative values', () {
    expect(durationText(16320), '04h 32m');
    expect(durationText(-1), '00h 00m');
  });
  testWidgets('login screen shows the sign-in layout without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = Api(client: MockClient((_) async => http.Response('{}', 200)));
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: LoginPage(api: api),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Sign in with Biometrics'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  test('Api stores up to 5 recent login emails without duplicates', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = Api(client: MockClient((_) async => http.Response('{}', 200)));
    await api.saveRecentEmail('one@hr360.dev');
    await api.saveRecentEmail('two@hr360.dev');
    await api.saveRecentEmail('three@hr360.dev');
    await api.saveRecentEmail('four@hr360.dev');
    await api.saveRecentEmail('five@hr360.dev');

    var emails = await api.getRecentEmails();
    expect(emails, [
      'five@hr360.dev',
      'four@hr360.dev',
      'three@hr360.dev',
      'two@hr360.dev',
      'one@hr360.dev',
    ]);

    // Re-saving an existing email moves it to the top without duplicating
    await api.saveRecentEmail('THREE@HR360.DEV');
    emails = await api.getRecentEmails();
    expect(emails, [
      'THREE@HR360.DEV',
      'five@hr360.dev',
      'four@hr360.dev',
      'two@hr360.dev',
      'one@hr360.dev',
    ]);
    expect(emails.length, 5);

    // Adding a 6th email drops the oldest
    await api.saveRecentEmail('six@hr360.dev');
    emails = await api.getRecentEmails();
    expect(emails, [
      'six@hr360.dev',
      'THREE@HR360.DEV',
      'five@hr360.dev',
      'four@hr360.dev',
      'two@hr360.dev',
    ]);
    expect(emails.length, 5);
    api.dispose();
  });
  testWidgets('splash provides a working continue action', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: SplashPage(onContinue: () => continued = true),
      ),
    );
    await tester.pump();
    expect(find.text('HR#360'), findsOneWidget);
    expect(find.text('Let’s begin'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2400));
    expect(continued, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('story view can be skipped and has no layout error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: StoryPage(onFinish: () => finished = true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Skip'));
    expect(finished, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('apply leave page shows the request form', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tz.initializeTimeZones();
    final fixtures =
        jsonDecode(File('test/fixtures.json').readAsStringSync())
            as Map<String, dynamic>;
    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path.replaceFirst(RegExp(r'^/api(/v1)?'), '');
        return http.Response(
          jsonEncode(fixtures[path] ?? {'items': [], 'has_more': false}),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: ApplyLeavePage(api: api),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Apply for leave'), findsOneWidget);
    expect(find.text('Submit request'), findsOneWidget);
    expect(find.textContaining('Leave type'), findsOneWidget);
    expect(find.textContaining('Start date'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets('leave details page renders request details, attachment and history', (tester) async {
    tz.initializeTimeZones();
    final api = Api(
      client: MockClient((request) async {
        final path = request.url.path.replaceFirst(RegExp(r'^/api(/v1)?'), '');
        if (path.contains('3359b00b-b969-4241-8e53-c36816fe8888')) {
          return http.Response(
            jsonEncode({
              'id': '3359b00b-b969-4241-8e53-c36816fe8888',
              'employeeId': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
              'employee': {
                'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
                'employeeCode': 'DEMO-E01',
                'fullName': 'Arun Kumar',
                'email': 'employee@giraffai.in',
                'status': 'ACTIVE',
                'designation': 'Software Engineer',
                'department': 'Engineering',
              },
              'leaveTypeId': '607085bb-0ffb-4e0d-9ac6-89939e63f73b',
              'leaveType': {
                'id': '607085bb-0ffb-4e0d-9ac6-89939e63f73b',
                'code': 'SL',
                'name': 'Sick Leave',
                'color': '#ef4444',
                'isPaid': true,
              },
              'startDate': '2026-10-29',
              'endDate': '2026-10-29',
              'startSession': 'FULL',
              'endSession': 'FULL',
              'days': 1,
              'reason': '1234333',
              'attachmentId': '4a02255b-aeb4-4200-80e9-9eedc6d88222',
              'status': 'PENDING',
              'history': [
                {
                  'at': '2026-10-25T09:30:28.246Z',
                  'action': 'SUBMITTED',
                  'byName': 'Arun Kumar',
                },
              ],
              'createdAt': '2026-10-25T09:30:28.172Z',
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: LeaveDetailsPage(
          api: api,
          id: '3359b00b-b969-4241-8e53-c36816fe8888',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Sick Leave request'), findsOneWidget);
    expect(find.text('Arun Kumar'), findsOneWidget);
    expect(find.text('DEMO-E01 · Software Engineer'), findsOneWidget);
    expect(find.text('Open document'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Withdraw'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets('profile screen renders the new design with identity, details, and tabs', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tz.initializeTimeZones();
    final api = Api(client: MockClient((_) async => http.Response('{}', 200)));
    api.profile = {
      'id': 'DEMO-E01',
      'code': 'DEMO-E01',
      'name': 'Arun Kumar',
      'email': 'employee@giraffai.in',
      'role': 'employee',
      'department': 'Engineering',
      'designation': 'Software Engineer',
      'manager_name': 'Priya Raman',
      'scope': 'SELF',
      'office': {
        'name': 'Chennai',
        'timezone': 'Asia/Kolkata',
      },
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(body: ProfilePage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Header and subtitle
    expect(find.text('My profile'), findsOneWidget);
    expect(find.text('Your account, preferences and security settings.'), findsOneWidget);

    // Tabs
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);

    // Identity Card
    expect(find.text('AK'), findsOneWidget);
    expect(find.text('Arun Kumar'), findsOneWidget);
    expect(find.text('Software Engineer'), findsOneWidget);
    expect(find.text('Employee'), findsOneWidget);

    // Details Card
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Employee code'), findsOneWidget);
    expect(find.text('DEMO-E01'), findsOneWidget);
    expect(find.text('employee@giraffai.in'), findsOneWidget);
    expect(find.text('Engineering'), findsOneWidget);
    expect(find.text('Priya Raman'), findsOneWidget);
    expect(find.text('Own records'), findsOneWidget);
    expect(find.text('Asia/Kolkata'), findsOneWidget);

    // Switch to Preferences tab
    await tester.tap(find.text('Preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Notifications & accessibility'), findsOneWidget);
    expect(find.text('Remind me before tasks are due'), findsOneWidget);
    expect(find.text('Remind me about overdue tasks'), findsOneWidget);
    expect(find.text('Also send notifications by email (when enabled by admin)'), findsOneWidget);
    expect(find.text('Reduce motion and animations'), findsOneWidget);

    // Switch to Security tab
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Changing your password signs out all other sessions.'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);
    expect(find.text('Update password'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
