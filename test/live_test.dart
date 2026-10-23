import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/dashboards.dart';
import 'package:hr360_mobile/leave.dart';
import 'package:hr360_mobile/network/dio_client.dart';
import 'package:hr360_mobile/network/live_gateway.dart';
import 'package:hr360_mobile/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

/// Serves captured `/api/v1` responses; unknown paths get an empty page.
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

  setUpAll(tz.initializeTimeZones);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final (role, scope, marker) in [
    ('admin', 'ALL', 'Organisation pulse'),
    ('hr', 'ALL', 'People overview'),
    ('manager', 'TEAM', 'Your team today'),
  ]) {
    testWidgets('$role dashboard renders live data without overflow', (
      tester,
    ) async {
      await phone(tester);
      final api = _api(fixtures, role, scope);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleDashboard(api: api, onTab: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(marker.toUpperCase()), findsOneWidget);
      expect(find.text('My day'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Today').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      api.dispose();
    });
  }

  testWidgets('leave page shows balances and the leave calendar', (
    tester,
  ) async {
    await phone(tester);
    final api = _api(fixtures, 'employee', 'SELF');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LeavePage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leave calendar'), findsOneWidget);
    expect(find.text('Loss of Pay'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    api.dispose();
  });

  testWidgets('module switch swaps to the Tasks navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _api(fixtures, 'admin', 'ALL');
    await tester.pumpWidget(MaterialApp(home: Shell(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Approvals'), findsOneWidget);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Task dashboard'), findsOneWidget);
    for (final tab in ['My tasks', 'Issues', 'Calendar', 'Dashboard']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tester.tap(find.text('HRMS'));
    await tester.pumpAndSettle();
    expect(find.text('Approvals'), findsOneWidget);
    api.dispose();
  });

  test('gateway maps v1 leave balances and requests', () async {
    final api = _api(fixtures, 'admin', 'ALL');
    final gateway = LiveGateway(api);
    final balances = await gateway.balances();
    final first = (balances['items'] as List).first as Map;
    expect(first['available'], isA<num>());
    expect(first['allocation'], isA<num>());
    final approvals = await gateway.requests({
      'status': 'PENDING',
      'actionable': 'true',
    });
    final rows = (approvals['items'] as List).cast<Map>();
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(row['employee_name'], isNot('Employee'));
      expect(row['type_name'], isNot('Leave'));
      expect((row['events'] as List).first['at'], isNotNull);
    }
    api.dispose();
  });
}
