import 'package:flutter/material.dart';
import 'api.dart';
import 'design.dart';
import 'attendance.dart';

/// Resolves relative API paths (e.g. /api/v1/files/...) to full absolute URLs.
String resolveMediaUrl(String? url, Api api) {
  if (url == null || url.trim().isEmpty) return '';
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final base = Api.base.endsWith('/api/v1')
      ? Api.base.substring(0, Api.base.length - '/api/v1'.length)
      : Api.base;
  if (trimmed.startsWith('/')) {
    return '$base$trimmed';
  }
  return '$base/$trimmed';
}

// =============================================================================
// 1. REGULARISATIONS LIST PAGE
// =============================================================================

class RegularisationsPage extends StatefulWidget {
  final Api api;
  const RegularisationsPage({super.key, required this.api});

  @override
  State<RegularisationsPage> createState() => _RegularisationsPageState();
}

class _RegularisationsPageState extends State<RegularisationsPage> {
  bool loading = true;
  Object? error;
  List<Json> items = [];
  String filter = 'ALL'; // 'ALL', 'PENDING', 'APPROVED', 'REJECTED'

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await widget.api.v1(
        'GET',
        '/regularisations',
        query: {
          'mine': 'true',
          'page': 1,
          'pageSize': 50,
          'sortBy': 'createdAt',
          'sortDir': 'desc',
        },
      );
      final raw = res is Map && res['data'] is Map ? res['data'] : res;
      final list = raw is Map && raw['items'] is List
          ? (raw['items'] as List)
          : raw is List
              ? raw
              : <dynamic>[];
      if (mounted) {
        setState(() {
          items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          loading = false;
        });
      }
    } catch (e) {
      // Fallback for mock/test mode
      try {
        final legacy = await widget.api.get('/regularisations', query: {'mine': 'true'});
        final list = (legacy['items'] as List?) ?? [];
        if (mounted) {
          setState(() {
            items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            loading = false;
          });
        }
      } catch (err) {
        if (mounted) {
          setState(() {
            error = err;
            loading = false;
          });
        }
      }
    }
  }

  List<Json> get filteredItems {
    if (filter == 'ALL') return items;
    return items.where((it) {
      final st = it['status']?.toString().toUpperCase() ?? '';
      return st == filter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Regularisation Requests',
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ink),
            tooltip: 'Refresh',
            onPressed: load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFBE5E38),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Request'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CorrectionPage(api: widget.api),
            ),
          );
          load();
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          child: Column(
            children: [
              _filterBar(),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('ALL', 'All (${items.length})'),
            const SizedBox(width: 8),
            _filterChip('PENDING', 'Pending (${_count('PENDING')})'),
            const SizedBox(width: 8),
            _filterChip('APPROVED', 'Approved (${_count('APPROVED')})'),
            const SizedBox(width: 8),
            _filterChip('REJECTED', 'Rejected (${_count('REJECTED')})'),
          ],
        ),
      ),
    );
  }

  int _count(String status) => items
      .where((it) => (it['status']?.toString().toUpperCase() ?? '') == status)
      .length;

  Widget _filterChip(String key, String label) {
    final active = filter == key;
    return ChoiceChip(
      selected: active,
      label: Text(label),
      onSelected: (_) => setState(() => filter = key),
      selectedColor: const Color(0xFFFDF0EA),
      backgroundColor: const Color(0xFFF4F7F8),
      labelStyle: TextStyle(
        color: active ? const Color(0xFFBE5E38) : const Color(0xFF64748B),
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: active ? const Color(0xFFBE5E38) : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _content() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBE5E38)),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: load, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }
    final rows = filteredItems;
    if (rows.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: Color(0xFF94A3B8),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No regularisation requests',
                  style: TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You have not submitted any attendance correction requests.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return _requestCard(row);
      },
    );
  }

  Widget _requestCard(Json row) {
    final status = row['status']?.toString().toUpperCase() ?? 'PENDING';
    final workDate = row['workDate']?.toString() ?? row['day']?.toString() ?? '';
    final type = row['type']?.toString() ?? row['type_name']?.toString() ?? 'ADD_SESSION';
    final typeTitle = _humanType(type);
    final reason = row['reason']?.toString() ?? '';
    final reqIn = row['requestedCheckIn']?.toString() ?? row['proposed_in']?.toString();
    final reqOut = row['requestedCheckOut']?.toString() ?? row['proposed_out']?.toString();
    final employeeId = row['employeeId']?.toString() ??
        row['employee']?['id']?.toString() ??
        row['user_id']?.toString() ??
        widget.api.profile?['id']?.toString() ??
        '';

    final (statusBg, statusFg, statusLabel) = _statusStyle(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B3A4B),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Tap request -> Opens full attendance day detail view
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AttendanceDayDetailPage(
                  api: widget.api,
                  employeeId: employeeId,
                  date: workDate,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDF0EA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_calendar_outlined,
                        color: Color(0xFFBE5E38),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDateFriendly(workDate),
                            style: const TextStyle(
                              color: ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            typeTitle,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusFg,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (reqIn != null || reqOut != null) ...[
                  Row(
                    children: [
                      if (reqIn != null)
                        Expanded(
                          child: _timeTile(
                            'Requested Check-in',
                            _formatTimeOnly(reqIn),
                            Icons.login_rounded,
                            const Color(0xFF10B981),
                          ),
                        ),
                      if (reqIn != null && reqOut != null)
                        const SizedBox(width: 12),
                      if (reqOut != null)
                        Expanded(
                          child: _timeTile(
                            'Requested Check-out',
                            _formatTimeOnly(reqOut),
                            Icons.logout_rounded,
                            const Color(0xFFF59E0B),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (reason.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Reason: $reason',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Tap to view day details & photos',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String) _statusStyle(String s) {
    switch (s) {
      case 'APPROVED':
        return (const Color(0xFFD1FAE5), const Color(0xFF059669), 'Approved');
      case 'REJECTED':
        return (const Color(0xFFFFE4E6), const Color(0xFFE11D48), 'Rejected');
      case 'PENDING':
      default:
        return (const Color(0xFFFEF3C7), const Color(0xFFD97706), 'Pending');
    }
  }

  String _humanType(String t) {
    switch (t) {
      case 'ADD_SESSION':
        return 'Add missing session';
      case 'EDIT_SESSION':
      case 'MISSING_CHECKOUT':
        return 'Missing checkout adjustment';
      case 'VOID_SESSION':
        return 'Void session';
      default:
        return t.replaceAll('_', ' ');
    }
  }

  String _formatDateFriendly(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTimeOnly(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}

// =============================================================================
// 2. ATTENDANCE DAY DETAIL PAGE (Full view: stats, sessions, photos, regularisations)
// =============================================================================

class AttendanceDayDetailPage extends StatefulWidget {
  final Api api;
  final String? employeeId;
  final String date; // e.g. "2026-10-25"
  final Json? initialDayData;

  const AttendanceDayDetailPage({
    super.key,
    required this.api,
    this.employeeId,
    required this.date,
    this.initialDayData,
  });

  @override
  State<AttendanceDayDetailPage> createState() => _AttendanceDayDetailPageState();
}

class _AttendanceDayDetailPageState extends State<AttendanceDayDetailPage> {
  late DateTime currentDate;
  bool loading = true;
  Object? error;
  Json? dayPayload;

  @override
  void initState() {
    super.initState();
    currentDate = DateTime.tryParse(widget.date) ?? DateTime.now();
    loadDay();
  }

  Future<void> loadDay() async {
    setState(() {
      loading = true;
      error = null;
    });

    final empId = widget.employeeId ??
        widget.api.profile?['id']?.toString() ??
        'ffe7154f-ba0e-4988-84a5-320bbd6bac53';
    final dateStr = dateOnly(currentDate);

    try {
      final res = await widget.api.v1(
        'GET',
        '/attendance/days/$empId/$dateStr',
      );
      if (mounted) {
        final map = res is Map ? Map<String, dynamic>.from(res) : null;
        setState(() {
          dayPayload = map != null && map['data'] is Map
              ? Map<String, dynamic>.from(map['data'] as Map)
              : map;
          loading = false;
        });
      }
    } catch (e) {
      try {
        final data = await widget.api.get(
          '/attendance/me',
          query: {'from': dateStr, 'to': dateStr},
        );
        final dayObj = data['day'] ?? widget.initialDayData;
        if (mounted) {
          setState(() {
            dayPayload = {
              'employee': data['employee'] ?? widget.api.profile,
              'day': dayObj,
              'totals': data['totals'],
              'sessions': data['sessions'] ?? [],
              'events': data['events'] ?? [],
              'regularisations': data['regularisations'] ?? [],
            };
            loading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          if (widget.initialDayData != null) {
            setState(() {
              dayPayload = {
                'employee': widget.api.profile,
                'day': widget.initialDayData,
                'totals': {},
                'sessions': [],
                'events': [],
                'regularisations': [],
              };
              loading = false;
            });
          } else {
            setState(() {
              error = e;
              loading = false;
            });
          }
        }
      }
    }
  }

  void _previousDay() {
    setState(() => currentDate = currentDate.subtract(const Duration(days: 1)));
    loadDay();
  }

  void _nextDay() {
    setState(() => currentDate = currentDate.add(const Duration(days: 1)));
    loadDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance Details',
          style: TextStyle(
            color: ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ink),
            onPressed: loadDay,
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFBE5E38)))
            : RefreshIndicator(
                onRefresh: loadDay,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _headerCard(),
                    const SizedBox(height: 14),
                    _dayTotalsCard(),
                    const SizedBox(height: 14),
                    _sessionsCard(),
                    const SizedBox(height: 14),
                    _evidenceCard(),
                    const SizedBox(height: 14),
                    _regularisationsCard(),
                  ],
                ),
              ),
      ),
    );
  }

  // 1. Header Card (Breadcrumb, title, date navigation, request correction)
  Widget _headerCard() {
    final emp = dayPayload?['employee'] is Map ? dayPayload!['employee'] as Map : null;
    final empName = emp?['fullName']?.toString() ??
        widget.api.profile?['name']?.toString() ??
        'Arun Kumar';
    final empCode = emp?['employeeCode']?.toString() ??
        widget.api.profile?['employee_code']?.toString() ??
        'DEMO-E01';

    final day = dayPayload?['day'] is Map ? dayPayload!['day'] as Map : widget.initialDayData;
    final status = day?['status']?.toString().toUpperCase() ?? 'PRESENT';
    final isPresent = status == 'PRESENT';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B3A4B),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance  /  $empName  /  ${_formatDateShort(currentDate)}',
            style: const TextStyle(
              color: Color(0xFF8B93A7),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDateLong(currentDate),
                  style: const TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPresent ? const Color(0xFFE7F6EE) : const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isPresent ? const Color(0xFF1B7F56) : const Color(0xFFE15B64),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPresent ? 'Present' : status,
                      style: TextStyle(
                        color: isPresent ? const Color(0xFF1B7F56) : const Color(0xFFE15B64),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFBE5E38),
                child: Text(
                  _initials(empName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empName,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$empCode · You',
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Previous / Next Date arrows
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _previousDay,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.chevron_left_rounded, size: 20, color: ink),
                      ),
                    ),
                    Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                    InkWell(
                      onTap: _nextDay,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.chevron_right_rounded, size: 20, color: ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CorrectionPage(
                      api: widget.api,
                      day: currentDate,
                      record: dayPayload?['day'] is Map ? dayPayload!['day'] as Json : null,
                    ),
                  ),
                );
                loadDay();
              },
              icon: const Icon(Icons.edit_calendar_outlined, size: 14),
              label: const Text('Request correction'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBE5E38),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Day totals card (First in, Last out, Sessions, Gross, Break, Net, Overtime, Late by)
  Widget _dayTotalsCard() {
    final day = dayPayload?['day'] is Map ? dayPayload!['day'] as Map : widget.initialDayData;
    final firstIn = _formatTimeIso(day?['firstInAt']?.toString());
    final lastOut = _formatTimeIso(day?['lastOutAt']?.toString());
    final sessionsCount = day?['sessionsCount'] ?? 1;
    final completedSessions = day?['completedSessions'] ?? (day?['lastOutAt'] != null ? 1 : 0);
    final netMinutes = (day?['netMinutes'] as num?)?.toInt() ?? 0;
    final grossMinutes = (day?['grossMinutes'] as num?)?.toInt() ?? netMinutes;
    final breakMinutes = (day?['breakMinutes'] as num?)?.toInt() ?? 0;
    final overtimeMinutes = (day?['overtimeMinutes'] as num?)?.toInt() ?? 0;
    final isLate = day?['isLate'] == true;
    final lateMinutes = (day?['lateMinutes'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1B3A4B), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Day totals',
            style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            'Only completed, non-voided sessions count towards hours.',
            style: TextStyle(color: Color(0xFF8B93A7), fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.15,
            children: [
              _metricBox('First in', firstIn),
              _metricBox('Last out', lastOut),
              _metricBox('Sessions', '$completedSessions / $sessionsCount'),
              _metricBox('Gross', _formatDurationMins(grossMinutes)),
              _metricBox('Break deducted', _formatDurationMins(breakMinutes)),
              _metricBox('Net hours', _formatDurationMins(netMinutes)),
              _metricBox('Overtime', _formatDurationMins(overtimeMinutes)),
              _metricBox(
                'Late by',
                lateMinutes > 0
                    ? (lateMinutes < 60
                        ? '$lateMinutes min'
                        : lateMinutes % 60 == 0
                            ? '${lateMinutes ~/ 60}h'
                            : '${lateMinutes ~/ 60}h ${lateMinutes % 60}m')
                    : '—',
              ),
            ],
          ),
          if (isLate) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Exceptions',
                  style: TextStyle(color: Color(0xFF8B93A7), fontSize: 11.5),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF4E8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEFE2CB)),
                  ),
                  child: const Text(
                    'Late arrival',
                    style: TextStyle(
                      color: Color(0xFF946522),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B93A7),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Sessions card (table of check-in / check-out pairs)
  Widget _sessionsCard() {
    final list = dayPayload?['sessions'] as List? ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1B3A4B), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sessions',
            style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            'Pairs of check-in and check-out after approved corrections. Original events are never modified.',
            style: TextStyle(color: Color(0xFF8B93A7), fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No recorded session pairs for this date.',
                style: TextStyle(color: Color(0xFF8B93A7), fontSize: 12.5),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(child: Text('Check in', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700))),
                  Expanded(child: Text('Check out', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700))),
                  Expanded(child: Text('Duration', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700))),
                  SizedBox(width: 40, child: Text('Notes', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            for (final s in list)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatTimeIso(s['checkIn']?.toString()),
                        style: const TextStyle(color: ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formatTimeIso(s['checkOut']?.toString()),
                        style: const TextStyle(color: ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formatDurationMins((s['minutes'] as num?)?.toInt() ?? 0),
                        style: const TextStyle(color: ink, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(
                      width: 40,
                      child: Text('—', style: TextStyle(color: Color(0xFF8B93A7), fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // 4. Raw events & evidence card (WITH IMAGES!)
  Widget _evidenceCard() {
    final events = dayPayload?['events'] as List? ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1B3A4B), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raw events & evidence',
                      style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Photos are shown via short-lived links; access is audited.',
                      style: TextStyle(color: Color(0xFF8B93A7), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${events.length} event${events.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No raw check-in / check-out events recorded.',
                style: TextStyle(color: Color(0xFF8B93A7), fontSize: 12.5),
              ),
            )
          else
            for (final ev in events) ...[
              _eventEvidenceItem(ev),
              if (ev != events.last) const Divider(height: 20),
            ],
        ],
      ),
    );
  }

  Widget _eventEvidenceItem(dynamic ev) {
    final eventType = ev['eventType']?.toString().toUpperCase() ?? 'CHECK_IN';
    final isIn = eventType == 'CHECK_IN';
    final serverTime = _formatTimeIso(ev['serverTime']?.toString());
    final deviceTime = _formatTimeIso(ev['deviceTime']?.toString());
    final lat = (ev['latitude'] as num?)?.toDouble();
    final lon = (ev['longitude'] as num?)?.toDouble();
    final accuracy = (ev['accuracy'] as num?)?.round();
    final photo = ev['photo'] is Map ? ev['photo'] as Map : null;
    final photoUrl = resolveMediaUrl(photo?['url']?.toString(), widget.api);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo Image Thumbnail (Selfie evidence)
        GestureDetector(
          onTap: photoUrl.isNotEmpty
              ? () => _openFullPhotoModal(photoUrl, isIn ? 'Check-in Selfie' : 'Check-out Selfie')
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 72,
              height: 72,
              color: const Color(0xFFE2E8F0),
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      headers: {
                        if (widget.api.token != null)
                          'Authorization': 'Bearer ${widget.api.token}',
                      },
                      errorBuilder: (_, __, ___) => _fallbackPhoto(),
                    )
                  : _fallbackPhoto(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Event details column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isIn ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                    size: 15,
                    color: isIn ? const Color(0xFF1B7F56) : const Color(0xFFE15B64),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${isIn ? 'Check in' : 'Check out'}  ${_formatDateShort(currentDate)}, $serverTime',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (lat != null && lon != null)
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFFBE5E38)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}${accuracy != null ? ' (±$accuracy m)' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFBE5E38),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 2),
              Text(
                'Device time ${_formatDateShort(currentDate)}, $deviceTime',
                style: const TextStyle(
                  color: Color(0xFF8B93A7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _openEventDetailsModal(ev),
          child: const Text('Details', style: TextStyle(fontSize: 11.5)),
        ),
      ],
    );
  }

  Widget _fallbackPhoto() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.person_rounded, color: Color(0xFF94A3B8), size: 28),
      ),
    );
  }

  void _openFullPhotoModal(String url, String title) {
    showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(dialog),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                headers: {
                  if (widget.api.token != null)
                    'Authorization': 'Bearer ${widget.api.token}',
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.white,
                  child: const Center(child: Text('Photo preview unavailable')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEventDetailsModal(dynamic ev) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Event Details (${ev['eventType'] ?? 'CHECK_IN'})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink),
              ),
              const Divider(height: 20),
              detail('Event ID', ev['id']?.toString() ?? '—'),
              detail('Server time', ev['serverTime']?.toString() ?? '—'),
              detail('Device time', ev['deviceTime']?.toString() ?? '—'),
              detail('Source', ev['source']?.toString() ?? '—'),
              detail('Latitude', ev['latitude']?.toString() ?? '—'),
              detail('Longitude', ev['longitude']?.toString() ?? '—'),
              detail('Accuracy', '${ev['accuracy'] ?? '—'} m'),
              detail('Review status', ev['reviewStatus']?.toString() ?? 'NOT_REQUIRED'),
            ],
          ),
        ),
      ),
    );
  }

  // 5. Regularisations card
  Widget _regularisationsCard() {
    final regs = dayPayload?['regularisations'] as List? ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1B3A4B), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Regularisations',
                  style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CorrectionPage(
                        api: widget.api,
                        day: currentDate,
                      ),
                    ),
                  );
                  loadDay();
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (regs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No regularisations requested for this date.',
                style: TextStyle(color: Color(0xFF8B93A7), fontSize: 12),
              ),
            )
          else
            for (final r in regs) ...[
              _regularisationItem(r),
              if (r != regs.last) const Divider(height: 16),
            ],
        ],
      ),
    );
  }

  Widget _regularisationItem(dynamic r) {
    final status = r['status']?.toString().toUpperCase() ?? 'PENDING';
    final reason = r['reason']?.toString() ?? '';
    final reqIn = _formatTimeIso(r['requestedCheckIn']?.toString());
    final reqOut = _formatTimeIso(r['requestedCheckOut']?.toString());
    final isPending = status == 'PENDING';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Add missing session',
                style: TextStyle(color: ink, fontSize: 13.5, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isPending ? 'Pending' : status,
                style: TextStyle(
                  color: isPending ? const Color(0xFFD97706) : const Color(0xFF059669),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'In $reqIn Out $reqOut · ${_formatDateShort(currentDate)}',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            reason,
            style: const TextStyle(color: ink, fontSize: 12.5),
          ),
        ],
        if (r['attachment'] != null || r['attachmentId'] != null) ...[
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final att = r['attachment'] is Map ? r['attachment'] as Map : null;
              final url = resolveMediaUrl(att?['url']?.toString(), widget.api);
              return InkWell(
                onTap: url.isNotEmpty
                    ? () => _openFullPhotoModal(url, 'Regularisation Attachment')
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(
                        url.isNotEmpty ? 'View Attachment' : 'Attachment Included',
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // Formatting helpers
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _formatDateShort(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatDateLong(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTimeIso(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDurationMins(int mins) {
    if (mins <= 0) return '0h';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
