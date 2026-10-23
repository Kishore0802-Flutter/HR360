import 'package:flutter/material.dart';
import 'api.dart';
import 'design.dart';

class EmployeesPage extends StatefulWidget {
  final Api api;
  const EmployeesPage({super.key, required this.api});
  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  static const _pageSize = 8;
  final search = TextEditingController();
  List<Json> people = [];
  List<Json> departments = [];
  String? departmentId;
  int page = 0;
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool keepDepartments = true}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.get(
        '/employees',
        query: {
          'q': search.text.trim(),
          if (departmentId != null) 'departmentId': departmentId!,
        },
      );
      final rows = items(result);
      if (!mounted) return;
      setState(() {
        people = rows;
        page = 0;
        if (!keepDepartments || departments.isEmpty) {
          final seen = <String>{};
          departments = [
            for (final row in rows)
              if (seen.add(row['departmentId']?.toString() ?? ''))
                {'id': row['departmentId'], 'name': row['department']},
          ];
        }
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = (people.length / _pageSize).ceil().clamp(1, 999);
    final start = page * _pageSize;
    final shown = people.skip(start).take(_pageSize).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F8),
        title: const Text(
          'Employees',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: error != null
          ? FailureView(error!, load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: TextField(
                    controller: search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => load(),
                    decoration: InputDecoration(
                      hintText: 'Search name, email or code',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Search',
                        onPressed: load,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (departments.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      children: [
                        _chip('All', departmentId == null, () {
                          setState(() => departmentId = null);
                          load();
                        }),
                        for (final row in departments)
                          if ((row['name']?.toString() ?? '').isNotEmpty)
                            _chip(
                              row['name'].toString(),
                              departmentId == row['id'],
                              () {
                                setState(
                                  () => departmentId = row['id']?.toString(),
                                );
                                load();
                              },
                            ),
                      ],
                    ),
                  ),
                Expanded(
                  child: loading
                      ? const DashboardShimmer()
                      : RefreshIndicator(
                          onRefresh: load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: [
                              Text(
                                '${people.length} people',
                                style: const TextStyle(
                                  color: Color(0xFF8B93A7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (shown.isEmpty)
                                const EmptyView(
                                  'No one matches',
                                  'Try another name or department.',
                                ),
                              for (final person in shown) ...[
                                _EmployeeCard(person),
                                const SizedBox(height: 10),
                              ],
                              if (pages > 1) ...[
                                const SizedBox(height: 6),
                                _Pager(
                                  page: page,
                                  pages: pages,
                                  onPrev: page == 0
                                      ? null
                                      : () => setState(() => page--),
                                  onNext: page >= pages - 1
                                      ? null
                                      : () => setState(() => page++),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: on ? const Color(0xFF1B7F56) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: on ? Colors.white : const Color(0xFF1B2A4A),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmployeeCard extends StatelessWidget {
  final Json person;
  const _EmployeeCard(this.person);
  @override
  Widget build(BuildContext context) {
    final name = person['name']?.toString() ?? '';
    final hue = (person['hue'] as num?)?.toDouble() ?? 200;
    final color = HSLColor.fromAHSL(1, hue % 360, 0.42, 0.42).toColor();
    final wash = HSLColor.fromAHSL(1, hue % 360, 0.45, 0.94).toColor();
    final place = [
      person['designation'],
      person['department'],
    ].where((part) => part != null && part.toString().isNotEmpty).join(' · ');
    final active = person['status']?.toString() == 'ACTIVE';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: wash,
              child: Text(
                _initials(name),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1B2A4A),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFE7F6EE)
                              : const Color(0xFFF3F5F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          active ? 'Active' : person['status'].toString(),
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF1B7F56)
                                : const Color(0xFF6E7C8A),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID ${person['code']}',
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 12,
                    ),
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      place,
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [person['office'], person['city']]
                        .where(
                          (part) => part != null && part.toString().isNotEmpty,
                        )
                        .join(', '),
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeamAttendancePage extends StatefulWidget {
  final Api api;
  const TeamAttendancePage({super.key, required this.api});
  @override
  State<TeamAttendancePage> createState() => _TeamAttendancePageState();
}

class _TeamAttendancePageState extends State<TeamAttendancePage> {
  static const _pageSize = 8;
  static const _filters = [
    '',
    'PRESENT',
    'CHECKED_IN',
    'NOT_CHECKED_IN',
    'LATE',
    'ON_LEAVE',
    'ABSENT',
    'MISSING_CHECKOUT',
  ];
  DateTime day = DateTime.now();
  String status = '';
  List<Json> rows = [];
  int page = 0;
  bool loading = true;
  Object? error;

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
      final result = await widget.api.get(
        '/attendance',
        query: {'date': dateOnly(day), if (status.isNotEmpty) 'status': status},
      );
      if (!mounted) return;
      setState(() {
        rows = items(result);
        page = 0;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  bool get isToday => dateOnly(day) == dateOnly(DateTime.now());

  void shift(int delta) {
    final next = day.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return;
    setState(() => day = next);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = (rows.length / _pageSize).ceil().clamp(1, 999);
    final shown = rows.skip(page * _pageSize).take(_pageSize).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F8),
        title: const Text(
          'Team attendance',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: error != null
          ? FailureView(error!, load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => shift(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          isToday
                              ? 'Today · ${day.day} ${_mon(day)}'
                              : '${day.day} ${_mon(day)} ${day.year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1B2A4A),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: isToday ? null : () => shift(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final filter in _filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              filter.isEmpty ? 'All' : _label(filter),
                            ),
                            selected: status == filter,
                            onSelected: (_) {
                              setState(() => status = filter);
                              load();
                            },
                            selectedColor: const Color(0xFFE7F6EE),
                            checkmarkColor: const Color(0xFF1B7F56),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: loading
                      ? const DashboardShimmer()
                      : RefreshIndicator(
                          onRefresh: load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              if (shown.isEmpty)
                                const EmptyView(
                                  'No attendance rows',
                                  'Nothing matches this day and status.',
                                ),
                              for (final row in shown) ...[
                                _AttendanceCard(row),
                                const SizedBox(height: 10),
                              ],
                              if (pages > 1)
                                _Pager(
                                  page: page,
                                  pages: pages,
                                  onPrev: page == 0
                                      ? null
                                      : () => setState(() => page--),
                                  onNext: page >= pages - 1
                                      ? null
                                      : () => setState(() => page++),
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

class _AttendanceCard extends StatelessWidget {
  final Json row;
  const _AttendanceCard(this.row);
  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? '';
    final tone = _tone(status);
    final minutes = (row['workedMinutes'] as num?)?.toInt() ?? 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['name']?.toString() ?? '',
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [row['code'], row['department']]
                            .where(
                              (part) =>
                                  part != null && part.toString().isNotEmpty,
                            )
                            .join(' · '),
                        style: const TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tone.$1,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _label(status),
                    style: TextStyle(
                      color: tone.$2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              shortDate(row['date'].toString()),
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _time('In', clockText(row['checkIn']))),
                Expanded(child: _time('Out', clockText(row['checkOut']))),
                Expanded(
                  child: _time(
                    'Worked',
                    '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _time(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFF1B2A4A),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ],
  );
}

class HolidaysPage extends StatefulWidget {
  final Api api;
  const HolidaysPage({super.key, required this.api});
  @override
  State<HolidaysPage> createState() => _HolidaysPageState();
}

class _HolidaysPageState extends State<HolidaysPage> {
  List<Json>? rows;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.api.get('/holidays');
      if (!mounted) return;
      final list = items(result);
      list.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
      setState(() {
        rows = list;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F8),
        title: const Text(
          'Holidays',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: error != null
          ? FailureView(error!, load)
          : rows == null
          ? const DashboardShimmer()
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  const Text(
                    'Company holidays',
                    style: TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Everyone in the company sees the same calendar.',
                    style: TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (rows!.isEmpty)
                    const EmptyView(
                      'No holidays yet',
                      'Published holidays will show up here.',
                    ),
                  for (final row in rows!) ...[
                    _HolidayCard(row),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }
}

class _HolidayCard extends StatelessWidget {
  final Json row;
  const _HolidayCard(this.row);
  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(row['date'].toString());
    final today = DateTime.now();
    final upcoming =
        date != null &&
        !DateTime(
          date.year,
          date.month,
          date.day,
        ).isBefore(DateTime(today.year, today.month, today.day));
    final months = const [
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: upcoming
                    ? const Color(0xFFE7F6EE)
                    : const Color(0xFFF3F5F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    date == null ? '' : '${date.day}'.padLeft(2, '0'),
                    style: TextStyle(
                      color: upcoming
                          ? const Color(0xFF1B7F56)
                          : const Color(0xFF1B2A4A),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    date == null ? '' : months[date.month - 1],
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                    row['name']?.toString() ?? '',
                    style: const TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date == null ? '' : '${date.year}',
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _label(row['type']?.toString() ?? 'public'),
                style: const TextStyle(
                  color: Color(0xFF6C4DFF),
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
}

class _Pager extends StatelessWidget {
  final int page;
  final int pages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pager({
    required this.page,
    required this.pages,
    required this.onPrev,
    required this.onNext,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
      Text(
        'Page ${page + 1} of $pages',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
    ],
  );
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}

String _label(String raw) {
  final text = raw.toLowerCase().replaceAll('_', ' ');
  if (text.isEmpty) return raw;
  return text[0].toUpperCase() + text.substring(1);
}

(Color, Color) _tone(String status) => switch (status.toUpperCase()) {
  'PRESENT' => (const Color(0xFFE7F6EE), const Color(0xFF1B7F56)),
  'CHECKED_IN' => (const Color(0xFFE7F6EE), const Color(0xFF1B7F56)),
  'LATE' => (const Color(0xFFEAF1FF), const Color(0xFF3B82F6)),
  'ABSENT' => (const Color(0xFFFDECEC), const Color(0xFFE15B64)),
  'MISSING_CHECKOUT' => (const Color(0xFFFDECEC), const Color(0xFFE15B64)),
  'NOT_CHECKED_IN' => (const Color(0xFFFFF6E0), const Color(0xFFC48A00)),
  'LEAVE' ||
  'ON_LEAVE' ||
  'HALF_DAY_LEAVE' => (const Color(0xFFF3F0FF), const Color(0xFF6C4DFF)),
  'OVERTIME' => (const Color(0xFFF3F0FF), const Color(0xFF6C4DFF)),
  _ => (const Color(0xFFF3F5F7), const Color(0xFF6E7C8A)),
};

String _mon(DateTime day) => const [
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
][day.month - 1];
