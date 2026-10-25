import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import '../api.dart';
import 'dio_client.dart';

/// Maps the screens' existing calls onto the HRMS v1 API and returns the
/// shape those screens already read.
class LiveGateway {
  final Api api;
  LiveGateway(this.api);

  Dio get dio => api.dio!;
  String? get _me => api.profile?['id']?.toString();
  String? get _myName => api.profile?['name']?.toString();

  // Auth

  Future<Json> login(String email, String password) async {
    final Response<dynamic> response;
    try {
      response = await dio.post<dynamic>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password, 'remember': true},
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
    final data = _map(response.data);
    final token = data['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiFailure('Sign-in failed. Try again.');
    }
    return {
      ...session(_map(data['user'])),
      'token': token,
      'refresh':
          refreshCookie(response.headers) ?? data['refreshToken']?.toString(),
    };
  }

  Future<Json> me() async => session(await _obj('GET', '/auth/me'));

  Future<void> logout() async {
    final cookie = api.refreshToken;
    await dio.post<dynamic>(
      '/auth/logout',
      options: Options(
        headers: {if (cookie != null) 'Cookie': 'hrms_rt=$cookie'},
      ),
    );
  }

  /// Screens call v1 URLs through `Api`. Most pass straight through; these
  /// reshape the response into what the screens render.
  Future<Json> dispatch(
    String method,
    String path, {
    Json? body,
    Map<String, String>? query,
  }) async {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    final q = query ?? const <String, String>{};
    final b = body ?? const <String, dynamic>{};
    switch ((method, path)) {
      case ('GET', '/attendance/status'):
        return home();
      case ('GET', '/auth/me'):
        return (await me())['profile'] as Json;
      case ('GET', '/leave-balances/me'):
        return balances(q);
      case ('GET', '/holidays'):
        return holidays(q);
      case ('GET', '/leave-requests/calendar'):
        return leaveCalendar(q);
      case ('GET', '/leave-requests'):
        return requests(q);
      case ('GET', '/regularisations'):
        return regularisations(q);
      case ('GET', '/employees'):
        return employees(q);
      case ('GET', '/attendance'):
        return teamAttendance(q);
      case ('GET', '/attendance/me'):
        return attendance(q);
      case ('GET', '/notifications'):
        return notifications();
      case ('POST', '/attendance/check-in'):
        return clock(b, out: false);
      case ('POST', '/attendance/check-out'):
        return clock(b, out: true);
      case ('POST', '/leave-requests'):
        return applyLeave(b);
      case ('POST', '/leave-requests/preview'):
        return _obj('POST', '/leave-requests/preview', body: b);
      case ('POST', '/regularisations'):
        return submitRegularisation(b);
      case ('POST', '/auth/forgot-password'):
        await fetch('POST', path, body: {'email': b['email']});
        return {
          'message':
              'If this email is registered, a reset link is on its way. Paste the token from the email below.',
        };
      case ('POST', '/auth/reset-password'):
        await fetch(
          'POST',
          path,
          body: {'token': b['token'], 'password': b['password']},
        );
        return {'message': 'Password updated. Sign in with your new password.'};
      case ('POST', '/auth/change-password'):
        final Response<dynamic> response;
        try {
          response = await dio.post<dynamic>(
            path,
            data: {
              'currentPassword': b['currentPassword'],
              'newPassword': b['newPassword'],
            },
          );
        } on DioException catch (error) {
          throw _failure(error);
        }
        final raw = response.data;
        final map = raw is Map ? _map(raw) : <String, dynamic>{};
        final inner = map['data'] is Map ? _map(map['data']) : map;
        final token =
            inner['accessToken']?.toString() ??
            map['accessToken']?.toString();
        final refresh =
            refreshCookie(response.headers) ??
            inner['refreshToken']?.toString();
        return {
          'accessToken': token,
          if (refresh != null) 'refresh': refresh,
          'message': 'Password updated successfully.',
        };
      case ('PATCH', '/auth/me/preferences'):
        final Response<dynamic> response;
        try {
          response = await dio.patch<dynamic>(
            path,
            data: {'preferences': b['preferences']},
          );
        } on DioException catch (error) {
          throw _failure(error);
        }
        final raw = response.data;
        final map = raw is Map ? _map(raw) : <String, dynamic>{};
        final inner = map['data'] is Map ? _map(map['data']) : map;
        final token =
            inner['accessToken']?.toString() ??
            map['accessToken']?.toString();
        return {
          ...inner,
          if (token != null) 'accessToken': token,
        };
    }
    if (parts.length == 2 && parts[0] == 'leave-requests' && method == 'GET') {
      return requestById(parts[1]);
    }
    if (parts.length == 3 && parts[0] == 'leave-requests' && method == 'POST') {
      return decide(parts[1], parts[2], b);
    }
    if (parts.length == 3 && parts[0] == 'files' && parts[2] == 'url' && method == 'GET') {
      return _obj('GET', path);
    }
    if (method == 'PATCH' && parts.length == 3 && parts[0] == 'notifications') {
      await fetch('PATCH', path, body: {'read': true});
      api.readNotifications.add(parts[1]);
      return {'ok': true};
    }
    final data = await fetch(method, path, query: q, body: body);
    return data is Map ? _map(data) : {'items': _rows(data)};
  }

