import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_mobile/api.dart';
import 'package:hr360_mobile/welcome.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockStorage extends FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveRecentEmail stores up to 5, deduplicates, and orders latest first', () async {
    final storage = _MockStorage();
    final api = Api(storage: storage, offline: true);

    await api.saveRecentEmail('first@test.com');
    await api.saveRecentEmail('second@test.com');
    await api.saveRecentEmail('third@test.com');
    await api.saveRecentEmail('fourth@test.com');
    await api.saveRecentEmail('fifth@test.com');

    var list = await api.getRecentEmails();
    expect(list.length, 5);
    expect(list.first, 'fifth@test.com');

    // Adding a 6th email pushes out the oldest ('first@test.com')
    await api.saveRecentEmail('sixth@test.com');
    list = await api.getRecentEmails();
    expect(list.length, 5);
    expect(list, [
      'sixth@test.com',
      'fifth@test.com',
      'fourth@test.com',
      'third@test.com',
      'second@test.com',
    ]);

    // Adding an existing email (case-insensitive duplicate) moves it to the front without duplicating
    await api.saveRecentEmail('THIRD@test.com');
    list = await api.getRecentEmails();
    expect(list.length, 5);
    expect(list.first, 'THIRD@test.com');
    expect(list.where((e) => e.toLowerCase() == 'third@test.com').length, 1);
  });

  testWidgets('LoginPage removes biometric sign-in and displays dropdown for stored emails', (
    tester,
  ) async {
    final storage = _MockStorage();
    final api = Api(storage: storage, offline: true);

    // Save recent emails
    await api.saveRecentEmail('admin@giraffai.in');
    await api.saveRecentEmail('employee@giraffai.in');

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(api: api),
      ),
    );
    await tester.pumpAndSettle();

    // Biometrics and OR divider should be removed
    expect(find.text('Sign in with Biometrics'), findsNothing);
    expect(find.text('OR'), findsNothing);

    // Initial email is autofilled with latest recent email
    expect(find.text('employee@giraffai.in'), findsOneWidget);

    // Dropdown button exists
    final dropdownButton = find.byTooltip('Stored accounts');
    expect(dropdownButton, findsOneWidget);

    // Tap dropdown to see stored emails
    await tester.tap(dropdownButton);
    await tester.pumpAndSettle();

    expect(find.text('STORED EMAILS'), findsOneWidget);
    expect(find.text('admin@giraffai.in'), findsOneWidget);

    // Select admin email from dropdown
    await tester.tap(find.text('admin@giraffai.in'));
    await tester.pumpAndSettle();

    // Field is updated to admin@giraffai.in
    expect(find.text('admin@giraffai.in'), findsOneWidget);
  });
}
