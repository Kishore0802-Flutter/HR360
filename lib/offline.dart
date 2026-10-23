import 'dart:convert';
import 'dart:math';
import 'package:timezone/timezone.dart' as tz;

typedef Json = Map<String, dynamic>;

class OfflineFailure implements Exception {
  final String message;
  OfflineFailure(this.message);
  @override
  String toString() => message;
}

/// Device copy of the HR records the app used to load from the server.
class OfflineStore {
  static const storageKey = 'offline';
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;

  OfflineStore({required this.read, required this.write});

  Future<Json> login(String identifier, String password) async {
    final id = identifier.trim();
    if (id.isEmpty || password.isEmpty) {
      throw OfflineFailure('Enter your employee ID and password.');
    }
    final db = await load();
    final users = _users(db);
    final existing = _findUser(users, id);
    if (existing == null) {
      final profile = _profile(id);
      final token = _id(24);
      users[profile['id'] as String] = {
        'password': password,
        'token': token,
        'reset': null,
        'profile': profile,
      };
      db['users'] = users;
      await save(db);
      return {'token': token, 'profile': profile};
    }
    if (existing.value['password'] != password) {
      throw OfflineFailure(
        'That password does not match the one saved on this device.',
      );
    }
    final token = existing.value['token'] as String? ?? _id(24);
    existing.value['token'] = token;
    users[existing.key] = existing.value;
    db['users'] = users;
    await save(db);
    return {
      'token': token,
      'profile': Map<String, dynamic>.from(existing.value['profile'] as Map),
    };
  }

  Future<Json> resume(String identifier) async {
    final db = await load();
    final users = _users(db);
    final existing = _findUser(users, identifier.trim());
    if (existing == null) {
      throw OfflineFailure(
        'Sign in with your password once before using biometrics.',
      );
    }
    final token = existing.value['token'] as String? ?? _id(24);
    existing.value['token'] = token;
    users[existing.key] = existing.value;
    db['users'] = users;
    await save(db);
    return {
      'token': token,
      'profile': Map<String, dynamic>.from(existing.value['profile'] as Map),
    };
  }

  Future<Json?> profileForToken(String token) async {
    final users = _users(await load());
    for (final user in users.values) {
      final row = _map(user);
      if (row['token'] == token) return _map(row['profile']);
    }
    return null;
  }

  Future<Json> handle({
    required String method,
    required String path,
    Json? body,
    Map<String, String>? query,
    String? userId,
  }) async {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    final db = await load();
    if (parts.isEmpty) throw OfflineFailure('That action is not available.');
    if (parts[0] == 'forgot' && method == 'POST') {
      return _forgot(db, body?['email']?.toString() ?? '');
    }
    if (parts[0] == 'reset' && method == 'POST') {
      return _reset(
        db,
        body?['code']?.toString() ?? '',
        body?['password']?.toString() ?? '',
      );
    }
    if (userId == null) throw OfflineFailure('Sign in to continue.');
    final user = _users(db)[userId];
    if (user == null) throw OfflineFailure('Sign in to continue.');
    final profile = _map(_map(user)['profile']);
    final result = switch ((method, parts)) {
      ('GET', ['me']) => profile,
      ('GET', ['home']) => _home(db, profile),
      ('GET', ['balances']) => {'items': _balances(db, userId, query?['year'])},
      ('GET', ['attendance']) => _attendance(db, userId, query),
      ('GET', ['requests']) => _requestPage(db, userId, 'requests', query),
      ('GET', ['approvals']) => _requestPage(db, userId, 'approvals', query),
      ('GET', ['history']) => _requestPage(db, userId, 'history', query),
      ('GET', ['notifications']) => _notifications(db, userId, query),
      ('GET', ['requests', final id]) => _requestDetail(db, id),
      ('POST', ['location', 'check']) => _location(profile, body ?? {}),
      ('POST', ['attendance', 'punch']) => await _punch(
        db,
        profile,
        body ?? {},
      ),
      ('POST', ['leave']) => await _leave(db, profile, body ?? {}),
      ('POST', ['attendance', 'corrections']) => await _correction(
        db,
        profile,
        body ?? {},
      ),
      ('POST', ['requests', final id, 'decision']) => await _decide(
        db,
        profile,
        id,
        body ?? {},
      ),
      ('POST', ['requests', final id, 'cancel']) => await _cancel(
        db,
        profile,
        id,
      ),
      ('POST', ['notifications', final id, 'read']) => await _read(
        db,
        userId,
        id,
      ),
      ('POST', ['logout']) => {'ok': true},
      _ => throw OfflineFailure('That action is not available on this device.'),
    };
    return result;
  }