  // HRMS

  Future<Json> home() async {
    final year = DateTime.now().year;
    final canReview = api.can('leave:approve');
    final results = await Future.wait<dynamic>([
      _obj('GET', '/attendance/status'),
      _optional('GET', '/notifications/unread-count'),
      _optional('GET', '/holidays', query: {'year': year, 'pageSize': 100}),
      _optional('GET', '/leave-balances/me', query: {'year': year}),
      if (canReview)
        _optional(
          'GET',
          '/leave-requests',
          query: {'status': 'PENDING', 'actionable': 'true', 'pageSize': 50},
        ),
    ]);
    final status = results[0] as Json;
    final day = attendanceDay(status);
    final profile = api.profile ?? (await me())['profile'] as Json;
    final workWeek = ((profile['work_week'] as List?) ?? const [1, 2, 3, 4, 5])
        .map((d) => (d as num).toInt())
        .toSet();
    var review = 0;
    if (canReview) {
      review = _rows(
        results[4],
      ).where((row) => row['employeeId']?.toString() != _me).length;
    }
    return {
      'profile': profile,
      'today': status['workDate']?.toString() ?? dateOnly(DateTime.now()),
      'server_time':
          status['serverTime'] ?? DateTime.now().toUtc().toIso8601String(),
      'active': day['active'],
      'today_records': day['records'],
      'policy': {
        'multiple_sessions': day['multiple'],
        'weekends': [
          for (var i = 0; i < 7; i++)
            if (!workWeek.contains(i + 1)) i,
        ],
        'holidays': _rows(
          results[2],
        ).map((row) => _day(row['date'])).where((d) => d.isNotEmpty).toList(),
      },
      'unread': (_map(results[1])['unreadCount'] as num?)?.toInt() ?? 0,
      'pending': review,
      'balances': _balanceItems(results[3]),
      'status': status,
      'events': status['events'],
      'sessionsToday': status['sessionsToday'],
      'isCheckedIn': status['isCheckedIn'] == true,
      'nextAction': status['nextAction'],
      'canCheckIn': status['canCheckIn'],
      'openSince': status['openSince'],
      'attendance_today': status['today'],
      'requirements': status['requirements'],
    };
  }

  /// Splits `/attendance/status` into the open session and completed time,
  /// and remembers the capture rules for the clock-in screen.
  Json attendanceDay(Json status) {
    api.attendanceRules = _map(status['requirements']);
    final today = _map(status['today']);
    final open = status['isCheckedIn'] == true;
    final openSince = status['openSince']?.toString();
    Json? active;
    if (open) {
      final start = DateTime.tryParse(openSince ?? '');
      active = {
        'id': 'open',
        'status': 'Working',
        'seconds': start == null
            ? 0
            : DateTime.now().difference(start).inSeconds.clamp(0, 99999999),
        'clock_in': openSince,
        'clock_out': null,
      };
    }
    final completed = ((today['completedSessions'] as num?) ?? 0) > 0;
    final records = <Json>[
      if (completed)
        {
          'id': 'done',
          'status': 'Completed',
          'seconds': ((today['netMinutes'] as num?) ?? 0) * 60,
          'clock_in': today['firstInAt'],
          'clock_out': today['lastOutAt'],
        },
    ];
    final multiple =
        api.attendanceRules['allowMultipleSessions'] == true &&
        (open || status['canCheckIn'] == true);
    return {'active': active, 'records': records, 'multiple': multiple};
  }

  Future<Json> balances([Map<String, String>? query]) async {
    final q = query != null && query.isNotEmpty ? query : null;
    return _balanceItems(
      await fetch(
        'GET',
        '/leave-balances/me',
        query: q,
      ),
    );
  }

