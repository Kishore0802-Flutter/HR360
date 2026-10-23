import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'api.dart';
import 'design.dart';
import 'directory.dart';
import 'nav.dart';
import 'requests.dart';

enum AttendanceFilter {
  thisWeek,
  thisMonth,
  lastMonth,
  last30Days,
  custom,
}

String filterLabel(AttendanceFilter filter, [DateTimeRange? customRange]) {
  switch (filter) {
    case AttendanceFilter.thisWeek:
      return 'This week';
    case AttendanceFilter.thisMonth:
      return 'This month';
    case AttendanceFilter.lastMonth:
      return 'Last month';
    case AttendanceFilter.last30Days:
      return 'Last 30 days';
    case AttendanceFilter.custom:
      if (customRange != null) {
        return '${_shortDay(customRange.start)} - ${_shortDay(customRange.end)}';
      }
      return 'Custom range...';
  }
}

class AttendancePage extends StatefulWidget {
  final Api api;
  const AttendancePage({super.key, required this.api});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  AttendanceFilter filter = AttendanceFilter.thisMonth;
  DateTimeRange? customRange;
  DateTime focus = DateTime.now();
  DateTime? selected;
  Json? data;
  Json? home;
  Object? error;
  bool synced = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({AttendanceFilter? newFilter, DateTimeRange? range}) async {
    if (newFilter != null) filter = newFilter;
    if (range != null) customRange = range;
    if (mounted) setState(() => error = null);
    try {
      final now = DateTime.now();
      DateTime fromDate;
      DateTime toDate;

      switch (filter) {
        case AttendanceFilter.thisWeek:
          final monday = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1));
          fromDate = monday;
          toDate = DateTime(now.year, now.month, now.day);
          break;
        case AttendanceFilter.thisMonth:
          fromDate = DateTime(focus.year, focus.month, 1);
          toDate = DateTime(focus.year, focus.month + 1, 0);
          break;
        case AttendanceFilter.lastMonth:
          fromDate = DateTime(now.year, now.month - 1, 1);
          toDate = DateTime(now.year, now.month, 0);
          break;
        case AttendanceFilter.last30Days:
          fromDate = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 30));
          toDate = DateTime(now.year, now.month, now.day);
          break;
        case AttendanceFilter.custom:
          fromDate = customRange?.start ?? DateTime(now.year, now.month, 1);
          toDate = customRange?.end ?? DateTime(now.year, now.month + 1, 0);
          break;
      }

      final results = await Future.wait<dynamic>([
        widget.api.get(
          '/attendance/me',
          query: {'from': dateOnly(fromDate), 'to': dateOnly(toDate)},
        ),
        widget.api
            .get('/attendance/status')
            .catchError((_) => <String, dynamic>{}),
      ]);

      final attendance = results[0] as Json;
      final summary = results[1] as Json;

      final todayStr = summary['today']?.toString();
      final today = todayStr != null ? DateTime.tryParse(todayStr) : now;
      final officeDay = today != null
          ? DateTime(today.year, today.month, today.day)
          : DateTime(now.year, now.month, now.day);

      if (!synced) {
        focus = DateTime(officeDay.year, officeDay.month);
        selected = officeDay;
        synced = true;
      }

      if (!mounted) return;
      setState(() {
        home = summary.isNotEmpty ? summary : null;
        data = attendance;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  void shiftMonth(int delta) {
    focus = DateTime(focus.year, focus.month + delta);
    filter = AttendanceFilter.thisMonth;
    final inMonth = selected != null &&
        selected!.year == focus.year &&
        selected!.month == focus.month;
    if (!inMonth) {
      selected = DateTime(focus.year, focus.month, 1);
    }
    load();
  }

  List<Json> get daysList {
    final raw = data?['days'];
    if (raw is List) {
      final list =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      list.sort((a, b) => (b['date']?.toString() ?? '')
          .compareTo(a['date']?.toString() ?? ''));
      return list;
    }
    return const [];
  }

  Map<String, Json> get daysByDate {
    final map = <String, Json>{};
    for (final day in daysList) {
      final date = day['date']?.toString();
      if (date != null && date.isNotEmpty) {
        map[date] = day;
      }
    }
    return map;
  }

  String markFor(DateTime day) {
    final key = dateOnly(day);
    final dayData = daysByDate[key];
    if (dayData != null) {
      final status = dayData['status']?.toString().toUpperCase();
      if (status == 'PRESENT') {
        return dayData['isLate'] == true ? 'late' : 'present';
      }
      if (status == 'ABSENT') return 'absent';
      if (status == 'HOLIDAY') return 'holiday';
      if (status == 'ON_LEAVE' || status == 'HALF_DAY_LEAVE') return 'leave';
      if (status == 'WEEKEND') return 'weekend';
    }
    return 'none';
  }

  Future<void> openDay(DateTime day) async {
    setState(() => selected = day);
    final key = dateOnly(day);
    final dayData = daysByDate[key];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => _DaySheet(
        api: widget.api,
        day: day,
        dayData: dayData,
        mark: markFor(day),
        office: widget.api.profile?['office'] as Json?,
      ),
    );
    if (mounted) load();
  }

  Future<void> onFilterPicked(AttendanceFilter picked) async {
    if (picked == AttendanceFilter.custom) {
      final now = DateTime.now();
      final pickedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 2),
        initialDateRange: customRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: DateTime(now.year, now.month, now.day),
            ),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B7F56),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1B2A4A),
            ),
          ),
          child: child!,
        ),
      );
      if (pickedRange != null) {
        focus = DateTime(pickedRange.end.year, pickedRange.end.month);
        load(newFilter: AttendanceFilter.custom, range: pickedRange);
      }
    } else {
      if (picked == AttendanceFilter.lastMonth) {
        final now = DateTime.now();
        focus = DateTime(now.year, now.month - 1);
      } else if (picked == AttendanceFilter.thisMonth ||
          picked == AttendanceFilter.thisWeek) {
        final now = DateTime.now();
        focus = DateTime(now.year, now.month);
      }
      load(newFilter: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return FailureView(error!, load);
    if (data == null) return const DashboardShimmer();

    final totals = (data?['totals'] as Json?) ?? const {};
    final employee =
        (data?['employee'] as Json?) ?? widget.api.profile ?? {};
    final employeeName = employee['fullName']?.toString() ??
        employee['name']?.toString() ??
        widget.api.profile?['name']?.toString() ??
        'there';

    final present = ((totals['present'] as num?) ?? 0).toInt();
    final absent = ((totals['absent'] as num?) ?? 0).toInt();
    final late = ((totals['late'] as num?) ?? 0).toInt();
    final total = present + absent;
    final totalNetMinutes =
        ((totals['totalNetMinutes'] as num?) ?? 0).toInt();
    final averageNetMinutes =
        ((totals['averageNetMinutes'] as num?) ?? 0).toInt();
    final holidays = ((totals['holidays'] as num?) ?? 0).toInt();

    final now = DateTime.now();
    final currentDay =
        selected ?? DateTime(focus.year, focus.month, 1);
    final selectedDayData = daysByDate[dateOnly(currentDay)];

    final firstIn = selectedDayData?['firstInAt']?.toString();
    final lastOut = selectedDayData?['lastOutAt']?.toString();
    final isWorking =
        selectedDayData?['hasOpenSession'] == true ||
        (firstIn != null && lastOut == null);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/logo_mark.png',
                      height: 26,
                      alignment: Alignment.centerLeft,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'From Joining to Growing',
                      style:
                          TextStyle(color: Color(0xFF8E99A8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsPage(api: widget.api),
                  ),
                ),
                icon: Badge(
                  isLabelVisible:
                      ((home?['unread'] as num?) ?? 0) > 0,
                  smallSize: 8,
                  backgroundColor: const Color(0xFFE85D4C),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF1B3A4B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_partOfDay(now)},\n$employeeName',
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Here's your attendance summary",
                      style:
                          TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/dash_afternoon.png',
                  width: 108,
                  height: 84,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          if (widget.api.can('employees:view') &&
              widget.api.can('attendance:review')) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Shortcut(
                    icon: Icons.groups_outlined,
                    title: 'Employees',
                    subtitle: 'Directory',
                    onTap: () => openRoute(
                      context,
                      '/team/employees',
                      () => EmployeesPage(api: widget.api),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Shortcut(
                    icon: Icons.fact_check_outlined,
                    title: 'Team log',
                    subtitle: 'All attendance',
                    onTap: () => openRoute(
                      context,
                      '/team/attendance',
                      () => TeamAttendancePage(api: widget.api),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // 1st: Totals summary cards
          Row(
            children: [
              _StatCard(
                icon: Icons.calendar_month_outlined,
                label: 'Present',
                value: '$present',
                unit: present == 1 ? 'day' : 'days',
                color: const Color(0xFF1B7F56),
                background: const Color(0xFFE7F6EE),
              ),
              const _StatArrow(),
              _StatCard(
                icon: Icons.cancel_outlined,
                label: 'Absent',
                value: '$absent',
                unit: absent == 1 ? 'day' : 'days',
                color: const Color(0xFFE15B64),
                background: const Color(0xFFFDECEC),
              ),
              const _StatArrow(),
              _StatCard(
                icon: Icons.schedule_outlined,
                label: 'Late',
                value: '$late',
                unit: late == 1 ? 'day' : 'days',
                color: const Color(0xFF3B82F6),
                background: const Color(0xFFEAF1FF),
              ),
              const _StatArrow(),
              _StatCard(
                icon: Icons.calendar_today_outlined,
                label: 'Total',
                value: '$total',
                unit: 'days',
                color: const Color(0xFF7C6BF2),
                background: const Color(0xFFF3F0FF),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 2nd: Calendar Card
          _AttendanceCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: Color(0xFF1B3A4B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _monthTitle(focus),
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => shiftMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    _WeekLabel('Sun'),
                    _WeekLabel('Mon'),
                    _WeekLabel('Tue'),
                    _WeekLabel('Wed'),
                    _WeekLabel('Thu'),
                    _WeekLabel('Fri'),
                    _WeekLabel('Sat'),
                  ],
                ),
                const SizedBox(height: 6),
                _MonthGrid(
                  month: focus,
                  selected: currentDay,
                  markFor: markFor,
                  onPick: openDay,
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _LegendDot(
                      color: Color(0xFF1B7F56),
                      label: 'Present',
                    ),
                    _LegendDot(
                      color: Color(0xFFE15B64),
                      label: 'Absent',
                    ),
                    _LegendDot(
                      color: Color(0xFF3B82F6),
                      label: 'Late',
                    ),
                    _LegendDot(
                      color: Color(0xFFC5CAD3),
                      label: 'Holiday',
                    ),
                    _LegendDot(
                      color: Color(0xFFF59E0B),
                      label: 'Leave',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Selected Day Log
          _AttendanceCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.event_note_outlined,
                      size: 18,
                      color: Color(0xFF1B3A4B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _sameDay(currentDay, now)
                            ? "Today's Log"
                            : 'Day log',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => openDay(currentDay),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Text(
                          '${_shortDay(currentDay)} >',
                          style: const TextStyle(
                            color: Color(0xFF8B93A7),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedDayData == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No attendance recorded for this day.',
                      style:
                          TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
                    ),
                  )
                else if (firstIn != null) ...[
                  _LogRow(
                    icon: Icons.login_rounded,
                    iconColor: const Color(0xFF1B7F56),
                    iconBackground: const Color(0xFFE7F6EE),
                    title: 'Clock In',
                    time: clockText(firstIn),
                    office: _officeName(widget.api.profile ?? {}),
                    place: 'Inside office (Geofence)',
                    badge: isWorking
                        ? 'Working'
                        : (selectedDayData['isLate'] == true
                            ? 'Late'
                            : 'Present'),
                    badgeColor: const Color(0xFF1B7F56),
                    badgeBackground: const Color(0xFFE7F6EE),
                  ),
                  if (lastOut != null)
                    _LogRow(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFE15B64),
                      iconBackground: const Color(0xFFFDECEC),
                      title: 'Clock Out',
                      time: clockText(lastOut),
                      office: _officeName(widget.api.profile ?? {}),
                      place: 'Inside office (Geofence)',
                      badge: 'Completed',
                      badgeColor: const Color(0xFF6E7C8A),
                      badgeBackground: const Color(0xFFF1F3F6),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Net worked: ${_looseDuration(((selectedDayData['netMinutes'] as num?) ?? 0) * 60)}',
                          style: const TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selectedDayData['isLate'] == true &&
                          ((selectedDayData['lateMinutes'] as num?) ?? 0) >
                              0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF4E8),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: const Color(0xFFEFE2CB)),
                          ),
                          child: Text(
                            '${selectedDayData['lateMinutes']} min late',
                            style: const TextStyle(
                              color: Color(0xFF946522),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: selectedDayData['status'] == 'ABSENT'
                                ? const Color(0xFFFDECEC)
                                : const Color(0xFFF4F6F8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            selectedDayData['status'] == 'ABSENT'
                                ? Icons.cancel_outlined
                                : selectedDayData['status'] == 'HOLIDAY'
                                ? Icons.celebration_outlined
                                : selectedDayData['status'] == 'WEEKEND'
                                ? Icons.weekend_outlined
                                : Icons.beach_access_outlined,
                            size: 18,
                            color: selectedDayData['status'] == 'ABSENT'
                                ? const Color(0xFFE15B64)
                                : const Color(0xFF8B93A7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                switch (selectedDayData['status']
                                    ?.toString()
                                    .toUpperCase()) {
                                  'ABSENT' => 'Marked Absent',
                                  'HOLIDAY' =>
                                    selectedDayData['holiday']
                                            ?.toString() ??
                                        'Holiday',
                                  'WEEKEND' => 'Weekend / Weekly Off',
                                  'ON_LEAVE' || 'HALF_DAY_LEAVE' =>
                                    selectedDayData['leaveType']
                                            ?.toString() ??
                                        'On Leave',
                                  _ => 'No record',
                                },
                                style: const TextStyle(
                                  color: Color(0xFF1B2A4A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                selectedDayData['status'] == 'ABSENT'
                                    ? 'No attendance was recorded'
                                    : _fullDate(currentDay),
                                style: const TextStyle(
                                  color: Color(0xFF8B93A7),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selectedDayData['status'] == 'ABSENT')
                          TextButton(
                            onPressed: () => openDay(currentDay),
                            child: const Text('Regularize'),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Attendance History Logs
          _AttendanceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Net hours',
                              style: TextStyle(
                                color: Color(0xFF7A6E5E),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _looseDuration(totalNetMinutes * 60),
                              style: const TextStyle(
                                color: Color(0xFF1B2A4A),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (averageNetMinutes > 0 || holidays > 0)
                              Text(
                                [
                                  if (averageNetMinutes > 0)
                                    'Avg ${_looseDuration(averageNetMinutes * 60)} / day',
                                  if (holidays > 0)
                                    '$holidays ${holidays == 1 ? 'holiday' : 'holidays'}',
                                ].join('  •  '),
                                style: const TextStyle(
                                  color: Color(0xFF8B7E6F),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _DateFilterButton(
                        current: filter,
                        range: customRange,
                        onSelected: onFilterPicked,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (daysList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No attendance records found for this period.',
                        style: TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  _AttendanceTable(
                    days: daysList,
                    onPick: openDay,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  String _officeName(Json profile) {
    final office = profile['office'];
    if (office is Map && office['name'] != null) {
      return office['name'].toString();
    }
    return 'Office';
  }
}

String _partOfDay(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) return 'Good Morning';
  if (hour >= 12 && hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

String _monthTitle(DateTime date) {
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
  return '${months[date.month - 1]} ${date.year}';
}

String _fullDate(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _weekName(DateTime date) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return days[date.weekday - 1];
}

String _shortDay(DateTime date) {
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

bool _sameDay(DateTime a, DateTime? b) =>
    b != null && a.year == b.year && a.month == b.month && a.day == b.day;

String? _latestOut(List<Json> rows) {
  if (rows.any((row) => row['clock_out'] == null)) return null;
  String? best;
  for (final row in rows) {
    final value = row['clock_out']?.toString();
    if (value == null) continue;
    if (best == null || value.compareTo(best) > 0) best = value;
  }
  return best;
}

String _looseDuration(num seconds) {
  final n = seconds.toInt().clamp(0, 99999999);
  return '${n ~/ 3600}h ${(n % 3600) ~/ 60}m';
}



(String, String)? _timeParts(dynamic value) {
  if (value == null) return null;
  try {
    final d = tz.TZDateTime.from(
      DateTime.parse(value.toString()),
      tz.getLocation(officeTimezone),
    );
    final hour =
        (d.hour % 12 == 0 ? 12 : d.hour % 12).toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return ('$hour:$minute', period);
  } catch (_) {
    return null;
  }
}

class _TimeCell extends StatelessWidget {
  final dynamic iso;
  const _TimeCell({required this.iso});

  @override
  Widget build(BuildContext context) {
    final parts = _timeParts(iso);
    if (parts == null) {
      return const Text(
        '—',
        style: TextStyle(color: Color(0xFF8B7E6F), fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          parts.$1,
          style: const TextStyle(
            color: Color(0xFF1B2A4A),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          parts.$2,
          style: const TextStyle(
            color: Color(0xFF7A6E5E),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TableStatusPill extends StatelessWidget {
  final String status;
  const _TableStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final upper = status.toUpperCase();
    final Color dotColor;
    final Color textColor;
    final Color bgColor;
    final String label;

    switch (upper) {
      case 'PRESENT':
        dotColor = const Color(0xFF1B7F56);
        textColor = const Color(0xFF1B7F56);
        bgColor = const Color(0xFFE7F6EE);
        label = 'Present';
        break;
      case 'WEEKEND':
        dotColor = const Color(0xFF6E5C49);
        textColor = const Color(0xFF6E5C49);
        bgColor = const Color(0xFFF3ECE0);
        label = 'Weekend';
        break;
      case 'ABSENT':
        dotColor = const Color(0xFFE15B64);
        textColor = const Color(0xFFE15B64);
        bgColor = const Color(0xFFFDECEC);
        label = 'Absent';
        break;
      case 'HOLIDAY':
        dotColor = const Color(0xFF7C6BF2);
        textColor = const Color(0xFF7C6BF2);
        bgColor = const Color(0xFFF3F0FF);
        label = 'Holiday';
        break;
      case 'ON_LEAVE':
      case 'HALF_DAY_LEAVE':
        dotColor = const Color(0xFFD97706);
        textColor = const Color(0xFFD97706);
        bgColor = const Color(0xFFFEF3C7);
        label = upper == 'HALF_DAY_LEAVE' ? 'Half Day' : 'Leave';
        break;
      default:
        dotColor = const Color(0xFF8B93A7);
        textColor = const Color(0xFF8B93A7);
        bgColor = const Color(0xFFF4F6F8);
        label = status;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableLateBadge extends StatelessWidget {
  final int minutes;
  const _TableLateBadge({required this.minutes});

  @override
  Widget build(BuildContext context) {
    if (minutes <= 0) {
      return const Text(
        '—',
        style: TextStyle(color: Color(0xFF8B7E6F), fontSize: 13),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7ECDA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEFE2CB)),
      ),
      child: Text(
        '$minutes min',
        style: const TextStyle(
          color: Color(0xFF946522),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TableHeadCell extends StatelessWidget {
  final String text;
  final double width;
  const _TableHeadCell(this.text, this.width);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7A6E5E),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

class _AttendanceTable extends StatelessWidget {
  final List<Json> days;
  final ValueChanged<DateTime> onPick;

  const _AttendanceTable({
    required this.days,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEFE6D8)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                color: const Color(0xFFF6F1E7),
                child: const Row(
                  children: [
                    _TableHeadCell('Date', 100),
                    _TableHeadCell('Status', 105),
                    _TableHeadCell('First in', 80),
                    _TableHeadCell('Last out', 80),
                    _TableHeadCell('Sessions', 70),
                    _TableHeadCell('Net hours', 80),
                    _TableHeadCell('Late', 84),
                    _TableHeadCell('Exceptions', 90),
                  ],
                ),
              ),
              for (int i = 0; i < days.length; i++)
                _TableRowWidget(
                  day: days[i],
                  isLast: i == days.length - 1,
                  onTap: () {
                    final d =
                        DateTime.tryParse(days[i]['date']?.toString() ?? '');
                    if (d != null) onPick(d);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableRowWidget extends StatelessWidget {
  final Json day;
  final bool isLast;
  final VoidCallback onTap;

  const _TableRowWidget({
    required this.day,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = day['status']?.toString().toUpperCase() ?? 'ABSENT';
    final isWeekend = status == 'WEEKEND';
    final dateStr = day['date']?.toString() ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime(1970);
    final firstIn = day['firstInAt']?.toString();
    final lastOut = day['lastOutAt']?.toString();
    final sessions = (day['sessionsCount'] as num?)?.toInt() ?? 0;
    final netMinutes = (day['netMinutes'] as num?)?.toInt() ?? 0;
    final isLate = day['isLate'] == true;
    final lateMinutes = (day['lateMinutes'] as num?)?.toInt() ?? 0;
    final exceptions = (day['exceptions'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    return Material(
      color: isWeekend ? const Color(0xFFFAF6EE) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: Color(0xFFEFE6D8), width: 1),
                  ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${_weekName(date).substring(0, 3)}, ${date.day} ${_shortMonth(date)}',
                    style: const TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 105,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _TableStatusPill(status: status),
                ),
              ),
              SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _TimeCell(iso: firstIn),
                ),
              ),
              SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _TimeCell(iso: lastOut),
                ),
              ),
              SizedBox(
                width: 70,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    sessions > 0 ? '$sessions' : '—',
                    style: TextStyle(
                      color: sessions > 0
                          ? const Color(0xFF1B2A4A)
                          : const Color(0xFF8B7E6F),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    netMinutes > 0
                        ? '${netMinutes ~/ 60}h ${netMinutes % 60}m'
                        : '—',
                    style: TextStyle(
                      color: netMinutes > 0
                          ? const Color(0xFF1B2A4A)
                          : const Color(0xFF8B7E6F),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 84,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: isLate && lateMinutes > 0
                      ? _TableLateBadge(minutes: lateMinutes)
                      : const Text(
                          '—',
                          style: TextStyle(
                            color: Color(0xFF8B7E6F),
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
              SizedBox(
                width: 90,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: exceptions.isNotEmpty
                      ? Text(
                          exceptions.join(', '),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE15B64),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const Text(
                          '—',
                          style: TextStyle(
                            color: Color(0xFF8B7E6F),
                            fontSize: 13,
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
}

class _DateFilterButton extends StatelessWidget {
  final AttendanceFilter current;
  final DateTimeRange? range;
  final ValueChanged<AttendanceFilter> onSelected;
  const _DateFilterButton({
    required this.current,
    this.range,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AttendanceFilter>(
      onSelected: onSelected,
      color: const Color(0xFFFAF7F2),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE8ECEF)),
      ),
      offset: const Offset(0, 42),
      itemBuilder: (context) => [
        _menuItem(AttendanceFilter.thisWeek, 'This week', current),
        _menuItem(AttendanceFilter.thisMonth, 'This month', current),
        _menuItem(AttendanceFilter.last30Days, 'Last 30 days', current),
        const PopupMenuDivider(height: 1),
        _menuItem(AttendanceFilter.lastMonth, 'Last month', current),
        _menuItem(AttendanceFilter.custom, 'Custom range...', current),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF8F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6B5E51), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: Color(0xFF8C7E72),
            ),
            const SizedBox(width: 8),
            Text(
              current == AttendanceFilter.thisMonth
                  ? 'By Date'
                  : filterLabel(current, range),
              style: const TextStyle(
                color: Color(0xFF6E5C49),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF8C7E72),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<AttendanceFilter> _menuItem(
    AttendanceFilter value,
    String label,
    AttendanceFilter active,
  ) {
    final isSelected = value == active;
    return PopupMenuItem<AttendanceFilter>(
      value: value,
      height: 42,
      child: Text(
        label,
        style: TextStyle(
          color:
              isSelected ? const Color(0xFF1B7F56) : const Color(0xFF1B2A4A),
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          fontSize: 13.5,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color background;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.background,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatArrow extends StatelessWidget {
  const _StatArrow();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 2),
    child: Icon(Icons.arrow_forward, size: 12, color: Color(0xFFC5CAD3)),
  );
}

class _AttendanceCard extends StatelessWidget {
  final Widget child;
  const _AttendanceCard({required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x101B2A4A),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: child,
    ),
  );
}

class _WeekLabel extends StatelessWidget {
  final String text;
  const _WeekLabel(this.text);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF8B93A7),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF6E7C8A), fontSize: 11),
      ),
    ],
  );
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final String Function(DateTime day) markFor;
  final ValueChanged<DateTime> onPick;
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.markFor,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7;
    final cells = lead + count;
    final rows = (cells / 7).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _cell(row * 7 + col, lead, count)),
            ],
          ),
      ],
    );
  }

  Widget _cell(int index, int lead, int count) {
    final dayNumber = index - lead + 1;
    if (dayNumber < 1 || dayNumber > count) return const SizedBox(height: 46);
    final day = DateTime(month.year, month.month, dayNumber);
    final picked = _sameDay(day, selected);
    final mark = markFor(day);
    final dot = switch (mark) {
      'present' => const Color(0xFF1B7F56),
      'absent' => const Color(0xFFE15B64),
      'late' => const Color(0xFF3B82F6),
      'holiday' => const Color(0xFFC5CAD3),
      'leave' => const Color(0xFFF59E0B),
      _ => null,
    };
    return InkWell(
      onTap: () => onPick(day),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: picked
                  ? const BoxDecoration(
                      color: Color(0xFF1B2744),
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  color: picked ? Colors.white : const Color(0xFF1B2A4A),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: dot ?? Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String time;
  final String office;
  final String place;
  final String badge;
  final Color badgeColor;
  final Color badgeBackground;
  const _LogRow({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.time,
    required this.office,
    required this.place,
    required this.badge,
    required this.badgeColor,
    required this.badgeBackground,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1B2A4A),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                time,
                style: const TextStyle(color: Color(0xFF6E7C8A), fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Color(0xFF8B93A7),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      office,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DaySheet extends StatelessWidget {
  final Api api;
  final DateTime day;
  final Json? dayData;
  final String mark;
  final Json? office;
  const _DaySheet({
    required this.api,
    required this.day,
    this.dayData,
    required this.mark,
    this.office,
  });

  @override
  Widget build(BuildContext context) {
    final statusType =
        dayData?['status']?.toString().toUpperCase() ?? mark.toUpperCase();
    final isLate = dayData?['isLate'] == true || mark == 'late';
    final lateMinutes = ((dayData?['lateMinutes'] as num?) ?? 0).toInt();
    final firstIn = dayData?['firstInAt']?.toString();
    final lastOut = dayData?['lastOutAt']?.toString();
    final netMinutes =
        ((dayData?['netMinutes'] as num?) ?? 0).toInt();
    final grossMinutes =
        ((dayData?['grossMinutes'] as num?) ?? netMinutes).toInt();
    final breakMinutes = ((dayData?['breakMinutes'] as num?) ?? 0).toInt();
    final overtimeMinutes =
        ((dayData?['overtimeMinutes'] as num?) ?? 0).toInt();
    final exceptions = (dayData?['exceptions'] as List?) ?? const [];
    final sessionsCount = dayData?['sessionsCount'] ?? 1;
    final completedSessions =
        dayData?['completedSessions'] ?? (lastOut != null ? 1 : 0);

    final status = switch (statusType) {
      'PRESENT' => isLate
          ? (
              'Late Arrival',
              lateMinutes > 0
                  ? 'Arrived $lateMinutes min after scheduled start time'
                  : 'You arrived late at the office',
              const Color(0xFFEAF1FF),
              const Color(0xFF3B82F6),
            )
          : (
              'Present',
              (dayData?['hasOpenSession'] == true ||
                      (firstIn != null && lastOut == null))
                  ? 'You are currently at the office'
                  : 'You were present at the office',
              const Color(0xFFE7F6EE),
              const Color(0xFF1B7F56),
            ),
      'ABSENT' => (
          'Absent',
          'No attendance recorded for this day',
          const Color(0xFFFDECEC),
          const Color(0xFFE15B64),
        ),
      'HOLIDAY' => (
          'Holiday',
          dayData?['holiday']?.toString() ?? 'The office was closed',
          const Color(0xFFF4F6F8),
          const Color(0xFF6E7C8A),
        ),
      'WEEKEND' => (
          'Weekend',
          'Weekly off',
          const Color(0xFFF4F6F8),
          const Color(0xFF8B93A7),
        ),
      'ON_LEAVE' || 'HALF_DAY_LEAVE' => (
          'On Leave',
          dayData?['leaveType']?.toString() ?? 'Approved leave',
          const Color(0xFFFEF3C7),
          const Color(0xFFD97706),
        ),
      _ => (
          'No record',
          'Nothing is recorded for this day',
          const Color(0xFFF4F6F8),
          const Color(0xFF8B93A7),
        ),
    };

    final officeName = office?['name']?.toString() ?? 'Office';

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B2744),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day.day.toString().padLeft(2, '0')}\n${_shortMonth(day)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekName(day),
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      _fullDate(day),
                      style: const TextStyle(color: Color(0xFF8B93A7)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: status.$3,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: status.$4,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.$1,
                          style: TextStyle(
                            color: status.$4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          status.$2,
                          style: const TextStyle(
                            color: Color(0xFF6E7C8A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (firstIn != null) ...[
            const SizedBox(height: 12),
            _SheetEvent(
              color: const Color(0xFF1B7F56),
              title: 'Clock In',
              time: clockText(firstIn),
              office: officeName,
              place: 'Inside office (Geofence)',
            ),
            if (lastOut != null)
              _SheetEvent(
                color: const Color(0xFFE15B64),
                title: 'Clock Out',
                time: clockText(lastOut),
                office: officeName,
                place: 'Inside office (Geofence)',
              ),
          ],
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  _SheetStat(
                    icon: Icons.schedule_outlined,
                    label: 'Gross Hours',
                    value: _looseDuration(grossMinutes * 60),
                  ),
                  _SheetStat(
                    icon: Icons.coffee_outlined,
                    label: 'Break Time',
                    value: '${breakMinutes}m',
                  ),
                  _SheetStat(
                    icon: Icons.bolt_outlined,
                    label: 'Working Hours',
                    value: _looseDuration(netMinutes * 60),
                  ),
                ],
              ),
            ),
          ),
          if (dayData != null) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session & Audit Info',
                      style: TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Completed Sessions',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$completedSessions / $sessionsCount',
                          style: const TextStyle(
                            color: Color(0xFF1B2A4A),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (overtimeMinutes > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Overtime',
                            style: TextStyle(
                              color: Color(0xFF8B93A7),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$overtimeMinutes min',
                            style: const TextStyle(
                              color: Color(0xFF1B7F56),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (exceptions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Exceptions',
                            style: TextStyle(
                              color: Color(0xFF8B93A7),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            exceptions
                                .join(', ')
                                .replaceAll('_', ' '),
                            style: const TextStyle(
                              color: Color(0xFFE15B64),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.edit_calendar_outlined, size: 16),
              onPressed: () {
                final navigator = Navigator.of(context);
                final record = dayData;
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => CorrectionPage(
                      api: api,
                      record: record,
                      day: day,
                    ),
                  ),
                );
              },
              label: const Text('Request a correction'),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortMonth(DateTime date) {
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
  return months[date.month - 1];
}

class _SheetEvent extends StatelessWidget {
  final Color color;
  final String title;
  final String time;
  final String office;
  final String place;
  const _SheetEvent({
    required this.color,
    required this.title,
    required this.time,
    required this.office,
    required this.place,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.logout_rounded, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
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
              Text(time, style: const TextStyle(color: Color(0xFF6E7C8A))),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                office,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2A4A),
                ),
              ),
              Text(
                place,
                style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SheetStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SheetStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 16, color: Color(0xFF8B93A7)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1B2A4A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class AttendanceDetail extends StatelessWidget {
  final Api api;
  final Json record;
  const AttendanceDetail({super.key, required this.api, required this.record});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Attendance details')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        heading(shortDate(record['day'])),
        Panel(
          color: ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total working hours',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Text(
                durationText(record['seconds']),
                style: const TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              StatusBadge(record['status']),
            ],
          ),
        ),
        Panel(
          child: Column(
            children: [
              detail('Clock in', clockText(record['clock_in'])),
              detail('Clock out', clockText(record['clock_out'])),
              detail(
                'Office',
                api.profile?['office']['name'] ?? record['office_id'],
              ),
              detail('Record revision', '${record['revision']}'),
              detail(
                'Clock-in GPS',
                '${record['in_lat']}, ${record['in_lon']}',
              ),
              if (record['out_lat'] != null)
                detail(
                  'Clock-out GPS',
                  '${record['out_lat']}, ${record['out_lon']}',
                ),
            ],
          ),
        ),
        notice(
          'Manager-approved corrections retain the original GPS evidence and an audit timeline. Times are shown in your assigned office timezone.',
        ),
        ActionButton(
          'Request a correction',
          icon: Icons.edit_calendar_outlined,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CorrectionPage(api: api, record: record),
              ),
            );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

class CorrectionPage extends StatefulWidget {
  final Api api;
  final Json? record;
  final DateTime? day;
  const CorrectionPage({super.key, required this.api, this.record, this.day});
  @override
  State<CorrectionPage> createState() => _CorrectionPageState();
}

class _CorrectionPageState extends State<CorrectionPage> {
  late DateTime day;
  late TimeOfDay checkIn, checkOut;
  final reason = TextEditingController();
  String regularize = 'Present';
  List<Json> punches = const [];
  bool busy = false;
  bool loadingDay = true;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final recorded = record == null
        ? null
        : DateTime.tryParse(
            (record['day'] ?? record['date'])?.toString() ?? '',
          );
    day = recorded ?? widget.day ?? DateTime.now();
    final clockIn = record == null
        ? null
        : DateTime.tryParse(
            (record['clock_in'] ?? record['firstInAt'])?.toString() ?? '',
          )?.toLocal();
    final clockOut = record == null
        ? null
        : DateTime.tryParse(
            (record['clock_out'] ?? record['lastOutAt'])?.toString() ?? '',
          )?.toLocal();
    checkIn = clockIn == null
        ? const TimeOfDay(hour: 9, minute: 15)
        : TimeOfDay.fromDateTime(clockIn);
    checkOut = clockOut == null
        ? const TimeOfDay(hour: 18, minute: 30)
        : TimeOfDay.fromDateTime(clockOut);
    loadDay();
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  Future<void> loadDay() async {
    setState(() => loadingDay = true);
    try {
      final data = await widget.api.get(
        '/attendance/me',
        query: {'from': dateOnly(day), 'to': dateOnly(day)},
      );
      final rows = items(
        data,
      ).where((row) => row['day'] == dateOnly(day)).toList();
      if (mounted) setState(() => punches = rows);
    } catch (_) {
      if (mounted) setState(() => punches = const []);
    } finally {
      if (mounted) setState(() => loadingDay = false);
    }
  }

  Future<void> pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => day = DateTime(picked.year, picked.month, picked.day));
    await loadDay();
  }

  Future<void> pickTime(bool inbound) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: inbound ? checkIn : checkOut,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (inbound) {
        checkIn = picked;
      } else {
        checkOut = picked;
      }
    });
  }

  void showPunches() {
    final logs = punches.isEmpty ? [const <String, dynamic>{}] : punches;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF4F7F8),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            const Text(
              'Punch logs',
              style: TextStyle(
                color: Color(0xFF1B2A4A),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              shortDate(dateOnly(day)),
              style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < logs.length; i++) ...[
              if (logs.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Session ${i + 1}',
                    style: const TextStyle(
                      color: Color(0xFF6E7C8A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              _punchRow(
                Icons.login_rounded,
                const Color(0xFFE7F6EE),
                primary,
                'Check-in',
                clockText(logs[i]['clock_in']),
              ),
              const SizedBox(height: 8),
              _punchRow(
                Icons.logout_rounded,
                const Color(0xFFFDECEC),
                const Color(0xFFE15B64),
                'Check-out',
                clockText(logs[i]['clock_out']),
              ),
              if (i < logs.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> submit() async {
    if (widget.api.live) {
      await comingSoon(
        context,
        'Attendance request',
        'Regularizing attendance is on hold for now.',
      );
      return;
    }
    if (reason.text.trim().isEmpty) {
      message(context, 'Please add a reason.');
      return;
    }
    final start = _at(checkIn);
    final end = _at(checkOut);
    if (!end.isAfter(start)) {
      message(context, 'Check-out must be after check-in.');
      return;
    }
    setState(() => busy = true);
    try {
      final recordId =
          widget.record?['id'] ??
          (punches.isEmpty ? null : punches.first['id']);
      final created = await widget.api.mutate('/regularisations', {
        if (recordId != null) 'attendance_id': recordId,
        'day': dateOnly(day),
        'proposed_in': start.toUtc().toIso8601String(),
        'proposed_out': end.toUtc().toIso8601String(),
        'regularize_as': regularize == 'Home' ? 'Work from home' : 'Present',
        'reason': reason.text.trim(),
      });
      if (mounted) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RequestDetails(
              api: widget.api,
              id: created['id'],
              review: false,
            ),
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
  Widget build(BuildContext context) {
    final profile = widget.api.profile ?? {};
    final name = profile['name']?.toString() ?? '';
    final absent = punches.isEmpty;
    final statusLabel = absent ? 'Absent' : 'Present';
    final statusBg = absent ? const Color(0xFFFDECEC) : const Color(0xFFE7F6EE);
    final statusFg = absent ? const Color(0xFFE15B64) : primary;
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Regularize Attendance',
                          style: TextStyle(
                            color: Color(0xFF1B2A4A),
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Request to regularize your missed or incorrect attendance.',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const _RegularizeArt(),
              ],
            ),
            const SizedBox(height: 16),
            _formCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFE4DFF8),
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Color(0xFF6B5BD6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${profile['designation'] ?? 'Team member'}  ·  ${profile['id'] ?? ''}',
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            _formCard(
              child: InkWell(
                onTap: pickDay,
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color(0xFF6E7C8A),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Date',
                        style: TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${shortDate(dateOnly(day))}, ${weekdays[day.weekday - 1]}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFC5CAD3)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Current status',
              style: TextStyle(
                color: Color(0xFF1B2A4A),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            _formCard(
              child: loadingDay
                  ? const LinearProgressIndicator(minHeight: 2)
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                absent ? Icons.cancel : Icons.check_circle,
                                size: 16,
                                color: statusFg,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusFg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: showPunches,
                          child: const Row(
                            children: [
                              Text(
                                'View punch logs',
                                style: TextStyle(
                                  color: Color(0xFF1B7F56),
                                  fontWeight: FontWeight.w500,
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
            ),
            const SizedBox(height: 16),
            const Text(
              'Regularize as',
              style: TextStyle(
                color: Color(0xFF1B2A4A),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _choice(
                    'Present',
                    Icons.schedule,
                    regularize == 'Present',
                    () => setState(() => regularize = 'Present'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _choice(
                    'Work From Home',
                    Icons.home_outlined,
                    regularize == 'Home',
                    () => setState(() => regularize = 'Home'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _timeBox(
                    'Check-in time',
                    _clockLabel(checkIn),
                    () => pickTime(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _timeBox(
                    'Check-out time',
                    _clockLabel(checkOut),
                    () => pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Reason',
              style: TextStyle(
                color: Color(0xFF1B2A4A),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reason,
              maxLines: 4,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText:
                    'Enter reason for regularization\ne.g., Forgot to punch, System issue, Official work etc.',
                hintStyle: const TextStyle(
                  color: Color(0xFFB0B7C3),
                  fontSize: 13,
                  height: 1.4,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(
                    Icons.description_outlined,
                    color: Color(0xFFC5CAD3),
                  ),
                ),
                counterText: '${reason.text.length}/500',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: busy ? null : submit,
              child: Text(
                busy ? 'Sending' : 'Submit request',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) => Material(
    color: selected ? const Color(0xFFE7F6EE) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? primary : const Color(0xFFE8EDF2),
        width: selected ? 1.4 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? primary : const Color(0xFF8B93A7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                style: TextStyle(
                  color: selected ? primary : const Color(0xFF1B2A4A),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: selected ? primary : const Color(0xFFD0D5DD),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _timeBox(String label, String value, VoidCallback onTap) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFE8EDF2)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 16, color: Color(0xFF8B93A7)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC5CAD3)),
          ],
        ),
      ),
    ),
  );
}

Widget _punchRow(
  IconData icon,
  Color background,
  Color foreground,
  String label,
  String value,
) => Material(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: foreground, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6E7C8A), fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1B2A4A),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    ),
  ),
);

Widget _formCard({required Widget child}) => Material(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  child: Padding(padding: const EdgeInsets.all(14), child: child),
);

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length < 2 ? 1 : 2).toUpperCase();
  }
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}

String _clockLabel(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '${hour.toString().padLeft(2, '0')}:$minute $suffix';
}

class _RegularizeArt extends StatelessWidget {
  const _RegularizeArt();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 72,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: 8,
          top: 0,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_month, color: Color(0xFF1B7F56)),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF1B7F56),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.schedule, color: Colors.white, size: 16),
          ),
        ),
      ],
    ),
  );
}

class RegularizeListPage extends StatefulWidget {
  final Api api;
  const RegularizeListPage({super.key, required this.api});
  @override
  State<RegularizeListPage> createState() => _RegularizeListPageState();
}

class _DayIssue {
  final DateTime day;
  final String title, detail, chip, kind;
  final Color chipBg, chipFg;
  final Json? record;
  const _DayIssue({
    required this.day,
    required this.title,
    required this.detail,
    required this.chip,
    required this.kind,
    required this.chipBg,
    required this.chipFg,
    this.record,
  });
}

class _RegularizeListPageState extends State<RegularizeListPage> {
  int tab = 0;
  bool loading = true, busy = false;
  Object? error;
  DateTime? officeDay;
  List<_DayIssue> issues = const [];
  List<Json> history = const [];
  final selected = <String>{};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final home = await widget.api.get('/attendance/status');
      final today = DateTime.parse(home['today'].toString());
      final day = DateTime(today.year, today.month, today.day);
      final start = DateTime(day.year, day.month, 1);
      final attendance = await widget.api.get(
        '/attendance/me',
        query: {'from': dateOnly(start), 'to': dateOnly(day)},
      );
      final requests = await widget.api.get(
        '/regularisations',
        query: {'mine': 'true'},
      );
      final punches = <String, List<Json>>{};
      for (final row in items(attendance)) {
        final key = _punchDay(row);
        if (key.isEmpty) continue;
        punches.putIfAbsent(key, () => []).add(row);
      }
      final rows = items(requests);
      final month = dateOnly(start).substring(0, 7);
      final past = rows.where((row) {
        if (row['kind'] != 'Attendance') return false;
        return row['start'].toString().startsWith(month);
      }).toList();

      final found = <_DayIssue>[];
      final keys = punches.keys.toList()..sort();
      for (final key in keys) {
        final issue = _issueFor(
          DateTime.parse(key),
          punches[key] ?? const <Json>[],
        );
        if (issue != null) found.add(issue);
      }
      if (!mounted) return;
      setState(() {
        officeDay = day;
        issues = found;
        history = past;
        selected.removeWhere(
          (key) => !found.any((issue) => dateOnly(issue.day) == key),
        );
        loading = false;
        error = null;
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

  String _punchDay(Json row) {
    final clock = row['clock_in']?.toString();
    if (clock != null && clock.isNotEmpty) {
      final zoned = tz.TZDateTime.from(
        DateTime.parse(clock),
        tz.getLocation(officeTimezone),
      );
      return dateOnly(zoned);
    }
    return row['day']?.toString() ?? '';
  }

  _DayIssue? _issueFor(DateTime day, List<Json> logs) {
    const missedBg = Color(0xFFFDECEC);
    const missedFg = Color(0xFFE15B64);
    if (logs.isEmpty) return null;
    Json? row;
    for (final item in logs) {
      row ??= item;
      if (item['clock_in'] != null) row = item;
    }
    final inbound = row?['clock_in'];
    final outbound = _latestOut(logs);
    final span = outbound == null
        ? '${clockText(inbound)} – Not recorded'
        : '${clockText(inbound)} – ${clockText(outbound)}';
    if (inbound == null) {
      return _DayIssue(
        day: day,
        title: 'Forgot to check-in',
        detail: span,
        chip: 'Missed',
        kind: 'missed',
        chipBg: missedBg,
        chipFg: missedFg,
        record: row,
      );
    }
    if (outbound == null) {
      return _DayIssue(
        day: day,
        title: 'Forgot to check-out',
        detail: span,
        chip: 'Missed',
        kind: 'open',
        chipBg: missedBg,
        chipFg: missedFg,
        record: row,
      );
    }
    final left = tz.TZDateTime.from(
      DateTime.parse(outbound),
      tz.getLocation(officeTimezone),
    );
    if (left.hour < 18) {
      return _DayIssue(
        day: day,
        title: 'Check-out early',
        detail: span,
        chip: 'Early Leave',
        kind: 'early',
        chipBg: const Color(0xFFFFF3E0),
        chipFg: const Color(0xFFE09A3D),
        record: row,
      );
    }
    final status = (row?['status'] ?? '').toString().toLowerCase();
    if (status.contains('late')) {
      return _DayIssue(
        day: day,
        title: 'Check-in late',
        detail: span,
        chip: 'Late',
        kind: 'late',
        chipBg: const Color(0xFFFFF6E0),
        chipFg: const Color(0xFFC4840A),
        record: row,
      );
    }
    return _DayIssue(
      day: day,
      title: 'Checked in',
      detail: span,
      chip: 'Present',
      kind: 'present',
      chipBg: const Color(0xFFE7F6EE),
      chipFg: primary,
      record: row,
    );
  }

  Future<void> openOne(_DayIssue issue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CorrectionPage(
          api: widget.api,
          record: issue.record,
          day: issue.day,
        ),
      ),
    );
    if (mounted) load();
  }

  DateTime _at(DateTime day, int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  DateTime _fromClock(DateTime day, dynamic value, int hour, int minute) {
    if (value == null) return _at(day, hour, minute);
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return _at(day, hour, minute);
    final local = tz.TZDateTime.from(parsed, tz.getLocation(officeTimezone));
    return _at(day, local.hour, local.minute);
  }

  Future<void> continueSelected() async {
    if (widget.api.live) {
      await comingSoon(
        context,
        'Attendance request',
        'Regularizing attendance is on hold for now.',
      );
      return;
    }
    final chosen = issues
        .where((issue) => selected.contains(dateOnly(issue.day)))
        .toList();
    if (chosen.isEmpty || busy) return;
    if (chosen.length == 1) {
      await openOne(chosen.first);
      return;
    }
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => _BatchReason(count: chosen.length),
    );
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      for (final issue in chosen) {
        final inbound = _fromClock(issue.day, issue.record?['clock_in'], 9, 15);
        final outbound = issue.kind == 'late' || issue.kind == 'present'
            ? _fromClock(issue.day, issue.record?['clock_out'], 18, 30)
            : _at(issue.day, 18, 30);
        final recordId = issue.record?['id'];
        await widget.api.mutate('/regularisations', {
          if (recordId != null) 'attendance_id': recordId,
          'day': dateOnly(issue.day),
          'proposed_in': inbound.toUtc().toIso8601String(),
          'proposed_out': outbound.toUtc().toIso8601String(),
          'regularize_as': 'Present',
          'reason': reason,
        });
      }
      if (!mounted) return;
      message(context, '${chosen.length} requests sent to your manager.');
      selected.clear();
      await load();
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sticker = issues.isNotEmpty
        ? issues.first.day
        : (officeDay ?? DateTime.now());
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F8),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: ink),
                  ),
                  const Expanded(
                    child: Text(
                      'Regularize Attendance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? FailureView(error!, load)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        _regularizeBanner(sticker),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            _filter(
                              'Needs Action',
                              0,
                              issues
                                  .where((issue) => issue.kind != 'present')
                                  .length,
                            ),
                            _filter('History', 1, null),
                            _filter('Guidelines', 2, null),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (tab == 0) ..._needs(),
                        if (tab == 1) ..._past(),
                        if (tab == 2) ..._guide(),
                      ],
                    ),
            ),
            if (!loading && error == null && tab == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    disabledBackgroundColor: const Color(0xFFB7D7C8),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: selected.isEmpty || busy ? null : continueSelected,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue (${selected.length} selected)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _needs() {
    if (issues.isEmpty) {
      return const [
        EmptyView(
          'No check-ins this month',
          'Days you check in this month show here with the recorded clock-in and clock-out.',
        ),
      ];
    }
    return [
      for (final issue in issues)
        _LogCard(
          day: issue.day,
          title: issue.title,
          detail: issue.detail,
          chip: issue.chip,
          chipBg: issue.chipBg,
          chipFg: issue.chipFg,
          checked: selected.contains(dateOnly(issue.day)),
          onTap: () {
            final key = dateOnly(issue.day);
            setState(() {
              if (!selected.add(key)) selected.remove(key);
            });
          },
          onOpen: () => openOne(issue),
        ),
    ];
  }

  List<Widget> _past() {
    if (history.isEmpty) {
      return const [
        EmptyView(
          'No history this month',
          'Requests you send from Needs Action appear here with their status.',
        ),
      ];
    }
    return [
      for (final row in history)
        _LogCard(
          day: DateTime.parse(row['start'].toString()),
          title: row['type_name']?.toString() ?? 'Attendance',
          detail: row['proposed_in'] == null
              ? (row['reason']?.toString() ?? '')
              : '${clockText(row['proposed_in'])} – ${clockText(row['proposed_out'])}',
          chip: row['status']?.toString() ?? '',
          chipBg: _statusBg(row['status']?.toString()),
          chipFg: _statusFg(row['status']?.toString()),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RequestDetails(
                  api: widget.api,
                  id: row['id'].toString(),
                  review: false,
                ),
              ),
            );
            if (mounted) load();
          },
        ),
    ];
  }

  List<Widget> _guide() => const [
    _GuideCard(
      icon: Icons.login_rounded,
      color: Color(0xFFE15B64),
      background: Color(0xFFFDECEC),
      title: 'Missed punches',
      body:
          'Select a day with no check-in or check-out, then continue. Add the real times and a reason for your manager.',
    ),
    _GuideCard(
      icon: Icons.schedule,
      color: Color(0xFFE09A3D),
      background: Color(0xFFFFF3E0),
      title: 'Early leave',
      body:
          'A check-out before 6:00 PM is listed when the punch looks short. Correct the time if you stayed longer.',
    ),
    _GuideCard(
      icon: Icons.home_outlined,
      color: Color(0xFF7C6BF2),
      background: Color(0xFFF3F0FF),
      title: 'Work from home',
      body:
          'On the request, choose Work from home when you worked away from the office that day.',
    ),
    _GuideCard(
      icon: Icons.fact_check_outlined,
      color: primary,
      background: Color(0xFFE7F6EE),
      title: 'This month only',
      body:
          'This list is the current month. Each selected day is its own request. Approved days leave Needs Action and show in History.',
    ),
  ];

  Widget _filter(String label, int index, int? count) {
    final on = tab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: InkWell(
        onTap: () => setState(() => tab = index),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: on ? ink : const Color(0xFF8B93A7),
                    fontSize: 14,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (count != null && count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE85D4C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: on ? 36 : 0,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _regularizeBanner(DateTime day) => Stack(
  clipBehavior: Clip.none,
  children: [
    Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 128, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4EEF8), Color(0xFFE9F0F8), Color(0xFFF8F1EA)],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Have a missed or\nincorrect\nattendance?',
            style: TextStyle(
              color: ink,
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Raise a regularization request and keep your records accurate.',
            style: TextStyle(
              color: Color(0xFF8B93A7),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    ),
    const Positioned(right: 8, top: 10, child: _BannerScene()),
    Positioned(right: 6, bottom: -16, child: _DateSticker(day)),
  ],
);

class _DateSticker extends StatelessWidget {
  final DateTime day;
  const _DateSticker(this.day);
  @override
  Widget build(BuildContext context) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Transform.rotate(
      angle: 0.06,
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3D2C4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22E7A07A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              months[day.month - 1],
              style: const TextStyle(
                color: Color(0xFFE07A5F),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${day.day}',
              style: const TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            Text(
              days[day.weekday - 1],
              style: const TextStyle(
                color: Color(0xFF8B93A7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerScene extends StatelessWidget {
  const _BannerScene();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 118,
    height: 112,
    child: Stack(
      children: [
        Positioned(
          right: 0,
          bottom: 6,
          child: Icon(Icons.spa, color: Color(0xFF3E8F62), size: 34),
        ),
        Positioned(
          left: 8,
          top: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: 72,
              height: 80,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [_Ring(), _Ring(), _Ring(), _Ring()],
                    ),
                    SizedBox(height: 8),
                    _Grid(),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 56,
          top: 58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF2E3A59),
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Colors.white, width: 3),
              ),
            ),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.schedule, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Ring extends StatelessWidget {
  const _Ring();
  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 8,
    decoration: BoxDecoration(
      color: const Color(0xFFD7DCE6),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class _Grid extends StatelessWidget {
  const _Grid();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var row = 0; row < 3; row++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var column = 0; column < 4; column++)
                Container(
                  width: 8,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EBF2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class _LogCard extends StatelessWidget {
  final DateTime day;
  final String title, detail, chip;
  final Color chipBg, chipFg;
  final bool? checked;
  final VoidCallback onTap;
  final VoidCallback? onOpen;
  const _LogCard({
    required this.day,
    required this.title,
    required this.detail,
    required this.chip,
    required this.chipBg,
    required this.chipFg,
    required this.onTap,
    this.checked,
    this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final on = checked == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: on ? const Color(0xFFE8A58A) : const Color(0xFFE6EAF0),
                width: on ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                if (checked != null) ...[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: on ? primary : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: on ? primary : const Color(0xFFD5DBE3),
                        width: 1.4,
                      ),
                    ),
                    child: on
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        months[day.month - 1],
                        style: const TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      Text(
                        days[day.weekday - 1],
                        style: const TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
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
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      color: chipFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onOpen ?? onTap,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFB0B7C3),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final Color color, background;
  final String title, body;
  const _GuideCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.body,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: background,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Color(0xFF6E7C8A),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BatchReason extends StatefulWidget {
  final int count;
  const _BatchReason({required this.count});
  @override
  State<_BatchReason> createState() => _BatchReasonState();
}

class _BatchReasonState extends State<_BatchReason> {
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Regularize ${widget.count} days',
          style: const TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Each day is sent as its own request. Missing times are filled as 09:15 AM – 06:30 PM.',
          style: TextStyle(
            color: Color(0xFF8B93A7),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: reason,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason for these days',
            filled: true,
            fillColor: Color(0xFFF4F7F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () {
            final text = reason.text.trim();
            if (text.isEmpty) {
              message(context, 'Please add a reason.');
              return;
            }
            Navigator.pop(context, text);
          },
          child: const Text('Submit requests'),
        ),
      ],
    ),
  );
}

Color _statusBg(String? status) {
  switch (status) {
    case 'Approved':
      return const Color(0xFFE7F6EE);
    case 'Rejected':
      return const Color(0xFFFDECEC);
    default:
      return const Color(0xFFFFF6E0);
  }
}

Color _statusFg(String? status) {
  switch (status) {
    case 'Approved':
      return primary;
    case 'Rejected':
      return const Color(0xFFE15B64);
    default:
      return const Color(0xFFC4840A);
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F6EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1B7F56), size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    ),
  );
}
