import 'package:flutter/material.dart';
import 'api.dart';
import 'design.dart';
import 'directory.dart';
import 'nav.dart';
import 'requests.dart';

class LeavePage extends StatefulWidget {
  final Api api;
  const LeavePage({super.key, required this.api});
  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  Json? balances, requests;
  Object? error;
  String filter = 'All';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Future.wait([
        widget.api.get('/leave-balances/me'),
        widget.api.get('/leave-requests', query: {'mine': 'true'}),
      ]);
      if (mounted) {
        setState(() {
          balances = r[0];
          requests = r[1];
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> openRequest(Json request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LeaveDetailsPage(api: widget.api, id: request['id'].toString()),
      ),
    );
    load();
  }

  void showPolicy() {
    final bs = items(balances);
    final allocation = bs.fold<num>(
      0,
      (sum, row) => sum + _num(row['allocation']),
    );
    final used = bs.fold<num>(0, (sum, row) => sum + _num(row['used']));
    final pending = bs.fold<num>(0, (sum, row) => sum + _num(row['reserved']));
    final available = bs.fold<num>(
      0,
      (sum, row) => sum + _num(row['available']),
    );
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Leave policy'),
        content: Text(
          'You have ${_count(allocation)} days allocated. Approved leave uses ${_count(used)} days, and pending requests hold ${_count(pending)}. ${_count(available)} days are still available. Weekends are not counted.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return FailureView(error!, load);
    if (balances == null) return const DashboardShimmer();
    final bs = items(balances);
    final available = bs.fold<num>(
      0,
      (sum, row) => sum + _num(row['available']),
    );
    final used = bs.fold<num>(0, (sum, row) => sum + _num(row['used']));
    final pending = bs.fold<num>(0, (sum, row) => sum + _num(row['reserved']));
    final leaveRows = items(
      requests,
    ).where((row) => row['kind'] == null || row['kind'] == 'Leave').toList();
    final history = leaveRows.where((row) {
      if (filter == 'All') return true;
      return row['status'] == filter;
    }).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Row(
            children: [
              const Text(
                'LEAVE',
                style: TextStyle(
                  color: Color(0xFF1B7F56),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Material(
                color: const Color(0xFFE7F6EE),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: showPolicy,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 16,
                          color: Color(0xFF1B7F56),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Leave Policy',
                          style: TextStyle(
                            color: Color(0xFF1B7F56),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Time for you',
            style: TextStyle(
              color: Color(0xFF1B2A4A),
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Take time off. Recharge. Come back stronger.',
            style: TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => openRoute(
                context,
                '/holidays',
                () => HolidaysPage(api: widget.api),
              ),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.celebration_outlined,
                      color: Color(0xFF1B7F56),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Holidays',
                            style: TextStyle(
                              color: Color(0xFF1B2A4A),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Company holidays this year',
                            style: TextStyle(
                              color: Color(0xFF8B93A7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Color(0xFF8B93A7)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6EE),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL AVAILABLE LEAVE',
                          style: TextStyle(
                            color: Color(0xFF1B7F56),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_count(available)} days',
                          style: const TextStyle(
                            color: Color(0xFF1B2A4A),
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Across all leave types',
                          style: TextStyle(
                            color: Color(0xFF6E7C8A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _LeaveRing(
                    available: available,
                    used: used,
                    pending: pending,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RingKey(
                        color: const Color(0xFFE15B64),
                        label: 'Used',
                        value: '${_count(used)} days',
                      ),
                      _RingKey(
                        color: const Color(0xFFE0A100),
                        label: 'Pending',
                        value: '${_count(pending)} days',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Leave Balance',
            style: TextStyle(
              color: Color(0xFF1B2A4A),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (bs.isEmpty)
            const EmptyView(
              'No leave allocation yet.',
              'Contact HR to configure your leave types and balance.',
            )
          else if (bs.length <= 3)
            Row(
              children: [
                for (var i = 0; i < bs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _BalanceCard(balance: bs[i])),
                ],
              ],
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final width = (box.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final balance in bs)
                      SizedBox(
                        width: width,
                        child: _BalanceCard(balance: balance),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ApplyLeavePage(api: widget.api),
                ),
              );
              load();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18),
                SizedBox(width: 8),
                Text(
                  'Apply for leave',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _LeaveCalendar(api: widget.api, requests: leaveRows),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'My requests & history',
                          style: TextStyle(
                            color: Color(0xFF1B2A4A),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: const Text('My requests'),
                                ),
                                body: RequestsPage(
                                  api: widget.api,
                                  mode: 'requests',
                                ),
                              ),
                            ),
                          );
                          load();
                        },
                        child: const Row(
                          children: [
                            Text(
                              'View all',
                              style: TextStyle(
                                color: Color(0xFF1B7F56),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Color(0xFF1B7F56),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final name in [
                          'All',
                          'Pending',
                          'Approved',
                          'Rejected',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: filter == name
                                  ? const Color(0xFFE7F6EE)
                                  : const Color(0xFFF3F5F7),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setState(() => filter = name),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: filter == name
                                          ? const Color(0xFF1B7F56)
                                          : const Color(0xFF8B93A7),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 8, 20),
                      child: Column(
                        children: [
                          Text(
                            filter == 'All'
                                ? 'No leave requests yet.'
                                : 'No ${filter.toLowerCase()} requests.',
                            style: const TextStyle(
                              color: Color(0xFF1B2A4A),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            filter == 'All'
                                ? 'Apply for leave and it will show here. Approved days come off that leave type.'
                                : 'Approved days are already removed from that leave type.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8B93A7),
                              fontSize: 12,
                            ),
                          ),
                          if (filter != 'All' && leaveRows.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() => filter = 'All'),
                              child: const Text('Show all requests'),
                            ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final request in history.take(8))
                          _LeaveHistoryRow(
                            request: request,
                            onTap: () => openRequest(request),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Month view of approved and pending leave plus company holidays.
class _LeaveCalendar extends StatefulWidget {
  final Api api;

  /// Own requests, used when the calendar endpoint is unavailable.
  final List<Json> requests;
  const _LeaveCalendar({required this.api, required this.requests});

  @override
  State<_LeaveCalendar> createState() => _LeaveCalendarState();
}

class _LeaveCalendarState extends State<_LeaveCalendar> {
  static const _ink = Color(0xFF1B2A4A);
  static const _soft = Color(0xFF8B93A7);
  static const _amber = Color(0xFFE0A100);
  static const _holiday = Color(0xFFE07A5F);
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  late DateTime month;
  late DateTime selected;
  List<Json>? remoteLeaves;
  List<Json> holidays = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
    selected = DateTime(now.year, now.month, now.day);
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1, 0);
    List<Json>? leaves;
    var days = <Json>[];
    try {
      final result = await widget.api.get(
        '/leave-requests/calendar',
        query: {'from': dateOnly(from), 'to': dateOnly(to)},
      );
      if (result['leaves'] is List) {
        leaves = _rows(result['leaves']);
        days = _rows(result['holidays']);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      remoteLeaves = leaves;
      holidays = days;
      loading = false;
    });
  }

  List<Json> get leaves =>
      remoteLeaves ??
      [
        for (final row in widget.requests)
          if (row['status'] == 'Approved' || row['status'] == 'Pending')
            {
              'start': row['start'],
              'end': row['end'],
              'status': row['status'],
              'type': row['type_name'] ?? 'Leave',
              'color': row['type_color'],
              'session': row['session'] ?? 'FULL',
              'own': true,
              'name': '',
            },
      ];

  Set<int> get workWeek {
    final list = widget.api.profile?['work_week'];
    if (list is List && list.isNotEmpty) {
      return list.map((d) => (d as num).toInt()).toSet();
    }
    return {1, 2, 3, 4, 5};
  }

  List<Json> leavesOn(DateTime day) {
    if (!workWeek.contains(day.weekday)) return const [];
    final key = dateOnly(day);
    return leaves
        .where(
          (row) =>
              row['start'].toString().compareTo(key) <= 0 &&
              row['end'].toString().compareTo(key) >= 0,
        )
        .toList();
  }

  Json? holidayOn(DateTime day) {
    final key = dateOnly(day);
    for (final row in holidays) {
      if (row['date'] == key) return row;
    }
    return null;
  }

  void shift(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      selected = DateTime(month.year, month.month, 1);
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7;
    final cells = ((offset + count) / 7).ceil() * 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var approved = 0, pending = 0;
    for (var d = 1; d <= count; d++) {
      final rows = leavesOn(DateTime(month.year, month.month, d));
      if (rows.any((r) => r['status'] == 'Approved')) approved++;
      if (rows.any((r) => r['status'] == 'Pending')) pending++;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F6EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_note_outlined,
                    color: primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave calendar',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$approved approved · $pending pending · ${holidays.length} holiday${holidays.length == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _soft, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => shift(-1),
                    icon: const Icon(Icons.chevron_left_rounded, color: _ink),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[month.month - 1]} ${month.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => shift(1),
                    icon: const Icon(Icons.chevron_right_rounded, color: _ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Text(
                      _weekdays[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: workWeek.contains(i == 0 ? 7 : i)
                            ? _soft
                            : _soft.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: loading ? 0.45 : 1,
              child: Column(
                children: [
                  for (var row = 0; row < cells ~/ 7; row++)
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(
                            child: _cell(
                              row * 7 + col - offset + 1,
                              count,
                              today,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _CalendarKey(color: primary, label: 'Approved', filled: true),
                _CalendarKey(color: _amber, label: 'Pending', filled: false),
                _CalendarKey(color: _holiday, label: 'Holiday', filled: true),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFEEF1F4)),
            _dayDetail(),
          ],
        ),
      ),
    );
  }

  Widget _cell(int date, int count, DateTime today) {
    if (date < 1 || date > count) return const SizedBox(height: 44);
    final day = DateTime(month.year, month.month, date);
    final rows = leavesOn(day);
    final holiday = holidayOn(day);
    final approved = rows.where((r) => r['status'] == 'Approved').toList();
    final waiting = rows.any((r) => r['status'] == 'Pending');
    final isSelected = day == selected;
    final isToday = day == today;
    final weekend = !workWeek.contains(day.weekday);
    final tone = approved.isNotEmpty
        ? _hex(approved.first['color']) ?? primary
        : null;
    Color? fill;
    Color text = weekend ? _soft : _ink;
    Border? border;
    if (tone != null) {
      fill = tone.withValues(alpha: 0.16);
      text = tone;
    } else if (waiting) {
      fill = _amber.withValues(alpha: 0.08);
      border = Border.all(color: _amber, width: 1.4);
      text = const Color(0xFFB07D00);
    } else if (holiday != null) {
      fill = _holiday.withValues(alpha: 0.14);
      text = _holiday;
    }
    if (isSelected) {
      fill = _ink;
      text = Colors.white;
      border = null;
    } else if (isToday && border == null) {
      border = Border.all(color: _ink, width: 1.4);
    }
    final others = rows.where((r) => r['own'] != true).length;
    return GestureDetector(
      onTap: () => setState(() => selected = day),
      child: SizedBox(
        height: 44,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: border,
                ),
                child: Text(
                  '$date',
                  style: TextStyle(
                    color: text,
                    fontWeight: tone != null || waiting || isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (others > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C6BF2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$others',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayDetail() {
    final rows = leavesOn(selected);
    final holiday = holidayOn(selected);
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${days[selected.weekday - 1]}, ${selected.day} ${_months[selected.month - 1]}',
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (holiday != null)
          _entry(
            color: _holiday,
            icon: Icons.celebration_outlined,
            title: holiday['name'].toString(),
            subtitle: holiday['optional'] == true
                ? 'Optional holiday'
                : 'Company holiday',
          ),
        for (final row in rows)
          _entry(
            color: row['status'] == 'Pending'
                ? _amber
                : _hex(row['color']) ?? primary,
            icon: Icons.beach_access_outlined,
            title: row['own'] == true || (row['name'] ?? '').toString().isEmpty
                ? row['type'].toString()
                : '${row['name']} · ${row['type']}',
            subtitle: switch (row['session']) {
              'FIRST_HALF' => 'First half',
              'SECOND_HALF' => 'Second half',
              _ => 'Full day',
            },
            status: row['status'].toString(),
          ),
        if (holiday == null && rows.isEmpty)
          const Text(
            'A regular working day. No leave or holiday here.',
            style: TextStyle(color: _soft, fontSize: 12.5),
          ),
      ],
    );
  }

  Widget _entry({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    String? status,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: _soft, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _CalendarKey extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;
  const _CalendarKey({
    required this.color,
    required this.label,
    required this.filled,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color.withValues(alpha: 0.3) : null,
          border: Border.all(color: color, width: 1.4),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF6E7C8A), fontSize: 11.5),
      ),
    ],
  );
}

List<Json> _rows(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Json>[];

Color? _hex(Object? value) {
  final text = value?.toString().replaceFirst('#', '') ?? '';
  if (text.length != 6) return null;
  final parsed = int.tryParse(text, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

num _num(dynamic value) => value is num ? value : 0;

String _count(num value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

class _RingKey extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _RingKey({
    required this.color,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF6E7C8A), fontSize: 11),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _LeaveRing extends StatelessWidget {
  final num available;
  final num used;
  final num pending;
  const _LeaveRing({
    required this.available,
    required this.used,
    required this.pending,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 72,
    child: CustomPaint(
      painter: _RingPainter(available: available, used: used, pending: pending),
      child: const Center(
        child: Icon(
          Icons.event_available_outlined,
          color: Color(0xFF1B7F56),
          size: 22,
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final num available;
  final num used;
  final num pending;
  const _RingPainter({
    required this.available,
    required this.used,
    required this.pending,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final total = available + used + pending;
    if (total <= 0) {
      paint.color = const Color(0xFFD7E8DF);
      canvas.drawArc(rect.deflate(6), 0, 6.28318, false, paint);
      return;
    }
    var start = -1.5708;
    for (final part in [
      (available, const Color(0xFF1B7F56)),
      (used, const Color(0xFFE15B64)),
      (pending, const Color(0xFFE0A100)),
    ]) {
      if (part.$1 <= 0) continue;
      final sweep = part.$1 / total * 6.28318;
      paint.color = part.$2;
      canvas.drawArc(rect.deflate(6), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.available != available || old.used != used || old.pending != pending;
}

class _BalanceCard extends StatelessWidget {
  final Json balance;
  const _BalanceCard({required this.balance});
  @override
  Widget build(BuildContext context) {
    final code =
        (balance['code']?.toString() ?? balance['id']?.toString() ?? '')
            .toLowerCase();
    final style = switch (code) {
      'sl' => (
        const Color(0xFFFDECEC),
        const Color(0xFFE15B64),
        Icons.medical_services_outlined,
      ),
      'el' => (
        const Color(0xFFFFF6E8),
        const Color(0xFFE0A100),
        Icons.spa_outlined,
      ),
      'lop' => (
        const Color(0xFFF1F3F5),
        const Color(0xFF6B7280),
        Icons.money_off_outlined,
      ),
      _ => (
        const Color(0xFFF3F0FF),
        const Color(0xFF7C6BF2),
        Icons.beach_access_outlined,
      ),
    };
    final allocation = _num(balance['allocation']);
    final used = _num(balance['used']);
    final pending = _num(balance['reserved']);
    final available = _num(balance['available']);
    final usedShare = allocation <= 0
        ? 0.0
        : (used / allocation).clamp(0, 1).toDouble();
    final pendingShare = allocation <= 0
        ? 0.0
        : (pending / allocation).clamp(0, 1 - usedShare).toDouble();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: style.$1,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(style.$3, color: style.$2, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              '${balance['name']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                //fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_count(available)} days',
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 4,
                child: Row(
                  children: [
                    if (usedShare > 0)
                      Expanded(
                        flex: (usedShare * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: style.$2),
                      ),
                    if (pendingShare > 0)
                      Expanded(
                        flex: (pendingShare * 1000).round().clamp(1, 1000),
                        child: ColoredBox(
                          color: style.$2.withValues(alpha: 0.35),
                        ),
                      ),
                    Expanded(
                      flex: ((1 - usedShare - pendingShare) * 1000)
                          .round()
                          .clamp(1, 1000),
                      child: const ColoredBox(color: Color(0xFFE8EDF2)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveHistoryRow extends StatelessWidget {
  final Json request;
  final VoidCallback onTap;
  const _LeaveHistoryRow({required this.request, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(request['start'].toString());
    final status = request['status']?.toString() ?? '';
    final tone = switch (status) {
      'Approved' => (const Color(0xFFE7F6EE), const Color(0xFF1B7F56)),
      'Rejected' => (const Color(0xFFFDECEC), const Color(0xFFE15B64)),
      'Pending' => (const Color(0xFFFFF6E0), const Color(0xFFC48A00)),
      _ => (const Color(0xFFF1F3F6), const Color(0xFF6E7C8A)),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F6EE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: start == null
                  ? const Text(
                      '--',
                      style: TextStyle(
                        color: Color(0xFF1B7F56),
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          start.day.toString().padLeft(2, '0'),
                          style: const TextStyle(
                            color: Color(0xFF1B7F56),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1,
                          ),
                        ),
                        Text(
                          _monthShort(start.month),
                          style: const TextStyle(
                            color: Color(0xFF1B7F56),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request['type_name'] ?? request['kind'] ?? 'Leave'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _leaveSpan(request),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tone.$1,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: tone.$2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFC5CAD3), size: 18),
          ],
        ),
      ),
    );
  }
}

String _eventWhen(dynamic value) {
  if (value == null || value.toString().isEmpty) return '';
  return '${shortDate(value.toString())}, ${clockText(value)}';
}

String _leaveSpan(Json request) {
  final days = _num(request['days']);
  final count = '${_count(days)} day${days == 1 ? '' : 's'}';
  final start = DateTime.tryParse(request['start'].toString());
  final end = DateTime.tryParse(request['end'].toString());
  if (start == null) return count;
  String dayMonth(DateTime day) => '${day.day} ${_monthShort(day.month)}';
  final sameDay =
      end == null ||
      (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day);
  if (sameDay) return '$count · ${dayMonth(start)} ${start.year}';
  return '$count · ${dayMonth(start)} – ${dayMonth(end)} ${end.year}';
}

String _monthShort(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

String _weekdayShort(DateTime day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];

class LeaveDetailsPage extends StatefulWidget {
  final Api api;
  final String id;
  const LeaveDetailsPage({super.key, required this.api, required this.id});
  @override
  State<LeaveDetailsPage> createState() => _LeaveDetailsPageState();
}

class _LeaveDetailsPageState extends State<LeaveDetailsPage> {
  Json? request;
  List<Json> balances = const [];
  Object? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await Future.wait([
        widget.api.get('/leave-requests/${widget.id}'),
        widget.api.get('/leave-balances/me'),
      ]);
      if (mounted) {
        setState(() {
          request = result[0];
          balances = items(result[1]);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> decide(String status) async {
    var remarks = '';
    if (status == 'Rejected') {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Reject request'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'Rejection remarks'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      remarks = controller.text.trim();
      controller.dispose();
      if (ok != true || !mounted) return;
      if (remarks.isEmpty) {
        message(context, 'Please add rejection remarks.');
        return;
      }
    } else if (status == 'cancel') {
      await comingSoon(
        context,
        'Cancel request',
        'Cancelling a leave request is coming soon.',
      );
      return;
    } else if (!await confirm(
      context,
      'Approve request?',
      'Approved days are counted as used.',
    )) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.api.mutate(
        '/leave-requests/${widget.id}/${switch (status) {
          'cancel' => 'cancel',
          'Rejected' => 'reject',
          _ => 'approve',
        }}',
        status == 'cancel' ? {} : {'comment': remarks},
      );
      await load();
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave Details')),
        body: FailureView(error!, load),
      );
    }
    final d = request;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave Details')),
        body: const DashboardShimmer(),
      );
    }
    final start = DateTime.tryParse(d['start'].toString());
    final end = DateTime.tryParse(d['end'].toString());
    final status = d['status']?.toString() ?? '';
    final days = _num(d['days']);
    final events = ((d['events'] as List?) ?? const [])
        .map((event) => Map<String, dynamic>.from(event as Map))
        .toList()
        .reversed
        .toList();
    final tone = switch (status) {
      'Approved' => (const Color(0xFFE7F6EE), const Color(0xFF1B7F56)),
      'Rejected' => (const Color(0xFFFDECEC), const Color(0xFFE15B64)),
      'Pending' => (const Color(0xFFFFF6E0), const Color(0xFFC48A00)),
      _ => (const Color(0xFFF1F3F6), const Color(0xFF6E7C8A)),
    };
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F8),
        title: const Text(
          'Leave Details',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        // actions: [
        //   if (canCancel || canDecide)
        //     PopupMenuButton<String>(
        //       enabled: !busy,
        //       onSelected: decide,
        //       itemBuilder: (context) => [
        //         if (canDecide)
        //           const PopupMenuItem(
        //             value: 'Approved',
        //             child: Text('Approve'),
        //           ),
        //         if (canDecide)
        //           const PopupMenuItem(value: 'Rejected', child: Text('Reject')),
        //         if (canCancel)
        //           const PopupMenuItem(
        //             value: 'cancel',
        //             child: Text('Cancel request'),
        //           ),
        //       ],
        //     ),
        // ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _detailCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F6EE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        start == null ? '--' : '${start.day}',
                        style: const TextStyle(
                          color: Color(0xFF1B7F56),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        start == null ? '' : _monthShort(start.month),
                        style: const TextStyle(
                          color: Color(0xFF1B7F56),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        start == null ? '' : '${start.year}',
                        style: const TextStyle(
                          color: Color(0xFF1B7F56),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tone.$1,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: tone.$2,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${d['type_name'] ?? 'Leave'}',
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_count(days)} day${days == 1 ? '' : 's'} (${shortDate(d['start'].toString())} – ${shortDate(d['end'].toString())})',
                        style: const TextStyle(
                          color: Color(0xFF6E7C8A),
                          fontSize: 12,
                        ),
                      ),
                      if (d['created'] != null)
                        Text(
                          'Applied on ${shortDate(d['created'].toString())}, ${clockText(d['created'])}',
                          style: const TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _detailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leave Information',
                  style: TextStyle(
                    color: Color(0xFF1B2A4A),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.calendar_today_outlined,
                  'Leave Type',
                  '${d['type_name'] ?? 'Leave'}',
                ),
                _infoRow(
                  Icons.schedule_outlined,
                  'Duration',
                  '${_count(days)} day${days == 1 ? '' : 's'}',
                ),
                _infoRow(
                  Icons.event_outlined,
                  'From',
                  start == null
                      ? shortDate(d['start'].toString())
                      : '${shortDate(d['start'].toString())} (${_weekdayShort(start)})',
                ),
                _infoRow(
                  Icons.event_outlined,
                  'To',
                  end == null
                      ? shortDate(d['end'].toString())
                      : '${shortDate(d['end'].toString())} (${_weekdayShort(end)})',
                ),
                _infoRow(Icons.wb_sunny_outlined, 'Session', 'Full day'),
                _infoRow(
                  Icons.description_outlined,
                  'Reason',
                  '${d['reason'] ?? ''}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _detailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Approval Details',
                  style: TextStyle(
                    color: Color(0xFF1B2A4A),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                _approvalStep(
                  title: switch (status) {
                    'Approved' => 'Approved',
                    'Rejected' => 'Rejected',
                    _ => 'Manager approval',
                  },
                  when: status == 'Pending'
                      ? 'Waiting for approval'
                      : _eventWhen(d['updated'] ?? d['created']),
                  name: 'Ramesh Kumar',
                  role: 'Reporting Manager',
                  icon: status == 'Rejected'
                      ? Icons.cancel
                      : status == 'Pending'
                      ? Icons.radio_button_checked
                      : Icons.check_circle,
                  iconColor: status == 'Rejected'
                      ? const Color(0xFFE15B64)
                      : status == 'Pending'
                      ? const Color(0xFFE0A100)
                      : const Color(0xFF1B7F56),
                  line: true,
                ),
                _approvalStep(
                  title: 'Submitted',
                  when: _eventWhen(
                    events
                            .cast<Json?>()
                            .where((event) => event?['action'] == 'Submitted')
                            .firstOrNull?['at'] ??
                        d['created'],
                  ),
                  name: 'You',
                  role:
                      widget.api.profile?['designation']?.toString() ??
                      'Team member',
                  icon: Icons.check_circle,
                  iconColor: const Color(0xFF1B7F56),
                  line: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _detailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leave Balance After This Request',
                  style: TextStyle(
                    color: Color(0xFF1B2A4A),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                for (final balance in balances) ...[
                  const SizedBox(height: 8),
                  _remainingRow(balance),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalStep({
    required String title,
    required String when,
    required String name,
    required String role,
    required IconData icon,
    required Color iconColor,
    required bool line,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 22),
              if (line)
                Container(width: 2, height: 64, color: const Color(0xFFD7E8DF)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2A4A),
                  ),
                ),
                Text(
                  when,
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFE7F6EE),
                      child: Text(
                        name.isEmpty ? '?' : name.substring(0, 1),
                        style: const TextStyle(
                          color: Color(0xFF1B7F56),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (role.isNotEmpty)
                            Text(
                              role,
                              style: const TextStyle(
                                color: Color(0xFF8B93A7),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _remainingRow(Json balance) {
    final code =
        (balance['code']?.toString() ?? balance['id']?.toString() ?? '')
            .toLowerCase();
    final style = switch (code) {
      'sl' => (
        const Color(0xFFFDECEC),
        const Color(0xFFE15B64),
        Icons.medical_services_outlined,
      ),
      'el' => (
        const Color(0xFFFFF6E8),
        const Color(0xFFE0A100),
        Icons.spa_outlined,
      ),
      'lop' => (
        const Color(0xFFF1F3F5),
        const Color(0xFF6B7280),
        Icons.money_off_outlined,
      ),
      _ => (
        const Color(0xFFF3F0FF),
        const Color(0xFF7C6BF2),
        Icons.beach_access_outlined,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: style.$1,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(style.$3, color: style.$2, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${balance['name']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${_count(_num(balance['available']))} days remaining',
            style: const TextStyle(
              color: Color(0xFF1B2A4A),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _detailCard({required Widget child}) => DecoratedBox(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE8EDF2)),
  ),
  child: Padding(padding: const EdgeInsets.all(14), child: child),
);

Widget _infoRow(IconData icon, String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Color(0xFF8B93A7)),
      const SizedBox(width: 10),
      SizedBox(
        width: 88,
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF6E7C8A), fontSize: 13),
        ),
      ),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: Color(0xFF1B2A4A),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    ],
  ),
);

class ApplyLeavePage extends StatefulWidget {
  final Api api;
  const ApplyLeavePage({super.key, required this.api});
  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  DateTime start = DateTime.now(), end = DateTime.now();
  List<Json>? balances;
  String? type;
  Json? policy;
  Object? error;
  bool busy = false;
  final reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    reason.addListener(() {
      if (mounted) setState(() {});
    });
    load();
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final r = await widget.api.get(
        '/leave-balances/me',
        query: {'year': '${start.year}'},
      );
      final h = await widget.api.get('/attendance/status');
      if (mounted) {
        setState(() {
          balances = items(r);
          policy = h['policy'];
          if (!balances!.any((b) => b['id'] == type)) {
            type = balances!.isEmpty ? null : balances!.first['id'];
          }
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> pick(bool first) async {
    final earliest = DateTime(DateTime.now().year - 1);
    final latest = DateTime(DateTime.now().year + 2, 12, 31);
    final d = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => _LeaveDateSheet(
        title: first ? 'From date' : 'To date',
        initial: first ? start : end,
        firstDate: first ? earliest : start,
        lastDate: latest,
        holidays: ((policy?['holidays'] as List?) ?? const [])
            .map((day) => day.toString())
            .toSet(),
      ),
    );
    if (d != null) {
      setState(() {
        if (first) {
          start = d;
          if (end.isBefore(start)) end = start;
        } else {
          end = d;
        }
      });
      load();
    }
  }

  Json? get selected {
    if (balances == null || type == null) return null;
    for (final balance in balances!) {
      if (balance['id'] == type) return balance;
    }
    return null;
  }

  Future<void> chooseType() async {
    if (balances == null || balances!.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => _LeaveTypeSheet(balances: balances!, selected: type),
    );
    if (picked != null && mounted) setState(() => type = picked);
  }

  int get days {
    if (policy == null || end.isBefore(start)) return 0;
    int total = 0;
    for (
      var d = DateTime(start.year, start.month, start.day);
      !d.isAfter(DateTime(end.year, end.month, end.day));
      d = d.add(const Duration(days: 1))
    ) {
      if (!(policy!['weekends'] as List).contains(d.weekday - 1) &&
          !(policy!['holidays'] as List).contains(dateOnly(d))) {
        total++;
      }
    }
    return total;
  }

  Future<void> submit() async {
    if (type == null || reason.text.trim().isEmpty) {
      message(context, 'Select a leave type and add a reason.');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await widget.api.mutate('/leave-requests', {
        'leaveTypeId': type,
        'startDate': dateOnly(start),
        'endDate': dateOnly(end),
        'startSession': 'FULL',
        'endSession': 'FULL',
        'reason': reason.text.trim(),
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                LeaveDetailsPage(api: widget.api, id: r['id'].toString()),
          ),
        );
      }
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FB),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF5F7FB),
      surfaceTintColor: const Color(0xFFF5F7FB),
      title: const Text(
        'Apply for Leave',
        style: TextStyle(
          color: Color(0xFF1B2A4A),
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    ),
    body: error != null
        ? FailureView(error!, load)
        : balances == null
        ? const DashboardShimmer()
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: ColoredBox(
                  color: const Color(0xFFE7F4EC),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 8, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TAKE A BREAK',
                                style: TextStyle(
                                  color: Color(0xFF1B8F6E),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Rest. Recharge.\nBe Your Best.',
                                style: TextStyle(
                                  color: Color(0xFF1B2A4A),
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Apply for leave and give yourself the time you deserve.',
                                style: TextStyle(
                                  color: Color(0xFF6E7C8A),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 10, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/leave_banner.jpg',
                            width: 150,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x101B2A4A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LeaveLabel('Leave Type'),
                      _LeaveBox(
                        onTap: chooseType,
                        child: Row(
                          children: [
                            const _LeaveIcon(Icons.event_available_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selected == null
                                        ? 'No leave available'
                                        : '${selected!['name']}',
                                    style: const TextStyle(
                                      color: Color(0xFF1B2A4A),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selected == null
                                        ? 'Ask HR to set a balance'
                                        : '${selected!['available']} days available',
                                    style: const TextStyle(
                                      color: Color(0xFF8B93A7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF8B93A7),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _LeaveLabel('From - To'),
                      Row(
                        children: [
                          Expanded(
                            child: _LeaveBox(
                              onTap: () => pick(true),
                              child: Row(
                                children: [
                                  const _LeaveIcon(
                                    Icons.calendar_month_outlined,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'From',
                                          style: TextStyle(
                                            color: Color(0xFF8B93A7),
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          _leaveDate(start),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF1B2A4A),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _LeaveBox(
                              onTap: () => pick(false),
                              child: Row(
                                children: [
                                  const _LeaveIcon(
                                    Icons.calendar_month_outlined,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'To',
                                          style: TextStyle(
                                            color: Color(0xFF8B93A7),
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          _leaveDate(end),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF1B2A4A),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (policy != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '$days working day${days == 1 ? '' : 's'} · weekends and holidays are excluded',
                            style: const TextStyle(
                              color: Color(0xFF8B93A7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const _LeaveLabel('Reason'),
                      TextField(
                        controller: reason,
                        maxLength: 1000,
                        maxLines: 4,
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF7F8FC),
                          hintText: 'Tell your manager a little more...',
                          hintStyle: const TextStyle(color: Color(0xFFB0B7C3)),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 52),
                            child: Icon(
                              Icons.description_outlined,
                              color: Color(0xFF1B2A4A),
                            ),
                          ),
                          contentPadding: const EdgeInsets.fromLTRB(
                            0,
                            14,
                            12,
                            14,
                          ),
                          counterText: '',
                          border: _leaveBorder,
                          enabledBorder: _leaveBorder,
                          focusedBorder: _leaveBorder,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${reason.text.length}/1000',
                          style: const TextStyle(
                            color: Color(0xFFB0B7C3),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: const StadiumBorder(),
                ),
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Submit request',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Color(0xFFB0B7C3)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Your request will be reviewed by your manager.',
                      style: TextStyle(color: Color(0xFFB0B7C3), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
  );
}

const _leaveBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
  borderSide: BorderSide(color: Color(0xFFE4E8F0)),
);

String _leaveDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

class _LeaveLabel extends StatelessWidget {
  final String text;
  const _LeaveLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF1B2A4A),
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Color(0xFFE15B64)),
          ),
        ],
      ),
    ),
  );
}

class _LeaveIcon extends StatelessWidget {
  final IconData icon;
  const _LeaveIcon(this.icon);
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: const BoxDecoration(
      color: Color(0xFFF1F3F8),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 18, color: Color(0xFF1B2A4A)),
  );
}

class _LeaveDateSheet extends StatefulWidget {
  final String title;
  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<String> holidays;
  const _LeaveDateSheet({
    required this.title,
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.holidays,
  });
  @override
  State<_LeaveDateSheet> createState() => _LeaveDateSheetState();
}

class _LeaveDateSheetState extends State<_LeaveDateSheet> {
  late DateTime selected;
  late DateTime month;
  @override
  void initState() {
    super.initState();
    selected = DateTime(
      widget.initial.year,
      widget.initial.month,
      widget.initial.day,
    );
    month = DateTime(selected.year, selected.month);
  }

  bool _inRange(DateTime day) {
    final first = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final last = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    return !day.isBefore(first) && !day.isAfter(last);
  }

  void _shift(int delta) {
    final next = DateTime(month.year, month.month + delta);
    final first = DateTime(widget.firstDate.year, widget.firstDate.month);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (next.isBefore(first) || next.isAfter(last)) return;
    setState(() => month = next);
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weeks = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final startPad = DateTime(month.year, month.month, 1).weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    final cells = <DateTime?>[
      for (var i = 0; i < startPad; i++) null,
      for (var day = 1; day <= days; day++)
        DateTime(month.year, month.month, day),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF8B93A7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _sheetDate(selected),
                style: const TextStyle(
                  color: Color(0xFF1B2A4A),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${months[month.month - 1]} ${month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final label in weeks)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 40,
              ),
              itemBuilder: (context, index) {
                final day = cells[index];
                if (day == null) return const SizedBox.shrink();
                final enabled = _inRange(day);
                final chosen = day == selected;
                final isToday =
                    day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final weekend =
                    day.weekday == DateTime.saturday ||
                    day.weekday == DateTime.sunday;
                final holiday = widget.holidays.contains(dateOnly(day));
                return Center(
                  child: Material(
                    color: chosen ? primary : Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: enabled
                          ? () => setState(() => selected = day)
                          : null,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isToday && !chosen)
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: primary),
                                ),
                              ),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: chosen
                                    ? Colors.white
                                    : enabled
                                    ? weekend
                                          ? const Color(0xFFB0B7C3)
                                          : const Color(0xFF1B2A4A)
                                    : const Color(0xFFD5DAE3),
                                fontWeight: chosen
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (holiday)
                              Positioned(
                                bottom: 4,
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: chosen ? Colors.white : primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Weekends are shaded. A dot marks a holiday.',
                style: TextStyle(color: Color(0xFF8B93A7), fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: const Color(0xFF1B2A4A),
                      side: const BorderSide(color: Color(0xFFE4E8F0)),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: primary,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('Select date'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveTypeSheet extends StatelessWidget {
  final List<Json> balances;
  final String? selected;
  const _LeaveTypeSheet({required this.balances, required this.selected});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Leave type',
              style: TextStyle(
                color: Color(0xFF1B2A4A),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick the balance this request should use.',
              style: TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            for (final balance in balances) ...[
              _TypeCard(
                balance: balance,
                on: balance['id'] == selected,
                onTap: () => Navigator.pop(context, balance['id'] as String),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final Json balance;
  final bool on;
  final VoidCallback onTap;
  const _TypeCard({
    required this.balance,
    required this.on,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final name = balance['name']?.toString() ?? 'Leave';
    final code = balance['code']?.toString() ?? '';
    final available = _num(balance['available']);
    final allocation = _num(balance['allocation']);
    final fraction = allocation == 0
        ? 0.0
        : (available / allocation).clamp(0.0, 1.0);
    final style = _typeStyle(code, name);
    return Material(
      color: on ? const Color(0xFFF3FBF7) : const Color(0xFFF7F8FC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: on ? primary : const Color(0xFFE4E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: style.$2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.$1, color: style.$3, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_count(available)} days available',
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction.toDouble(),
                        minHeight: 4,
                        backgroundColor: const Color(0xFFE4E8F0),
                        color: style.$3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                on ? Icons.check_circle : Icons.circle_outlined,
                color: on ? primary : const Color(0xFFD5DAE3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(IconData, Color, Color) _typeStyle(String code, String name) {
  final key = '$code $name'.toLowerCase();
  if (key.contains('sick') || key.contains('sl')) {
    return (
      Icons.medical_services_outlined,
      const Color(0xFFFDECEC),
      const Color(0xFFE15B64),
    );
  }
  if (key.contains('earn') || key.contains('el')) {
    return (
      Icons.savings_outlined,
      const Color(0xFFF3F0FF),
      const Color(0xFF6C4DFF),
    );
  }
  return (
    Icons.beach_access_outlined,
    const Color(0xFFE7F6EE),
    const Color(0xFF1B7F56),
  );
}

String _sheetDate(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

class _LeaveBox extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _LeaveBox({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF7F8FC),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE4E8F0)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    ),
  );
}