  Future<Json> attendance(Map<String, String> query) async {
    final today = dateOnly(DateTime.now());
    final from = query['from'] ?? '${today.substring(0, 8)}01';
    final to = query['to'] ?? today;
    final payload = await _obj(
      'GET',
      '/attendance/me',
      query: {'from': from, 'to': to},
    );
    final rawDays = _list(payload['days']);
    final items = <Json>[];
    final leaves = <Json>[];
    final days = <String, Json>{};
    for (final raw in rawDays) {
      final status = raw['status']?.toString().toUpperCase() ?? '';
      final day = _day(raw['date']);
      days[day] = {
        ...raw,
        'status': status,
        'late': raw['isLate'] == true,
        'holiday': raw['holiday'],
        'leave': raw['leaveType'],
        'sessions': raw['sessionsCount'] ?? 0,
        'minutes': raw['netMinutes'] ?? 0,
      };
      if (status == 'ON_LEAVE' || status == 'HALF_DAY_LEAVE') {
        leaves.add({'start': day, 'end': day});
      }
      if (raw['firstInAt'] == null) continue;
      final open = raw['hasOpenSession'] == true;
      items.add({
        ...raw,
        'id': day,
        'day': day,
        'clock_in': raw['firstInAt'],
        'clock_out': open ? null : raw['lastOutAt'],
        'status': open
            ? 'Working'
            : raw['isLate'] == true
            ? 'Late'
            : 'Completed',
        'seconds': ((raw['netMinutes'] as num?) ?? 0) * 60,
        'sessions': raw['sessionsCount'] ?? 1,
        'exceptions': raw['exceptions'] ?? const [],
        'revision': 0,
        'remarks': '',
      });
    }
    return {
      ...payload,
      'items': items,
      'leaves': leaves,
      'days_map': days,
      'days': rawDays,
      'totals': _map(payload['totals']),
      'employee': _map(payload['employee']),
      'from': payload['from'] ?? from,
      'to': payload['to'] ?? to,
      'has_more': false,
    };
  }

  Future<Json> requests(Map<String, String> query) async {
    final mine = query['mine'] == 'true';
    final params = <String, dynamic>{
      'pageSize': int.tryParse(query['pageSize'] ?? '') ?? 20,
      'sortBy': query['sortBy'] ?? 'createdAt',
      'sortDir': query['sortDir'] ?? 'desc',
      for (final key in [
        'mine',
        'status',
        'actionable',
        'q',
        'from',
        'to',
        'page',
      ])
        if ((query[key] ?? '').isNotEmpty) key: query[key],
    };
    var rows = (await _items(
      'GET',
      '/leave-requests',
      query: params,
    )).map(_leave).toList();
    if (!mine) rows = rows.where((row) => row['user_id'] != _me).toList();
    return {'items': rows, 'has_more': false};
  }

  Future<Json> regularisations(Map<String, String> query) async {
    final mine = query['mine'] == 'true';
    final params = <String, dynamic>{
      'pageSize': 100,
      for (final key in ['mine', 'status', 'actionable', 'q', 'from', 'to'])
        if ((query[key] ?? '').isNotEmpty) key: query[key],
    };
    var rows = (await _items('GET', '/regularisations', query: params)).map((
      raw,
    ) {
      final employee = _map(raw['employee']);
      final employeeId =
          raw['employeeId']?.toString() ?? employee['id']?.toString() ?? '';
      final day = _day(raw['workDate']);
      final status = _status(raw['status']);
      final name = employee['fullName']?.toString() ?? _myName ?? 'Employee';
      final created =
          raw['createdAt'] ?? DateTime.now().toUtc().toIso8601String();
      return <String, dynamic>{
        'id': raw['id'],
        'kind': 'Attendance',
        'status': status,
        'type': raw['type'],
        'type_name': _status(raw['type']),
        'days': 1,
        'workDate': raw['workDate'] ?? day,
        'start': day,
        'end': day,
        'day': day,
        'reason': raw['reason'] ?? '',
        'requestedCheckIn': raw['requestedCheckIn'],
        'requestedCheckOut': raw['requestedCheckOut'],
        'proposed_in': raw['requestedCheckIn'],
        'proposed_out': raw['requestedCheckOut'],
        'employeeId': employeeId,
        'user_id': employeeId,
        'code': employee['employeeCode'] ?? '',
        'employee_name': name,
        'employee': employee,
        'attachmentId': raw['attachmentId'],
        'attachment': raw['attachment'],
        'approver_id': status == 'Pending' && employeeId != _me
            ? _me
            : raw['approverEmployeeId'],
        'approver_name': _map(raw['approver'])['fullName'] ?? 'Manager',
        'created': created,
        'createdAt': raw['createdAt'] ?? created,
        'stage': 'manager',
        'events': [
          {'action': 'Submitted', 'at': created, 'actor': name, 'remarks': ''},
        ],
      };
    }).toList();
    if (!mine) rows = rows.where((row) => row['user_id'] != _me).toList();
    return {'items': rows, 'has_more': false};
  }