  Future<Json> load() async {
    final raw = await read(storageKey);
    if (raw == null || raw.isEmpty) return _empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final db = _map(decoded);
        db.putIfAbsent('users', () => <String, dynamic>{});
        db.putIfAbsent('attendance', () => <dynamic>[]);
        db.putIfAbsent('requests', () => <dynamic>[]);
        db.putIfAbsent('notifications', () => <dynamic>[]);
        db.putIfAbsent('seq', () => 1);
        return db;
      }
    } catch (_) {}
    return _empty();
  }

  Future<void> save(Json db) => write(storageKey, jsonEncode(db));

  Json _empty() => {
    'users': <String, dynamic>{},
    'attendance': <dynamic>[],
    'requests': <dynamic>[],
    'notifications': <dynamic>[],
    'seq': 1,
  };

  Json _profile(String id) {
    final email = id.contains('@') ? id : '$id@hr360.local';
    final name = id.contains('@')
        ? id.split('@').first
        : RegExp(r'^\d+$').hasMatch(id)
        ? 'Employee $id'
        : id;
    return {
      'id': id.contains('@') ? id.split('@').first : id,
      'email': email,
      'name': name,
      'role': 'manager',
      'manager_id': id.contains('@') ? id.split('@').first : id,
      'department': 'People',
      'designation': 'Team member',
      'joined': '2024-01-01',
      'phone': '',
      'photo_url': '',
      'office': {
        'id': 'local',
        'name': 'Chennai',
        'lat': 13.08,
        'lon': 80.27,
        'radius': 150.0,
        'timezone': 'Asia/Kolkata',
      },
      'manager_name': 'Saved on this device',
    };
  }

  Future<Json> _forgot(Json db, String email) async {
    final users = _users(db);
    final found = _findUser(users, email.trim());
    if (found == null) {
      return {
        'message':
            'If that employee ID or email is saved on this device, a reset code is ready.',
      };
    }
    final code = (100000 + Random.secure().nextInt(900000)).toString();
    found.value['reset'] = code;
    users[found.key] = found.value;
    db['users'] = users;
    await save(db);
    return {
      'message':
          'Reset code $code is saved on this device. Enter it to choose a new password.',
    };
  }

  Future<Json> _reset(Json db, String code, String password) async {
    if (password.length < 12) {
      throw OfflineFailure('Use at least 12 characters.');
    }
    final users = _users(db);
    MapEntry<String, Json>? match;
    for (final entry in users.entries) {
      if (_map(entry.value)['reset'] == code.trim()) {
        match = MapEntry(entry.key, _map(entry.value));
        break;
      }
    }
    if (match == null) throw OfflineFailure('That reset code is not valid.');
    match.value['password'] = password;
    match.value['reset'] = null;
    users[match.key] = match.value;
    db['users'] = users;
    await save(db);
    return {'message': 'Password saved on this device. Sign in with it.'};
  }

  Json _home(Json db, Json profile) {
    final userId = profile['id'] as String;
    final today = _today();
    final records = _attendanceRows(db, userId);
    final open = records.cast<Json?>().firstWhere(
      (row) => row!['clock_out'] == null,
      orElse: () => null,
    );
    final todayRecords = records.where((row) => row['day'] == today).toList();
    final recent = records.take(7).map(_withSeconds).toList();
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'profile': profile,
      'today': today,
      'server_time': now,
      'active': open == null ? null : _withSeconds(open),
      'today_records': todayRecords.map(_withSeconds).toList(),
      'balances': _balances(db, userId, null),
      'recent': recent,
      'unread': _notes(db, userId).where((note) => note['read'] == 0).length,
      'pending': _rows(db)
          .where(
            (row) => row['status'] == 'Pending' && row['approver_id'] == userId,
          )
          .length,
      'policy': _policy(),
    };
  }

  Json _attendance(Json db, String userId, Map<String, String>? query) {
    final from = query?['from'] ?? '0000-01-01';
    final to = query?['to'] ?? '9999-12-31';
    final rows = _attendanceRows(db, userId)
        .where(
          (row) =>
              row['day'].toString().compareTo(from) >= 0 &&
              row['day'].toString().compareTo(to) <= 0,
        )
        .map(_withSeconds)
        .toList();
    final leaves = _rows(db)
        .where(
          (row) =>
              row['user_id'] == userId &&
              row['kind'] == 'Leave' &&
              row['status'] == 'Approved' &&
              row['end'].toString().compareTo(from) >= 0 &&
              row['start'].toString().compareTo(to) <= 0,
        )
        .toList();
    return {'items': rows, 'leaves': leaves};
  }

  Json _requestPage(
    Json db,
    String userId,
    String mode,
    Map<String, String>? query,
  ) {
    final kind = query?['kind'];
    final status = query?['status'] ?? 'All';
    final employee = query?['employee']?.toLowerCase();
    final from = query?['from'];
    final to = query?['to'];
    final filtered = _rows(db).where((row) {
      if (mode == 'approvals') {
        if (row['approver_id'] != userId || row['status'] != 'Pending') {
          return false;
        }
      } else if (mode == 'history') {
        if (row['approver_id'] != userId || row['status'] == 'Pending') {
          return false;
        }
        if (status != 'All' && row['status'] != status) return false;
      } else {
        if (row['user_id'] != userId) return false;
        if (status != 'All' && row['status'] != status) return false;
      }
      if (kind != null && kind.isNotEmpty && row['kind'] != kind) return false;
      if (employee != null && employee.isNotEmpty) {
        final name = row['employee_name'].toString().toLowerCase();
        final id = row['user_id'].toString().toLowerCase();
        if (!name.contains(employee) && !id.contains(employee)) return false;
      }
      final updated = row['updated'].toString().substring(0, 10);
      if (from != null && updated.compareTo(from) < 0) return false;
      if (to != null && updated.compareTo(to) > 0) return false;
      return true;
    }).toList();
    final offset = int.tryParse(query?['offset'] ?? '0') ?? 0;
    const limit = 20;
    final page = filtered.skip(offset).take(limit).toList();
    return {'items': page, 'has_more': offset + page.length < filtered.length};
  }

  Json _notifications(Json db, String userId, Map<String, String>? query) {
    final notes = _notes(db, userId);
    final offset = int.tryParse(query?['offset'] ?? '0') ?? 0;
    const limit = 20;
    final page = notes.skip(offset).take(limit).toList();
    return {'items': page, 'has_more': offset + page.length < notes.length};
  }

  Json _requestDetail(Json db, String id) {
    final row = _rows(
      db,
    ).cast<Json?>().firstWhere((item) => item!['id'] == id, orElse: () => null);
    if (row == null) {
      throw OfflineFailure('That request is not on this device.');
    }
    final year = DateTime.parse(row['start'].toString()).year;
    return {
      ...row,
      'balance': row['kind'] == 'Leave'
          ? _balances(
              db,
              row['user_id'] as String,
              '$year',
            ).cast<Json?>().firstWhere(
              (item) => item!['id'] == row['type_id'],
              orElse: () => null,
            )
          : null,
    };
  }

  Json _location(Json profile, Json body) {
    final office = _map(profile['office']);
    final distance = _meters(
      (body['latitude'] as num?)?.toDouble() ?? office['lat'] as double,
      (body['longitude'] as num?)?.toDouble() ?? office['lon'] as double,
      (office['lat'] as num).toDouble(),
      (office['lon'] as num).toDouble(),
    ).round();
    final radius = (office['radius'] as num).round();
    return {
      'inside': distance <= radius,
      'distance': distance,
      'accuracy': body['accuracy'] ?? 0,
      'office': office,
    };
  }

  Future<Json> _punch(Json db, Json profile, Json body) async {
    final userId = profile['id'] as String;
    final action = body['action']?.toString();
    final records = _attendanceRows(db, userId);
    final open = records.cast<Json?>().firstWhere(
      (row) => row!['clock_out'] == null,
      orElse: () => null,
    );
    final now = DateTime.now().toUtc();
    if (action == 'in') {
      if (open != null) {
        throw OfflineFailure(
          'Clock out of the open session before clocking in again.',
        );
      }
      final today = _today();
      final finishedToday = records.any(
        (row) => row['day'] == today && row['clock_out'] != null,
      );
      if (finishedToday && _policy()['multiple_sessions'] != true) {
        throw OfflineFailure('Today’s attendance is already complete.');
      }
      final record = {
        'id': _id(12),
        'user_id': userId,
        'day': today,
        'office_id': profile['office']['id'],
        'clock_in': now.toIso8601String(),
        'clock_out': null,
        'in_lat': body['latitude'],
        'in_lon': body['longitude'],
        'out_lat': null,
        'out_lon': null,
        'in_accuracy': body['accuracy'],
        'out_accuracy': null,
        if (body['photo'] != null) 'in_photo': body['photo'],
        'revision': 0,
        'seconds': 0,
        'status': 'Working',
      };
      final all = _list(db['attendance'])..insert(0, record);
      db['attendance'] = all;
      await save(db);
      return record;
    }
    if (action == 'out') {
      if (open == null) {
        throw OfflineFailure('There is no open clock-in to close.');
      }
      final start = DateTime.parse(open['clock_in'].toString());
      open['clock_out'] = now.toIso8601String();
      open['out_lat'] = body['latitude'];
      open['out_lon'] = body['longitude'];
      open['out_accuracy'] = body['accuracy'];
      open['seconds'] = now
          .difference(start.toUtc())
          .inSeconds
          .clamp(0, 99999999);
      open['status'] = 'Completed';
      _replaceAttendance(db, open);
      await save(db);
      return _withSeconds(open);
    }
    throw OfflineFailure('Choose clock in or clock out.');
  }

  Future<Json> _leave(Json db, Json profile, Json body) async {
    final typeId = body['type_id']?.toString();
    final start = body['start']?.toString() ?? '';
    final end = body['end']?.toString() ?? '';
    final reason = body['reason']?.toString().trim() ?? '';
    if (typeId == null || reason.isEmpty) {
      throw OfflineFailure('Select a leave type and add a reason.');
    }
    final days = _workingDays(start, end);
    if (days <= 0) throw OfflineFailure('Select at least one working day.');
    final policy = _policy();
    if (days > (policy['max_leave_days'] as num)) {
      throw OfflineFailure('That request is longer than the allowed maximum.');
    }
    if (policy['allow_backdated_leave'] != true &&
        start.compareTo(_today()) < 0) {
      throw OfflineFailure('Backdated leave is not allowed.');
    }
    final userId = profile['id'] as String;
    final balance = _balances(db, userId, start.substring(0, 4))
        .cast<Json?>()
        .firstWhere((item) => item!['id'] == typeId, orElse: () => null);
    if (balance == null) {
      throw OfflineFailure('That leave type is not available.');
    }
    if (days > (balance['available'] as num)) {
      throw OfflineFailure(
        'That request is longer than the available balance.',
      );
    }
    final overlap = _rows(db).any(
      (row) =>
          row['user_id'] == userId &&
          row['kind'] == 'Leave' &&
          (row['status'] == 'Pending' || row['status'] == 'Approved') &&
          row['end'].toString().compareTo(start) >= 0 &&
          row['start'].toString().compareTo(end) <= 0,
    );
    if (overlap) {
      throw OfflineFailure('Those dates already have a leave request.');
    }
    final typeName = balance['name'];
    final request = _newRequest(
      db,
      profile,
      kind: 'Leave',
      typeId: typeId,
      typeName: typeName.toString(),
      start: start,
      end: end,
      days: days,
      reason: reason,
    );
    await _insertRequest(
      db,
      profile,
      request,
      'Leave request saved on this device.',
    );
    return _requestDetail(db, request['id'] as String);
  }

  Future<Json> _correction(Json db, Json profile, Json body) async {
    final attendanceId = body['attendance_id']?.toString();
    final day = body['day']?.toString();
    final userId = profile['id'];
    Json? record;
    if (attendanceId != null && attendanceId.isNotEmpty) {
      record = _list(db['attendance']).cast<Json?>().firstWhere(
        (row) => row!['id'] == attendanceId,
        orElse: () => null,
      );
      if (record == null || record['user_id'] != userId) {
        throw OfflineFailure('That attendance record is not on this device.');
      }
    } else if (day != null && day.isNotEmpty) {
      record = _list(db['attendance']).cast<Json?>().firstWhere(
        (row) => row!['user_id'] == userId && row['day'] == day,
        orElse: () => null,
      );
    } else {
      throw OfflineFailure('Choose the day to regularize.');
    }
    final proposedIn = body['proposed_in']?.toString();
    final proposedOut = body['proposed_out']?.toString();
    final reason = body['reason']?.toString().trim() ?? '';
    if (proposedIn == null || proposedOut == null || reason.isEmpty) {
      throw OfflineFailure('Add the corrected times and a reason.');
    }
    if (!DateTime.parse(proposedOut).isAfter(DateTime.parse(proposedIn))) {
      throw OfflineFailure('Clock-out must be after clock-in.');
    }
    final fromHome = body['regularize_as']?.toString() == 'Work from home';
    final request = _newRequest(
      db,
      profile,
      kind: 'Attendance',
      typeId: 'correction',
      typeName: fromHome ? 'Work from home' : 'Time correction',
      start: record?['day']?.toString() ?? day!,
      end: record?['day']?.toString() ?? day!,
      days: 0,
      reason: reason,
      extra: {
        'attendance_id': record?['id'],
        'proposed_in': proposedIn,
        'proposed_out': proposedOut,
        'original_in': record?['clock_in'],
        'original_out': record?['clock_out'],
        'base_revision': record?['revision'],
      },
    );
    request['office_id'] = _map(profile['office'])['id'];
    await _insertRequest(
      db,
      profile,
      request,
      'Attendance correction saved on this device.',
    );
    return _requestDetail(db, request['id'] as String);
  }

  Future<Json> _decide(Json db, Json profile, String id, Json body) async {
    final request = _ownedRequest(db, id);
    if (request['approver_id'] != profile['id']) {
      throw OfflineFailure('This request is not assigned to you.');
    }
    if (request['status'] != 'Pending') {
      throw OfflineFailure('This request is already ${request['status']}.');
    }
    final status = body['status']?.toString();
    final remarks = body['remarks']?.toString().trim() ?? '';
    if (status != 'Approved' && status != 'Rejected') {
      throw OfflineFailure('Choose approve or reject.');
    }
    final decision = status!;
    if (decision == 'Rejected' && remarks.isEmpty) {
      throw OfflineFailure('Please add rejection remarks.');
    }
    request['status'] = decision;
    request['remarks'] = remarks;
    request['updated'] = DateTime.now().toUtc().toIso8601String();
    _addEvent(db, request, profile, decision, remarks);
    if (decision == 'Approved' && request['kind'] == 'Attendance') {
      _applyCorrection(db, request);
    }
    _replaceRequest(db, request);
    _notify(
      db,
      request['user_id'] as String,
      'Request $decision',
      '${request['type_name']} was ${decision.toLowerCase()} on this device.',
      request['id'] as String,
    );
    await save(db);
    return _requestDetail(db, id);
  }

  Future<Json> _cancel(Json db, Json profile, String id) async {
    final request = _ownedRequest(db, id);
    if (request['user_id'] != profile['id'] || request['kind'] != 'Leave') {
      throw OfflineFailure('Only your own pending leave can be cancelled.');
    }
    if (request['status'] != 'Pending') {
      throw OfflineFailure('Only a pending request can be cancelled.');
    }
    request['status'] = 'Cancelled';
    request['updated'] = DateTime.now().toUtc().toIso8601String();
    _addEvent(db, request, profile, 'Cancelled', '');
    _replaceRequest(db, request);
    await save(db);
    return _requestDetail(db, id);
  }

  Future<Json> _read(Json db, String userId, String id) async {
    final notes = _list(db['notifications']);
    final index = notes.indexWhere(
      (item) => _map(item)['id'] == id && _map(item)['user_id'] == userId,
    );
    if (index >= 0) {
      final note = _map(notes[index]);
      note['read'] = 1;
      notes[index] = note;
      db['notifications'] = notes;
      await save(db);
    }
    return {'ok': true};
  }

  Json _newRequest(
    Json db,
    Json profile, {
    required String kind,
    required String typeId,
    required String typeName,
    required String start,
    required String end,
    required num days,
    required String reason,
    Json extra = const {},
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _id(12);
    return {
      'id': id,
      'user_id': profile['id'],
      'kind': kind,
      'type_id': typeId,
      'start': start,
      'end': end,
      'days': days,
      'reason': reason,
      'status': 'Pending',
      'stage': 'Manager',
      'approver_id': profile['id'],
      'created': now,
      'updated': now,
      'attendance_id': extra['attendance_id'],
      'proposed_in': extra['proposed_in'],
      'proposed_out': extra['proposed_out'],
      'original_in': extra['original_in'],
      'original_out': extra['original_out'],
      'base_revision': extra['base_revision'],
      'remarks': '',
      'employee_name': profile['name'],
      'type_name': typeName,
      'approver_name': profile['name'],
      'events': [
        {
          'id': _nextSeq(db),
          'request_id': id,
          'actor_id': profile['id'],
          'action': 'Submitted',
          'at': now,
          'remarks': '',
          'actor': profile['name'],
        },
      ],
    };
  }

  Future<void> _insertRequest(
    Json db,
    Json profile,
    Json request,
    String body,
  ) async {
    final requests = _list(db['requests'])..insert(0, request);
    db['requests'] = requests;
    _notify(
      db,
      profile['id'] as String,
      request['kind'] == 'Leave'
          ? 'Leave request saved'
          : 'Attendance request saved',
      body,
      request['id'] as String,
    );
    await save(db);
  }

  void _applyCorrection(Json db, Json request) {
    final records = _list(db['attendance']);
    final attendanceId = request['attendance_id']?.toString();
    final index = attendanceId == null || attendanceId.isEmpty
        ? -1
        : records.indexWhere((item) => _map(item)['id'] == attendanceId);
    final start = DateTime.parse(request['proposed_in'].toString());
    final end = DateTime.parse(request['proposed_out'].toString());
    final seconds = end
        .toUtc()
        .difference(start.toUtc())
        .inSeconds
        .clamp(0, 99999999);
    if (index < 0) {
      records.insert(0, {
        'id': _id(12),
        'user_id': request['user_id'],
        'day': request['start'],
        'office_id': request['office_id'],
        'clock_in': start.toUtc().toIso8601String(),
        'clock_out': end.toUtc().toIso8601String(),
        'in_lat': null,
        'in_lon': null,
        'out_lat': null,
        'out_lon': null,
        'in_accuracy': null,
        'out_accuracy': null,
        'revision': 1,
        'seconds': seconds,
        'status': 'Completed',
      });
      db['attendance'] = records;
      return;
    }
    final record = _map(records[index]);
    record['clock_in'] = start.toUtc().toIso8601String();
    record['clock_out'] = end.toUtc().toIso8601String();
    record['seconds'] = seconds;
    record['status'] = 'Completed';
    record['revision'] = ((record['revision'] as num?) ?? 0) + 1;
    records[index] = record;
    db['attendance'] = records;
  }

  void _addEvent(
    Json db,
    Json request,
    Json profile,
    String action,
    String remarks,
  ) {
    final events = _list(request['events']);
    events.add({
      'id': _nextSeq(db),
      'request_id': request['id'],
      'actor_id': profile['id'],
      'action': action,
      'at': DateTime.now().toUtc().toIso8601String(),
      'remarks': remarks,
      'actor': profile['name'],
    });
    request['events'] = events;
  }

  void _notify(
    Json db,
    String userId,
    String title,
    String body,
    String requestId,
  ) {
    final notes = _list(db['notifications'])
      ..insert(0, {
        'id': _id(12),
        'user_id': userId,
        'title': title,
        'body': body,
        'created': DateTime.now().toUtc().toIso8601String(),
        'request_id': requestId,
        'read': 0,
      });
    db['notifications'] = notes;
  }

  List<Json> _balances(Json db, String userId, String? year) {
    final y = int.tryParse(year ?? '') ?? DateTime.now().year;
    const types = [
      {'id': 'cl', 'name': 'Casual Leave', 'allocation': 12},
      {'id': 'sl', 'name': 'Sick Leave', 'allocation': 8},
      {'id': 'el', 'name': 'Earned Leave', 'allocation': 15},
    ];
    return types.map((type) {
      final related = _rows(db).where(
        (row) =>
            row['user_id'] == userId &&
            row['kind'] == 'Leave' &&
            row['type_id'] == type['id'] &&
            DateTime.parse(row['start'].toString()).year == y,
      );
      final used = related
          .where((row) => row['status'] == 'Approved')
          .fold<num>(0, (sum, row) => sum + (row['days'] as num));
      final reserved = related
          .where((row) => row['status'] == 'Pending')
          .fold<num>(0, (sum, row) => sum + (row['days'] as num));
      final allocation = type['allocation'] as int;
      return {
        'id': type['id'],
        'name': type['name'],
        'allocation': allocation,
        'used': used,
        'reserved': reserved,
        'available': max(0, allocation - used - reserved),
        'year': y,
      };
    }).toList();
  }

  int _workingDays(String startText, String endText) {
    final start = DateTime.parse(startText);
    final end = DateTime.parse(endText);
    if (end.isBefore(start)) return 0;
    final holidays = (_policy()['holidays'] as List)
        .map((day) => day.toString())
        .toSet();
    final weekends = (_policy()['weekends'] as List)
        .cast<num>()
        .map((day) => day.toInt())
        .toSet();
    var total = 0;
    for (
      var day = start;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      final key = _date(day);
      if (!weekends.contains(day.weekday - 1) && !holidays.contains(key)) {
        total++;
      }
    }
    return total;
  }

  Json _policy() => {
    'weekends': [5, 6],
    'holidays': <String>[],
    'allow_backdated_leave': false,
    'max_leave_days': 90,
    'leave_requires_hr': false,
    'hr_approver_id': null,
    'max_gps_accuracy': 100,
    'multiple_sessions': false,
    'max_session_hours': 24,
    'session_hours': 12,
    'correction_window_days': 31,
  };

  List<Json> _attendanceRows(Json db, String userId) =>
      _list(
        db['attendance'],
      ).map(_map).where((row) => row['user_id'] == userId).toList()..sort(
        (a, b) => b['clock_in'].toString().compareTo(a['clock_in'].toString()),
      );

  Json _withSeconds(Json row) {
    final copy = Map<String, dynamic>.from(row);
    if (copy['clock_out'] == null && copy['clock_in'] != null) {
      final start = DateTime.parse(copy['clock_in'].toString());
      copy['seconds'] = DateTime.now()
          .toUtc()
          .difference(start.toUtc())
          .inSeconds
          .clamp(0, 99999999);
    }
    return copy;
  }

  void _replaceAttendance(Json db, Json record) {
    final records = _list(db['attendance']);
    final index = records.indexWhere(
      (item) => _map(item)['id'] == record['id'],
    );
    if (index >= 0) records[index] = record;
    db['attendance'] = records;
  }

  List<Json> _rows(Json db) => _list(db['requests']).map(_map).toList()
    ..sort(
      (a, b) => b['updated'].toString().compareTo(a['updated'].toString()),
    );

  Json _ownedRequest(Json db, String id) {
    final row = _rows(
      db,
    ).cast<Json?>().firstWhere((item) => item!['id'] == id, orElse: () => null);
    if (row == null) {
      throw OfflineFailure('That request is not on this device.');
    }
    return row;
  }

  void _replaceRequest(Json db, Json request) {
    final requests = _list(db['requests']);
    final index = requests.indexWhere(
      (item) => _map(item)['id'] == request['id'],
    );
    if (index >= 0) requests[index] = request;
    db['requests'] = requests;
  }

  List<Json> _notes(Json db, String userId) => _list(
    db['notifications'],
  ).map(_map).where((note) => note['user_id'] == userId).toList();

  int _nextSeq(Json db) {
    final next = (db['seq'] as num?)?.toInt() ?? 1;
    db['seq'] = next + 1;
    return next;
  }

  Map<String, dynamic> _users(Json db) =>
      Map<String, dynamic>.from(db['users'] as Map);

  MapEntry<String, Json>? _findUser(
    Map<String, dynamic> users,
    String identifier,
  ) {
    final key = identifier.trim().toLowerCase();
    for (final entry in users.entries) {
      final row = _map(entry.value);
      final profile = _map(row['profile']);
      final id = profile['id'].toString().toLowerCase();
      final email = profile['email'].toString().toLowerCase();
      if (entry.key.toLowerCase() == key || id == key || email == key) {
        return MapEntry(entry.key, row);
      }
    }
    return null;
  }

  String _today() {
    final zoned = tz.TZDateTime.from(
      DateTime.now(),
      tz.getLocation('Asia/Kolkata'),
    );
    return _date(zoned);
  }

  String _date(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  double _meters(double lat1, double lon1, double lat2, double lon2) {
    const earth = 6371000.0;
    final p1 = lat1 * pi / 180;
    final p2 = lat2 * pi / 180;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = pow(sin(dLat / 2), 2) + cos(p1) * cos(p2) * pow(sin(dLon / 2), 2);
    return 2 * earth * asin(sqrt(a.toDouble()));
  }

  String _id(int bytes) => List<int>.generate(
    bytes,
    (_) => Random.secure().nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  Json _map(dynamic value) => Map<String, dynamic>.from(value as Map);
  List<dynamic> _list(dynamic value) => List<dynamic>.from(value as List);
}
