import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'network/dio_client.dart';
import 'network/live_gateway.dart';
import 'offline.dart' as device;

String officeTimezone = 'Asia/Kolkata';
typedef Json = Map<String, dynamic>;

class ApiFailure implements Exception {
  final String message;
  final int status;
  ApiFailure(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api extends ChangeNotifier {
  static const base = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://hrms-demo-api.giraffai.in/api/v1',
  );
  final FlutterSecureStorage storage;
  final http.Client client;
  final bool offline;
  final bool live;
  Dio? dio;
  String? token;
  String? refreshToken;

  /// One of `admin`, `hr`, `manager`, or `employee`.
  String? role;
  String scope = 'SELF';
  Set<String> permissions = {};
  Json? profile;
  Json? pending;

  /// Last `requirements` block from `/attendance/status`.
  Json attendanceRules = {};
  final Set<String> readNotifications = {};
  late final device.OfflineStore _offline = device.OfflineStore(
    read: (key) => storage.read(key: key),
    write: (key, value) => storage.write(key: key, value: value),
  );
  Api({
    FlutterSecureStorage? storage,
    http.Client? client,
    bool? offline,
    Dio? dio,
  }) : storage = storage ?? const FlutterSecureStorage(),
       client = client ?? http.Client(),
       offline = offline ?? false,
       live = client == null && (offline ?? false) == false {
    if (live) {
      this.dio =
          dio ??
          HrDio.create(
            baseUrl: base,
            readToken: () => token,
            readRefreshToken: () => refreshToken,
            onRefreshed: (access, refresh) async {
              token = access;
              refreshToken = refresh;
              await this.storage.write(key: 'session', value: access);
              if (refresh != null) {
                await this.storage.write(key: 'refresh', value: refresh);
              }
            },
            onUnauthorized: () {
              if (token != null) clearSession();
            },
          );
    }
  }
  bool get manager {
    if (live && permissions.contains('leave:approve')) return true;
    final value = (role ?? profile?['role'])?.toString().toLowerCase() ?? '';
    return value.isNotEmpty && value != 'employee';
  }

  /// Permission check against the server's list. Offline and test builds
  /// keep the older role-only behaviour.
  bool can(String permission) =>
      live ? permissions.contains(permission) : manager;

  bool get hasTasks =>
      live &&
      (permissions.contains('task_dashboard:view') ||
          permissions.contains('tasks:view'));

  /// Applies `user` from `/auth/login`, `/auth/refresh`, or `/auth/me`.
  void applyUser(Json session) {
    role = session['role'] as String?;
    scope = session['scope']?.toString() ?? 'SELF';
    permissions = Set<String>.from(session['permissions'] as Iterable? ?? []);
    profile = session['profile'] as Json;
    officeTimezone = profile!['office']['timezone'] as String;
  }

  /// Raw v1 call for screens built directly on the new API (dashboards,
  /// tasks). Returns the unwrapped `data`.
  Future<dynamic> v1(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) => LiveGateway(this).fetch(method, path, query: query, body: body);

  Future<void> restore() async {
    token = await storage.read(key: 'session');
    if (offline) {
      pending = null;
      await storage.delete(key: 'pending');
      if (token != null) {
        profile = await _offline.profileForToken(token!);
        if (profile == null) {
          token = null;
          await storage.delete(key: 'session');
        } else {
          officeTimezone = profile!['office']['timezone'];
        }
      }
      notifyListeners();
      return;
    }
    if (live) {
      role = await storage.read(key: 'role');
      refreshToken = await storage.read(key: 'refresh');
      if (token != null) {
        try {
          applyUser(await LiveGateway(this).me());
          notifyListeners();
        } on ApiFailure catch (e) {
          if (e.status == 401) {
            await clearSession();
          } else {
            rethrow;
          }
        }
      }
      notifyListeners();
      return;
    }
    final saved = await storage.read(key: 'pending');
    if (saved != null) pending = jsonDecode(saved) as Json;
    if (token != null) {
      try {
        profile = await get('/auth/me');
        officeTimezone = profile!['office']['timezone'];
        notifyListeners();
      } on ApiFailure catch (e) {
        if (e.status != 401) rethrow;
      }
    }
  }

  Future<void> login(String id, String password) async {
    if (live) {
      final session = await LiveGateway(this).login(id, password);
      token = session['token'] as String;
      refreshToken = session['refresh'] as String?;
      applyUser(session);
      await storage.write(key: 'session', value: token);
      await storage.write(key: 'role', value: role);
      if (refreshToken != null) {
        await storage.write(key: 'refresh', value: refreshToken);
      }
      await storage.write(key: 'last_id', value: id.trim());
      notifyListeners();
      return;
    }
    final Json r;
    if (offline) {
      try {
        r = await _offline.login(id, password);
      } on device.OfflineFailure catch (error) {
        throw ApiFailure(error.message);
      }
    } else {
      r = await call(
        'POST',
        '/auth/login',
        body: {'identifier': id, 'password': password},
      );
    }
    token = r['token'] as String;
    profile = r['profile'] as Json;
    officeTimezone = profile!['office']['timezone'];
    await storage.write(key: 'session', value: token);
    await storage.write(key: 'last_id', value: profile!['id'] as String);
    notifyListeners();
  }

  Future<Json> refreshProfile() async {
    final Json loaded;
    if (live) {
      final session = await LiveGateway(this).me();
      applyUser(session);
      loaded = session['profile'] as Json;
    } else if (offline) {
      loaded = (await _offline.profileForToken(token ?? '')) ?? {};
    } else {
      loaded = await get('/auth/me');
    }
    profile = loaded;
    final office = loaded['office'];
    if (office is Map && office['timezone'] != null) {
      officeTimezone = office['timezone'].toString();
    }
    notifyListeners();
    return loaded;
  }

  Future<void> loginSaved() async {
    final id = await storage.read(key: 'last_id');
    if (id == null || id.isEmpty) {
      throw ApiFailure(
        'Sign in with your password once before using biometrics.',
      );
    }
    if (!offline) throw ApiFailure('Sign in with your password.');
    final Json r;
    try {
      r = await _offline.resume(id);
    } on device.OfflineFailure catch (error) {
      throw ApiFailure(error.message);
    }
    token = r['token'] as String;
    profile = r['profile'] as Json;
    officeTimezone = profile!['office']['timezone'];
    await storage.write(key: 'session', value: token);
    notifyListeners();
  }

  Future<void> clearSession() async {
    token = null;
    refreshToken = null;
    role = null;
    scope = 'SELF';
    permissions = {};
    attendanceRules = {};
    profile = null;
    pending = null;
    readNotifications.clear();
    await storage.delete(key: 'session');
    await storage.delete(key: 'refresh');
    await storage.delete(key: 'role');
    await storage.delete(key: 'pending');
    notifyListeners();
  }

  Future<void> logout() async {
    if (live) {
      try {
        await LiveGateway(this).logout();
      } catch (_) {}
    } else if (!offline) {
      await call('POST', '/auth/logout', body: {});
    }
    await clearSession();
  }

  Future<Json> get(String path, {Map<String, String>? query}) =>
      call('GET', path, query: query);
  Future<Json> post(String path, Json body) => call('POST', path, body: body);
  Future<Json> patch(String path, Json body) => call('PATCH', path, body: body);

  /// Geofence check against the capture rules from `/attendance/status`.
  /// The server has no endpoint for this, so it runs on the device.
  Future<Json> checkLocation(Json gps) async {
    if (live) return LiveGateway(this).locationCheck(gps);
    return call('POST', '/location/check', body: gps);
  }

  Future<Json> mutate(String path, Json body) async {
    if (offline || live) return call('POST', path, body: body);
    if (pending != null) {
      throw ApiFailure(
        'An earlier action is unconfirmed. Resolve it from Home before continuing.',
      );
    }
    final bytes = List<int>.generate(20, (_) => Random.secure().nextInt(256));
    pending = {'path': path, 'body': body, 'key': base64UrlEncode(bytes)};
    await storage.write(key: 'pending', value: jsonEncode(pending));
    return retryPending();
  }

  Future<Json> retryPending() async {
    final p = pending;
    if (p == null) throw ApiFailure('There is no pending action.');
    try {
      final result = await call(
        'POST',
        p['path'] as String,
        body: p['body'] as Json,
        key: p['key'] as String,
      );
      pending = null;
      await storage.delete(key: 'pending');
      notifyListeners();
      return result;
    } on ApiFailure catch (e) {
      if (e.status >= 400 && e.status < 500 && e.status != 429) {
        pending = null;
        await storage.delete(key: 'pending');
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<Json> call(
    String method,
    String path, {
    Json? body,
    Map<String, String>? query,
    String? key,
  }) async {
    if (live) {
      return LiveGateway(this).dispatch(method, path, body: body, query: query);
    }
    (method, path, body, query) = _demoRoute(method, path, body, query);
    if (offline) {
      try {
        return await _offline.handle(
          method: method,
          path: path,
          body: body,
          query: query,
          userId: profile?['id'] as String?,
        );
      } on device.OfflineFailure catch (error) {
        throw ApiFailure(error.message);
      }
    }
    final url = Uri.parse('$base$path').replace(queryParameters: query);
    if (kReleaseMode && url.scheme != 'https') {
      throw ApiFailure('Release builds require an HTTPS API URL.');
    }
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (key != null) 'Idempotency-Key': key,
    };
    try {
      final response =
          await (method == 'GET'
                  ? client.get(url, headers: headers)
                  : client.post(
                      url,
                      headers: headers,
                      body: jsonEncode(body ?? {}),
                    ))
              .timeout(const Duration(seconds: 25));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiFailure('Unexpected server response.');
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && token != null) await clearSession();
        throw ApiFailure(
          decoded['error']?.toString() ?? 'Request failed.',
          response.statusCode,
        );
      }
      return decoded;
    } on TimeoutException {
      throw ApiFailure(
        'Connection timed out. The action may have reached the server. Refresh and resolve any unconfirmed action.',
      );
    } on http.ClientException {
      throw ApiFailure(
        'Unable to reach the server. Check your connection and API address.',
      );
    } on FormatException {
      throw ApiFailure(
        'The server returned an invalid response. Check the API URL.',
      );
    }
  }

  @override
  void dispose() {
    dio?.close();
    client.close();
    super.dispose();
  }
}

/// Screens call the v1 API. The on-device demo store and the widget-test
/// fixtures predate it, so v1 calls are translated for them here only.
(String, String, Json?, Map<String, String>?) _demoRoute(
  String method,
  String path,
  Json? body,
  Map<String, String>? query,
) {
  final q = query ?? const <String, String>{};
  final b = body ?? const <String, dynamic>{};
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  String title(String? raw) {
    final text = (raw ?? '').toLowerCase();
    return text.isEmpty ? 'All' : text[0].toUpperCase() + text.substring(1);
  }

  switch ((method, path)) {
    case ('GET', '/attendance/status'):
      return ('GET', '/home', null, null);
    case ('GET', '/auth/me'):
      return ('GET', '/me', null, null);
    case ('POST', '/auth/login'):
      return ('POST', '/login', b, null);
    case ('POST', '/auth/logout'):
      return ('POST', '/logout', b, null);
    case ('GET', '/leave-balances/me'):
      return ('GET', '/balances', null, q);
    case ('GET', '/attendance/me'):
      return ('GET', '/attendance', null, q);
    case ('GET', '/attendance'):
      return ('GET', '/attendance/records', null, q);
    case ('GET', '/leave-requests/calendar'):
      return ('GET', '/leave/calendar', null, q);
    case ('GET', '/leave-requests'):
    case ('GET', '/regularisations'):
      final legacy = q['mine'] == 'true'
          ? '/requests'
          : q['actionable'] == 'true'
          ? '/approvals'
          : '/history';
      return (
        'GET',
        legacy,
        null,
        {
          'kind':
              q['kind'] ??
              (path == '/regularisations' ? 'Attendance' : 'Leave'),
          'status': title(q['status']),
          if ((q['q'] ?? '').isNotEmpty) 'employee': q['q']!,
          if (q['from'] != null) 'from': q['from']!,
          if (q['to'] != null) 'to': q['to']!,
          if (q['offset'] != null) 'offset': q['offset']!,
        },
      );
    case ('POST', '/leave-requests'):
      return (
        'POST',
        '/leave',
        {
          'type_id': b['leaveTypeId'],
          'start': b['startDate'],
          'end': b['endDate'],
          'reason': b['reason'],
        },
        null,
      );
    case ('POST', '/attendance/check-in'):
    case ('POST', '/attendance/check-out'):
      return (
        'POST',
        '/attendance/punch',
        {...b, 'action': path.endsWith('in') ? 'in' : 'out'},
        null,
      );
    case ('POST', '/regularisations'):
      return ('POST', '/attendance/corrections', b, null);
    case ('POST', '/auth/forgot-password'):
      return ('POST', '/forgot', b, null);
    case ('POST', '/auth/reset-password'):
      return (
        'POST',
        '/reset',
        {'code': b['token'], 'password': b['password']},
        null,
      );
  }
  if (parts.length == 2 && parts[0] == 'leave-requests') {
    return (method, '/requests/${parts[1]}', body, query);
  }
  if (parts.length == 3 && parts[0] == 'leave-requests') {
    final action = parts[2];
    if (action == 'cancel') {
      return ('POST', '/requests/${parts[1]}/cancel', b, null);
    }
    return (
      'POST',
      '/requests/${parts[1]}/decision',
      {
        'status': action == 'reject' ? 'Rejected' : 'Approved',
        'remarks': b['comment'] ?? '',
      },
      null,
    );
  }
  if (method == 'PATCH' && parts.length == 3 && parts[0] == 'notifications') {
    return ('POST', path, b, null);
  }
  return (method, path, body, query);
}

Future<Json> captureLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw ApiFailure('Location services are off. Enable them in Settings.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw ApiFailure(
      'Location permission is blocked. Allow it in app settings.',
    );
  }
  if (permission == LocationPermission.denied) {
    throw ApiFailure('Location permission is needed to verify attendance.');
  }
  final p = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
  return {
    'latitude': p.latitude,
    'longitude': p.longitude,
    'accuracy': p.accuracy,
    'captured_at': p.timestamp.toUtc().toIso8601String(),
    'mocked': p.isMocked,
  };
}

List<Json> items(Json? data) => ((data?['items'] as List?) ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
String dateOnly(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String shortDate(String s) {
  final d = DateTime.parse(s);
  return '${d.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
}

String clockText(dynamic value) {
  if (value == null) return 'Not recorded';
  final d = tz.TZDateTime.from(
    DateTime.parse(value.toString()),
    tz.getLocation(officeTimezone),
  );
  return '${(d.hour % 12 == 0 ? 12 : d.hour % 12).toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String durationText(num seconds) {
  final n = seconds.toInt().clamp(0, 99999999);
  return '${(n ~/ 3600).toString().padLeft(2, '0')}h ${((n % 3600) ~/ 60).toString().padLeft(2, '0')}m';
}
