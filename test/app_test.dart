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
    expect(find.text('Rest. Recharge.\nBe Your Best.'), findsOneWidget);
    expect(find.text('Submit request'), findsOneWidget);
    expect(find.textContaining('Leave Type'), findsOneWidget);
    expect(find.textContaining('From - To'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