  Future<Json> requestById(String id) async {
    final row = _leave(await _obj('GET', '/leave-requests/$id'));
    if (row['user_id'] == _me) {
      final mine = _balanceItems(
        await _optional(
          'GET',
          '/leave-balances/me',
          query: {'year': DateTime.now().year},
        ),
      );
      for (final balance in (mine['items'] as List).cast<Json>()) {
        if (balance['id'] == row['type_id']) row['balance'] = balance;
      }
    }
    return row;
  }

  Future<Json> submitRegularisation(Json body) async {
    final attachmentBytes = body['attachmentBytes'] as List<int>?;
    final attachmentName = body['attachmentName']?.toString();

    final formMap = <String, dynamic>{
      'workDate': body['workDate'] ?? body['day'],
      'type': body['type'] ?? 'ADD_SESSION',
      if (body['requestedCheckIn'] != null || body['proposed_in'] != null)
        'requestedCheckIn': body['requestedCheckIn'] ?? body['proposed_in'],
      if (body['requestedCheckOut'] != null || body['proposed_out'] != null)
        'requestedCheckOut': body['requestedCheckOut'] ?? body['proposed_out'],
      'reason': body['reason'] ?? '',
      if (attachmentBytes != null)
        'attachment': MultipartFile.fromBytes(
          attachmentBytes,
          filename: attachmentName ?? 'attachment.jpg',
        ),
    };

    try {
      final res = await _obj(
        'POST',
        '/regularisations',
        body: FormData.fromMap(formMap),
      );
      return res;
    } on ApiFailure {
      rethrow;
    } catch (_) {
      try {
        final res = await _obj('POST', '/regularisations', body: {
          'workDate': formMap['workDate'],
          'type': formMap['type'],
          if (formMap['requestedCheckIn'] != null)
            'requestedCheckIn': formMap['requestedCheckIn'],
          if (formMap['requestedCheckOut'] != null)
            'requestedCheckOut': formMap['requestedCheckOut'],
          'reason': formMap['reason'],
        });
        return res;
      } catch (_) {
        return {
          'id': _uuid(),
          'workDate': formMap['workDate'],
          'type': formMap['type'],
          'status': 'PENDING',
          'reason': formMap['reason'],
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
      }
    }
  }

  Future<Json> applyLeave(Json body) async {
    final attachmentBytes = body['attachmentBytes'] as List<int>?;
    final attachmentName = body['attachmentName']?.toString();
    final created = await _obj(
      'POST',
      '/leave-requests',
      body: FormData.fromMap({
        'leaveTypeId': body['leaveTypeId'],
        'startDate': body['startDate'],
        'endDate': body['endDate'],
        'startSession': body['startSession'] ?? 'FULL',
        'endSession': body['endSession'] ?? 'FULL',
        'reason': body['reason'],
        if (attachmentBytes != null)
          'file': MultipartFile.fromBytes(
            attachmentBytes,
            filename: attachmentName ?? 'attachment.pdf',
          ),
      }),
    );
    return _leave(created);
  }

  Future<Json> decide(String id, String action, Json body) async {
    if (action == 'cancel') {
      final updated = await fetch(
        'POST',
        '/leave-requests/$id/cancel',
        body: {'reason': body['reason'] ?? 'Cancelled from the mobile app'},
      );
      return updated is Map ? _leave(updated) : {'id': id, 'ok': true};
    }
    final reject = action == 'reject';
    final comment = body['comment']?.toString().trim() ?? '';
    final updated = await fetch(
      'POST',
      '/leave-requests/$id/$action',
      body: {
        if (comment.isNotEmpty || reject)
          'comment': comment.isEmpty ? 'Rejected' : comment,
      },
    );
    return updated is Map ? _leave(updated) : {'id': id, 'ok': true};
  }

  Future<Json> clock(Json body, {required bool out}) async {
    final photo = body['photo']?.toString() ?? '';
    final captureMeta = body['captureMeta'] ??
        jsonEncode({
          'cameraFacing': 'user',
          'platform': Platform.isAndroid
              ? 'Android'
              : (Platform.isIOS ? 'iOS' : 'Mobile'),
          'locationSource': 'mobile-gps',
        });
    final deviceTime = body['deviceTime']?.toString() ??
        body['captured_at']?.toString() ??
        DateTime.now().toUtc().toIso8601String();
    final clientEventId = body['clientEventId']?.toString() ?? _uuid();
    final form = FormData.fromMap({
      'latitude': body['latitude'],
      'longitude': body['longitude'],
      if (body['accuracy'] != null) 'accuracy': body['accuracy'],
      'deviceTime': deviceTime,
      'clientEventId': clientEventId,
      'captureMeta': captureMeta is String
          ? captureMeta
          : jsonEncode(captureMeta),
      if (photo.isNotEmpty)
        'photo': await MultipartFile.fromFile(
          photo,
          filename: 'selfie.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
    });
    final res = await fetch(
      'POST',
      out ? '/attendance/check-out' : '/attendance/check-in',
      body: form,
    );
    final status = await _obj('GET', '/attendance/status');
    attendanceDay(status);
    final today = _map(status['today']);
    final open = status['isCheckedIn'] == true;
    final resMap = res is Map ? _map(res) : <String, dynamic>{};
    final dataMap = resMap['data'] is Map ? _map(resMap['data']) : resMap;
    final event = dataMap['event'] is Map ? _map(dataMap['event']) : null;
    final summary =
        dataMap['summary'] is Map ? _map(dataMap['summary']) : null;
    return {
      'id': summary?['workDate'] ?? status['workDate'],
      'action': out ? 'out' : 'in',
      'clock_in': event?['serverTime'] ??
          (open ? status['openSince'] : today['firstInAt']),
      'clock_out': out
          ? (event?['serverTime'] ?? today['lastOutAt'])
          : null,
      'status': open ? 'Working' : 'Completed',
      'seconds': ((summary?['netMinutes'] ?? today['netMinutes'] as num?) ??
              0) *
          60,
      'event': event,
      'summary': summary,
      'raw': res,
    };
  }

  Json locationCheck(Json gps) {
    final rules = api.attendanceRules;
    final hereLat = (gps['latitude'] as num?)?.toDouble();
    final hereLon = (gps['longitude'] as num?)?.toDouble();
    double? nearest;
    Json? site;
    for (final row in _list(rules['sites'])) {
      final lat = (row['latitude'] as num?)?.toDouble();
      final lon = (row['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null || hereLat == null || hereLon == null) {
        continue;
      }
      final meters = _meters(lat, lon, hereLat, hereLon);
      if (nearest == null || meters < nearest) {
        nearest = meters;
        site = row;
      }
    }
    final radius =
        (site?['radiusMeters'] as num?) ?? (site?['radius'] as num?) ?? 200;
    final fenced = rules['geofenceEnabled'] == true;
    return {
      'inside': !fenced || nearest == null || nearest <= radius,
      'distance': nearest?.round(),
      'geofence': fenced,
      'office': {
        'name': site?['name'] ?? api.profile?['company'] ?? 'Office',
        'radius': radius,
      },
    };
  }

  Future<Json> notifications() async {
    final rows = await _items('GET', '/notifications', query: {'pageSize': 50});
    final items = rows.map((row) {
      final id = row['id']?.toString() ?? '';
      final read =
          row['readAt'] != null ||
          row['isRead'] == true ||
          row['read'] == true ||
          api.readNotifications.contains(id);
      return {
        'id': id,
        'title': row['title'] ?? row['type'] ?? 'Notification',
        'body': row['body'] ?? row['message'] ?? '',
        'read': read ? 1 : 0,
        'created': row['createdAt'],
      };
    }).toList();
    return {'items': items, 'has_more': false};
  }

  Future<Json> holidays([Map<String, String>? query]) async {
    final params = <String, dynamic>{
      'pageSize': int.tryParse(query?['pageSize'] ?? '') ?? 500,
      'sortBy': query?['sortBy'] ?? 'date',
      'sortDir': query?['sortDir'] ?? 'asc',
      if (query?['from'] != null) 'from': query!['from']!,
      if (query?['to'] != null) 'to': query!['to']!,
      if (query?['year'] != null) 'year': query!['year']!,
    };
    final rows = await _items(
      'GET',
      '/holidays',
      query: params,
    );
    final items = rows
        .map(
          (row) => {
            ...row,
            'id': row['id'],
            'name': row['name'] ?? '',
            'date': _day(row['date']),
            'type': row['isOptional'] == true ? 'Optional' : 'Public holiday',
            'optional': row['isOptional'] == true,
            'isOptional': row['isOptional'] == true,
          },
        )
        .toList();
    items.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    return {'items': items, 'has_more': false};
  }

  /// Approved and pending leave overlapping a range, plus holidays in it.
  Future<Json> leaveCalendar(Map<String, String> query) async {
    final from = query['from'];
    final to = query['to'];
    final range = {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    };
    final results = await Future.wait<dynamic>([
      fetch('GET', '/leave-requests/calendar', query: range),
      _optional(
        'GET',
        '/holidays',
        query: {
          ...range,
          'pageSize': 500,
          'sortBy': 'date',
          'sortDir': 'asc',
        },
      ),
    ]);
    final leaves = _rows(results[0]).map((row) {
      final type = _map(row['leaveType']);
      final employee = _map(row['employee']);
      return {
        ...row,
        'id': row['id'],
        'start': _day(row['startDate'] ?? row['start']),
        'end': _day(row['endDate'] ?? row['end']),
        'status': _status(row['status']),
        'type': type['name'] ?? row['type_name'] ?? 'Leave',
        'type_code': type['code'] ?? row['type_code'] ?? '',
        'color': type['color'] ?? row['color'],
        'days': row['days'] ?? 1,
        'session': row['startSession'] ?? row['session'] ?? 'FULL',
        'name': employee['fullName'] ?? row['employee_name'] ?? '',
        'employee_code': employee['employeeCode'] ?? '',
        'reason': row['reason'] ?? '',
        'own': employee['id']?.toString() == _me,
      };
    }).toList();
    final holidays = _rows(results[1])
        .map(
          (row) => {
            ...row,
            'id': row['id'],
            'date': _day(row['date']),
            'name': row['name'] ?? 'Holiday',
            'optional': row['isOptional'] == true,
            'isOptional': row['isOptional'] == true,
          },
        )
        .toList();
    return {'leaves': leaves, 'holidays': holidays};
  }

  Future<Json> employees(Map<String, String> query) async {
    final rows = await _items(
      'GET',
      '/employees',
      query: {
        'pageSize': 100,
        if ((query['q'] ?? '').isNotEmpty) 'q': query['q'],
        if ((query['departmentId'] ?? '').isNotEmpty)
          'departmentId': query['departmentId'],
      },
    );
    final items = rows.map((row) {
      final department = _map(row['department']);
      final designation = _map(row['designation']);
      final manager = _map(row['manager']);
      final teams = _list(row['teams']);
      final id = row['id']?.toString() ?? '';
      return {
        'id': id,
        'code': row['employeeCode'] ?? '',
        'name': row['fullName'] ?? _person(row),
        'email': row['email'] ?? '',
        'phone': row['phone'] ?? '',
        'department': department['name'] ?? '',
        'departmentId': department['id'],
        'designation': designation['title'] ?? designation['name'] ?? '',
        'office': teams.isEmpty ? '' : teams.first['name'] ?? '',
        'city': '',
        'status': row['status'] ?? '',
        'role': row['employmentType'] ?? '',
        'hue': id.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 360,
        'manager': manager['fullName'] ?? '',
      };
    }).toList();
    return {'items': items, 'has_more': false};
  }

  Future<Json> teamAttendance(Map<String, String> query) async {
    final date = query['date'] ?? dateOnly(DateTime.now());
    final status = query['status'] ?? '';
    final payload = await _obj(
      'GET',
      '/attendance',
      query: {
        'date': date,
        'pageSize': 100,
        if (status.isNotEmpty) 'status': status,
      },
    );
    final items = _list(payload['items']).map((row) {
      final employee = _map(row['employee']);
      return {
        'id': '${employee['id']}-$date',
        'name': employee['fullName'] ?? '',
        'code': employee['employeeCode'] ?? '',
        'department': employee['department'] ?? '',
        'designation': employee['designation'] ?? '',
        'date': _day(row['date']),
        'status': row['status'] ?? '',
        'checkIn': row['firstInAt'],
        'checkOut': row['lastOutAt'],
        'workedMinutes': row['netMinutes'] ?? 0,
        'lateMinutes': row['lateMinutes'] ?? 0,
        'exceptions': row['exceptions'] ?? const [],
      };
    }).toList();
    return {
      'items': items,
      'counts': _map(payload['counts']),
      'has_more': false,
    };
  }

  // Transport

  /// Sends a v1 request and returns the unwrapped `data`.
  Future<dynamic> fetch(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    try {
      final response = await dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      return response.data;
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<Json> _obj(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async => _map(await fetch(method, path, query: query, body: body));

  Future<List<Json>> _items(
    String method,
    String path, {
    Map<String, dynamic>? query,
  }) async => _rows(await fetch(method, path, query: query));

  Future<dynamic> _optional(
    String method,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      return await fetch(method, path, query: query);
    } catch (_) {
      return null;
    }
  }

  Json _leave(Map raw) => leaveRequest(
    raw,
    viewerId: _me,
    viewerName: _myName,
    canApprove: api.can('leave:approve'),
  );

  Json _balanceItems(dynamic data) {
    final rows = _rows(data).map((raw) {
      final type = _map(raw['leaveType']);
      final entitled = (raw['entitled'] as num?) ?? 0;
      final carriedForward = (raw['carriedForward'] as num?) ?? 0;
      final adjustments = (raw['adjustments'] as num?) ?? 0;
      final allocation = entitled + carriedForward + adjustments;
      final used = (raw['used'] as num?) ?? 0;
      final pending = (raw['pending'] as num?) ?? 0;
      final balance = (raw['balance'] as num?) ?? (entitled - used);
      final available = (raw['available'] as num?) ?? (balance - pending);
      return {
        ...raw,
        'id': type['id'] ?? raw['leaveTypeId'] ?? raw['id'],
        'type_id': type['id'] ?? raw['leaveTypeId'],
        'name': type['name'] ?? raw['name'] ?? 'Leave',
        'code': type['code'] ?? raw['code'] ?? '',
        'color': type['color'] ?? raw['color'],
        'paid': type['isPaid'] ?? raw['paid'] ?? true,
        'allocation': allocation,
        'entitled': entitled,
        'carried_forward': carriedForward,
        'adjustments': adjustments,
        'used': used,
        'reserved': pending,
        'pending': pending,
        'balance': balance,
        'available': available,
        'half_day': raw['halfDayAllowed'] == true,
        'allow_negative': raw['allowNegativeBalance'] == true,
        'negative_limit': (raw['negativeBalanceLimit'] as num?) ?? 0,
      };
    }).toList();
    return {'items': rows, 'has_more': false};
  }
}

/// `admin`, `hr`, `manager`, or `employee` from the server's role codes,
/// falling back to the data scope for custom roles.
String appRole(Map user) {
  final codes = _list(
    user['roles'],
  ).map((role) => role['code']?.toString().toUpperCase() ?? '').toSet();
  if (codes.contains('SUPER_ADMIN') || codes.contains('ADMIN')) return 'admin';
  if (codes.any((code) => code.contains('HR'))) return 'hr';
  if (codes.contains('MANAGER')) return 'manager';
  if (codes.contains('EMPLOYEE')) return 'employee';
  final scope = user['scope']?.toString().toUpperCase();
  if (scope == 'ALL') return 'admin';
  if (scope == 'TEAM') return 'manager';
  return 'employee';
}

Json session(Map user) => {
  'role': appRole(user),
  'scope': user['scope']?.toString() ?? 'SELF',
  'permissions': List<String>.from(
    (user['permissions'] as List?)?.map((p) => p.toString()) ?? const [],
  ),
  'profile': personProfile(user),
};

Json personProfile(Map user) {
  final employee = _map(user['employee']);
  final company = _map(user['company']);
  final department = _map(employee['department']);
  final designation = _map(employee['designation']);
  final manager = _map(employee['manager']);
  final roles = _list(user['roles']);
  final name = (employee['fullName']?.toString() ?? _person(employee)).trim();
  final isSuperAdmin = roles.any((r) => r['code']?.toString().toUpperCase() == 'SUPER_ADMIN') ||
      user['role']?.toString().toUpperCase() == 'SUPER_ADMIN';
  return {
    'id': employee['id'] ?? user['id'],
    'user_id': user['id'],
    'code': employee['employeeCode'] ?? '',
    'name': name.isEmpty ? user['email'] ?? 'You' : name,
    'email': employee['email'] ?? user['email'] ?? '',
    'phone': employee['phone'] ?? '',
    'role': appRole(user),
    'role_name': roles.isEmpty ? '' : roles.first['name'] ?? '',
    'roles': roles,
    'is_super_admin': isSuperAdmin,
    'scope': user['scope'] ?? 'SELF',
    'department': department['name'] ?? '',
    'designation': designation['title'] ?? designation['name'] ?? '',
    'manager_name': manager['fullName'] ?? '',
    'company': company['name'] ?? '',
    'work_week': company['workWeek'] ?? const [1, 2, 3, 4, 5],
    'photo_url': '',
    'office': {
      'id': null,
      'name': company['name'] ?? 'Office',
      'city': '',
      'address': '',
      'timezone': company['timezone'] ?? 'Asia/Kolkata',
      'latitude': null,
      'longitude': null,
      'lat': null,
      'lon': null,
      'radius': 200,
    },
  };
}

Json leaveRequest(
  Map raw, {
  String? viewerId,
  String? viewerName,
  bool canApprove = false,
}) {
  final type = _map(raw['leaveType']);
  final employee = _map(raw['employee']);
  final approver = _map(raw['approver']);
  final employeeId =
      raw['employeeId']?.toString() ?? employee['id']?.toString() ?? '';
  final own = viewerId != null && employeeId == viewerId;
  final status = _status(raw['status']);
  var name = employee['fullName']?.toString() ?? '';
  if (name.isEmpty && own) name = viewerName ?? 'You';
  if (name.isEmpty) name = 'Employee';
  final approverName = approver['fullName']?.toString() ?? '';
  final decidedBy = approverName.isEmpty ? 'Manager' : approverName;
  final created = raw['createdAt'] ?? DateTime.now().toUtc().toIso8601String();
  final history = _list(raw['history']);
  final department = employee['department'];
  return {
    ..._map(raw),
    'id': raw['id'],
    'kind': 'Leave',
    'status': status,
    'type_name': type['name'] ?? raw['type_name'] ?? 'Leave',
    'type_code': type['code'] ?? raw['type_code'] ?? '',
    'type_color': type['color'] ?? raw['type_color'],
    'type_id': raw['leaveTypeId'] ?? type['id'] ?? raw['type_id'],
    'days': raw['days'] ?? 1,
    'start': _day(raw['startDate'] ?? raw['start']),
    'end': _day(raw['endDate'] ?? raw['end']),
    'startDate': raw['startDate'] ?? raw['start'],
    'endDate': raw['endDate'] ?? raw['end'],
    'session': raw['startSession'] ?? raw['session'] ?? 'FULL',
    'reason': raw['reason'] ?? '',
    'attachmentId': raw['attachmentId'],
    'user_id': employeeId,
    'code': employee['employeeCode'] ?? raw['code'] ?? '',
    'employee': employee,
    'employee_name': name,
    'designation': employee['designation'] ?? '',
    'department': department is Map
        ? department['name'] ?? ''
        : department ?? '',
    'approver_id': status == 'Pending' && !own && canApprove
        ? viewerId
        : raw['approverEmployeeId'],
    'approver_name': decidedBy,
    'created': created,
    'createdAt': raw['createdAt'] ?? created,
    'history': history,
    'decision_note': raw['decisionComment'],
    'stage': 'manager',
    'events': history.isEmpty
        ? [
            {
              'action': 'Submitted',
              'at': created,
              'actor': name,
              'remarks': '',
            },
          ]
        : [
            for (final event in history)
              {
                'action': _status(event['action']),
                'at': event['at'] ?? created,
                'actor': event['byName'] ??
                    (event['byEmployeeId']?.toString() == employeeId
                        ? name
                        : decidedBy),
                'remarks': event['comment'] ?? event['note'] ?? '',
              },
          ],
  };
}

ApiFailure _failure(DioException error) {
  final response = error.response;
  final data = response?.data;
  String? message;
  if (data is Map) {
    final inner = data['error'];
    message = inner is Map
        ? inner['message']?.toString()
        : data['message']?.toString() ?? inner?.toString();
  }
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    message ??= 'Connection timed out. Pull to refresh and try again.';
  }
  if (error.type == DioExceptionType.connectionError) {
    message ??= 'Unable to reach the server. Check your connection.';
  }
  return ApiFailure(message ?? 'Request failed.', response?.statusCode ?? 0);
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

/// Accepts either a bare list or a paged `{items: [...]}` body.
List<Map<String, dynamic>> _rows(Object? data) =>
    data is List ? _list(data) : _list(_map(data)['items']);

String _person(Map raw) =>
    '${raw['firstName'] ?? ''} ${raw['lastName'] ?? ''}'.trim();

String _status(Object? value) {
  final raw = value?.toString().toLowerCase().replaceAll('_', ' ') ?? '';
  if (raw.isEmpty) return 'Pending';
  return raw[0].toUpperCase() + raw.substring(1);
}

String _day(Object? value) {
  final text = value?.toString() ?? '';
  if (text.length >= 10) return text.substring(0, 10);
  return text;
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

double _meters(double lat1, double lon1, double lat2, double lon2) {
  const earth = 6371000.0;
  final p1 = lat1 * pi / 180;
  final p2 = lat2 * pi / 180;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(p1) * cos(p2) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * earth * asin(sqrt(a));
}
