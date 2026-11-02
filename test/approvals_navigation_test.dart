import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/dashboards.dart';
import 'package:hr360_mobile/network/dio_client.dart';
import 'package:hr360_mobile/network/live_gateway.dart';
import 'package:hr360_mobile/requests.dart';
import 'package:hr360_mobile/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

class _FixtureAdapter implements HttpClientAdapter {
  final Map<String, dynamic> fixtures;
  _FixtureAdapter(this.fixtures);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body =
        fixtures[options.path] ??
        {
          'success': true,
          'data': {'items': [], 'totalItems': 0},
        };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Api _api(Map<String, dynamic> fixtures, String role, String scope) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
    ..httpClientAdapter = _FixtureAdapter(fixtures)
    ..interceptors.add(EnvelopeInterceptor());
  final api = Api(dio: dio)..token = 'test';
  final user = Map<String, dynamic>.from(
    (fixtures['/auth/me'] as Map)['data'] as Map,
  );
  api.applyUser(session(user));
  api.role = role;
  api.scope = scope;
  return api;
}

void main() {
  final fixtures =
      jsonDecode(File('test/live_fixtures.json').readAsStringSync())
          as Map<String, dynamic>;

  setUpAll(() {
    tz.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'Tapping Leave requests and Regularisations navigates to corresponding Approvals tabs',
    (tester) async {
      await phone(tester);
      final api = _api(fixtures, 'manager', 'TEAM');

      int? navigatedTab;
      String? navigatedSubTab;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleDashboard(
              api: api,
              onTab: (tab) => navigatedTab = tab,
              onNavigate: (tab, {subTab}) {
                navigatedTab = tab;
                navigatedSubTab = subTab;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Needs your action'), findsOneWidget);
      expect(find.text('Leave requests'), findsOneWidget);
      expect(find.text('Regularisations'), findsOneWidget);

      // Tap Leave requests
      await tester.tap(find.text('Leave requests'));
      await tester.pumpAndSettle();
      expect(navigatedTab, 3);
      expect(navigatedSubTab, 'Leave');

      // Tap Regularisations
      await tester.tap(find.text('Regularisations'));
      await tester.pumpAndSettle();
      expect(navigatedTab, 3);
      expect(navigatedSubTab, 'Attendance');

      api.dispose();
    },
  );

  testWidgets(
    'Shell navigates from RoleDashboard Regularisations directly into Approvals Attendance tab',
    (tester) async {
      await phone(tester);
      final api = _api(fixtures, 'manager', 'TEAM');

      await tester.pumpWidget(
        MaterialApp(
          home: Shell(api: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Needs your action'), findsOneWidget);

      // Tap Regularisations card in "Needs your action"
      await tester.tap(find.text('Regularisations'));
      await tester.pumpAndSettle();

      // Should now be on the Approvals page with Team approvals title
      expect(find.text('Team approvals'), findsOneWidget);

      // Both Leave and Attendance tab buttons exist; Attendance should be active
      expect(find.text('Attendance'), findsWidgets);
      expect(tester.takeException(), isNull);

      api.dispose();
    },
  );

  testWidgets(
    'RequestsPage initializes with initialKind properly',
    (tester) async {
      await phone(tester);
      final api = _api(fixtures, 'manager', 'TEAM');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestsPage(
              api: api,
              mode: 'approvals',
              initialKind: 'Attendance',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Team approvals'), findsOneWidget);
      expect(tester.takeException(), isNull);

      api.dispose();
    },
  );
}

