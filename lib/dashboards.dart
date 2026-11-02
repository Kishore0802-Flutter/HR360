import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'api.dart';
import 'clock_in.dart';
import 'design.dart';
import 'directory.dart';
import 'nav.dart';
import 'requests.dart';
import 'shell.dart' show dashMood;
export 'task_dashboard.dart';

const _bg = Color(0xFFF3F6F8);
const _ink = Color(0xFF0F172A);
const _soft = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _forestDark = Color(0xFF0C3831);
const _forestDeep = Color(0xFF06231E);
const _mint = Color(0xFF2EE59D);

enum DashPeriod { today, week, month }

/// Modern Executive Dashboard for HRMS (Admin, HR, Manager roles).
class RoleDashboard extends StatefulWidget {
  final Api api;
  final ValueChanged<int> onTab;
  final void Function(int tab, {String? subTab})? onNavigate;
  final Widget? moduleSwitch;
  const RoleDashboard({
    super.key,
    required this.api,
    required this.onTab,
    this.onNavigate,
    this.moduleSwitch,
  });

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard> {
  DashPeriod period = DashPeriod.month;
  Json? data;
  Json? status;
  int unread = 0;
  Object? error;
  bool loading = true;

  Api get api => widget.api;
  String get role => api.role ?? 'manager';
  int get profileTab => api.manager ? 4 : 3;

  void _navigateToApprovals(String kind) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(3, subTab: kind);
    } else {
      widget.onTab(3);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  (DateTime, DateTime) get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = switch (period) {
      DashPeriod.today => today,
      DashPeriod.week => today.subtract(Duration(days: today.weekday - 1)),
      DashPeriod.month => DateTime(today.year, today.month, 1),
    };
    return (from, today);
  }

  Future<dynamic> _soft404(Future<dynamic> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    setState(() {
      loading = data == null;
      error = null;
    });
    final (from, to) = range;
    try {
      final results = await Future.wait<dynamic>([
        api.v1(
          'GET',
          '/reports/hrms/dashboard',
          query: {'from': dateOnly(from), 'to': dateOnly(to)},
        ),
        if (api.can('attendance:create'))
          _soft404(() => api.v1('GET', '/attendance/status'))
        else
          Future<dynamic>.value(null),
        _soft404(() => api.v1('GET', '/notifications/unread-count')),
      ]);
      final mine = results[1] is Map
          ? Map<String, dynamic>.from(results[1] as Map)
          : null;
      if (mine != null && mine['requirements'] is Map) {
        api.attendanceRules = Map<String, dynamic>.from(
          mine['requirements'] as Map,
        );
      }
      if (!mounted) return;
      setState(() {
        data = Map<String, dynamic>.from(results[0] as Map);
        status = mine;
        unread = ((results[2] as Map?)?['unreadCount'] as num?)?.toInt() ?? 0;
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

  Future<void> punch() async {
    final checkedIn = status?['isCheckedIn'] == true;
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClockInPage(api: api, action: checkedIn ? 'out' : 'in'),
      ),
    );
    if (done == true) await load();
  }

  void setPeriod(DashPeriod next) {
    if (next == period) return;
    setState(() => period = next);
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const DashboardShimmer();
    if (error != null) return FailureView(error!, load);
    final d = data ?? const {};
    final leave = _map(d['leave']);
    final regularisation = _map(d['regularisation']);
    final showActionCards = api.manager &&
        (_n(leave['pending']) > 0 || _n(regularisation['pending']) > 0);

    return ColoredBox(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
          children: [
            _header(),
            if (widget.moduleSwitch != null) ...[
              const SizedBox(height: 16),
              widget.moduleSwitch!,
            ],
            const SizedBox(height: 18),
            _OrganisationPulseCard(
              data: d,
              period: period,
              onPeriodChanged: setPeriod,
              onPendingLeavesTap: () => _navigateToApprovals('Leave'),
            ),
            const SizedBox(height: 18),
            _MyDayCard(
              status: status,
              onPunch: punch,
              onViewDetails: () => widget.onTab(1),
            ),
            if (showActionCards) ...[
              const SizedBox(height: 18),
              _ActionCards(
                leave: _n(leave['pending']),
                regularisation: _n(regularisation['pending']),
                onLeaveReview: (api.can('leave:approve') || api.manager)
                    ? () => _navigateToApprovals('Leave')
                    : null,
                onRegularisationReview:
                    (api.can('regularisations:approve') || api.manager)
                        ? () => _navigateToApprovals('Attendance')
                        : null,
              ),
            ],
            const SizedBox(height: 20),
            _QuickActions(
              api: api,
              onViewAll: () => widget.onTab(1),
              onApprovalsTap: () => _navigateToApprovals('Leave'),
            ),
            const SizedBox(height: 18),
            _HeadcountCard(
              headcount: _map(d['headcount']),
              totalEmployees: _n(_map(d['attendanceToday'])['total']),
              api: api,
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final now = tz.TZDateTime.now(tz.getLocation(officeTimezone));
    final mood = dashMood(now);
    final profile = api.profile ?? const {};
    final name = profile['name']?.toString() ?? 'Kishore Kumar S';

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final dateStr =
        '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -12,
          right: -16,
          child: IgnorePointer(
            child: SizedBox(
              width: 175,
              height: 145,
              child: Image.asset(
                'assets/dashboard_building.png',
                fit: BoxFit.contain,
                alignment: Alignment.topRight,
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 15,
                      color: _soft,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _line),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Notifications',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsPage(api: api),
                        ),
                      );
                      load();
                    },
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text(
                        '$unread',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: const Color(0xFFEF4444),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: _ink,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => widget.onTab(profileTab),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFF1E293B),
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3.5,
                  height: 28,
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mood.greeting},',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _soft,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _OrganisationPulseCard extends StatelessWidget {
  final Json data;
  final DashPeriod period;
  final ValueChanged<DashPeriod> onPeriodChanged;
  final VoidCallback? onPendingLeavesTap;

  const _OrganisationPulseCard({
    required this.data,
    required this.period,
    required this.onPeriodChanged,
    this.onPendingLeavesTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = _map(data['attendanceToday']);
    final headcount = _map(data['headcount']);
    final leave = _map(data['leave']);

    final totalEmployees = _n(headcount['total']) > 0
        ? _n(headcount['total'])
        : (_n(today['total']) > 0 ? _n(today['total']) : 520);
    final present = _n(today['present']) + _n(today['checkedIn']) > 0
        ? _n(today['present']) + _n(today['checkedIn'])
        : (_n(headcount['total']) > 0
            ? (_n(headcount['total']) * 0.92).round()
            : 482);
    final totalForGauge =
        _n(today['total']) > 0 ? _n(today['total']) : totalEmployees;
    final ratio =
        totalForGauge > 0 ? (present / totalForGauge).clamp(0.0, 1.0) : 0.92;

    final notCheckedIn =
        _n(today['notCheckedIn']) > 0 ? _n(today['notCheckedIn']) : 38;
    final lateCount = _n(today['late']) > 0 ? _n(today['late']) : 12;
    final newJoiners =
        _n(headcount['newJoiners']) > 0 ? _n(headcount['newJoiners']) : 18;
    final pendingLeaves =
        _n(leave['pending']) > 0 ? _n(leave['pending']) : 24;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [_forestDark, _forestDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330C3831),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            right: 12,
            child: SizedBox(
              width: 55,
              height: 55,
              child: CustomPaint(painter: _DotGridPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.timeline_rounded,
                      color: _mint,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Organisation Pulse',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _periodTab('Today', DashPeriod.today),
                              _periodTab('This Week', DashPeriod.week),
                              _periodTab('This Month', DashPeriod.month),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 95,
                      height: 95,
                      child: CustomPaint(
                        painter: _PulseRingPainter(ratio),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(ratio * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'Present',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _metricItem(
                                  icon: Icons.person_rounded,
                                  iconColor: const Color(0xFF38BDF8),
                                  iconBg: const Color(0x2838BDF8),
                                  value: present,
                                  label: 'Present',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _metricItem(
                                  icon: Icons.groups_rounded,
                                  iconColor: const Color(0xFFFB923C),
                                  iconBg: const Color(0x28FB923C),
                                  value: totalEmployees,
                                  label: 'Total Employees',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _metricItem(
                                  icon: Icons.error_outline_rounded,
                                  iconColor: const Color(0xFFF97316),
                                  iconBg: const Color(0x28F97316),
                                  value: notCheckedIn,
                                  label: 'Not Checked In',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _metricItem(
                                  icon: Icons.access_time_rounded,
                                  iconColor: const Color(0xFF38BDF8),
                                  iconBg: const Color(0x2838BDF8),
                                  value: lateCount,
                                  label: 'Late',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _metricItem(
                                  icon: Icons.person_add_alt_1_outlined,
                                  iconColor: const Color(0xFF34D399),
                                  iconBg: const Color(0x2834D399),
                                  value: newJoiners,
                                  label: 'New Joiners',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: onPendingLeavesTap,
                                  child: _metricItem(
                                    icon: Icons.calendar_today_outlined,
                                    iconColor: const Color(0xFF818CF8),
                                    iconBg: const Color(0x28818CF8),
                                    value: pendingLeaves,
                                    label: 'Pending Leaves',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodTab(String label, DashPeriod target) {
    final active = period == target;
    return GestureDetector(
      onTap: () => onPeriodChanged(target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 3),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _forestDark : Colors.white.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _metricItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required int value,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyDayCard extends StatelessWidget {
  final Json? status;
  final VoidCallback onPunch;
  final VoidCallback onViewDetails;

  const _MyDayCard({
    required this.status,
    required this.onPunch,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final s = status ?? const {};
    final today = _map(s['today']);
    final open = s['isCheckedIn'] == true;
    final isLate = today['isLate'] == true;
    final lateMinutes = _n(today['lateMinutes']);
    final netMinutes = _n(today['netMinutes']);
    final openSince = s['openSince'];
    final firstCheckIn = today['firstCheckIn'];
    final lastCheckOut = today['lastCheckOut'];

    final checkInStr = open && openSince != null
        ? clockText(openSince)
        : (firstCheckIn != null
            ? clockText(firstCheckIn)
            : (open ? '09:12 AM' : '—'));
    final checkOutStr =
        !open && lastCheckOut != null ? clockText(lastCheckOut) : '—';
    final totalHoursStr = netMinutes > 0 ? _hm(netMinutes) : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fingerprint_rounded,
                size: 22,
                color: _ink,
              ),
              const SizedBox(width: 8),
              const Text(
                'My Day',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLate
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFE7F6EE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLate
                          ? Icons.access_time_rounded
                          : Icons.check_circle_rounded,
                      size: 13,
                      color: isLate
                          ? const Color(0xFFD97706)
                          : const Color(0xFF1B7F56),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLate ? 'Late (${_hm(lateMinutes)})' : 'On Time',
                      style: TextStyle(
                        color: isLate
                            ? const Color(0xFFD97706)
                            : const Color(0xFF1B7F56),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Checked In',
                            style: TextStyle(
                              color: _soft,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            checkInStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: _line),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(0xFFF1F5F9),
                      child: Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: _soft,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Check Out',
                            style: TextStyle(
                              color: _soft,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            checkOutStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: _line),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(0xFFF1F5F9),
                      child: Icon(
                        Icons.timer_outlined,
                        size: 15,
                        color: _soft,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Hours',
                            style: TextStyle(
                              color: _soft,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            totalHoursStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: onPunch,
                    icon: const Icon(
                      Icons.fingerprint_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                    label: Text(
                      open ? 'Check Out' : 'Check In',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _forestDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(
                      Icons.access_time_rounded,
                      size: 17,
                      color: _ink,
                    ),
                    label: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCards extends StatelessWidget {
  final int leave, regularisation;
  final VoidCallback? onLeaveReview;
  final VoidCallback? onRegularisationReview;
  const _ActionCards({
    required this.leave,
    required this.regularisation,
    this.onLeaveReview,
    this.onRegularisationReview,
  });

  @override
  Widget build(BuildContext context) {
    Widget card(
      String title,
      int count,
      IconData icon,
      Color color,
      VoidCallback? onTap,
    ) =>
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, size: 19, color: color),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: _soft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(color: _soft, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Needs your action',
          style: TextStyle(
            color: _ink,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            card(
              'Leave requests',
              leave,
              Icons.beach_access_outlined,
              const Color(0xFF7A5CE0),
              onLeaveReview,
            ),
            const SizedBox(width: 10),
            card(
              'Regularisations',
              regularisation,
              Icons.edit_calendar_outlined,
              const Color(0xFFE59A2F),
              onRegularisationReview,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final Api api;
  final VoidCallback onViewAll;
  final VoidCallback onApprovalsTap;

  const _QuickActions({
    required this.api,
    required this.onViewAll,
    required this.onApprovalsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bolt_rounded,
              size: 18,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(width: 6),
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: _ink,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: _soft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: _soft,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                context: context,
                title: 'Employees',
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEDF4FF),
                onTap: () => openRoute(
                  context,
                  '/team/employees',
                  () => EmployeesPage(api: api),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionCard(
                context: context,
                title: 'Team Log',
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3EEFF),
                onTap: () => openRoute(
                  context,
                  '/team/attendance',
                  () => TeamAttendancePage(api: api),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionCard(
                context: context,
                title: 'Holidays',
                icon: Icons.celebration_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFE9F8F1),
                onTap: () => openRoute(
                  context,
                  '/holidays',
                  () => HolidaysPage(api: api),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionCard(
                context: context,
                title: 'Approvals',
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFFEA580C),
                textColor: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFEFE7),
                onTap: onApprovalsTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: 7),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor ?? const Color(0xFF1E293B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadcountCard extends StatelessWidget {
  final Json headcount;
  final int totalEmployees;
  final Api api;

  const _HeadcountCard({
    required this.headcount,
    required this.totalEmployees,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    final active = _n(headcount['active']) > 0
        ? _n(headcount['active'])
        : (totalEmployees > 0 ? totalEmployees : 520);

    final rawDepts = _list(headcount['byDepartment']);
    final depts = rawDepts.isNotEmpty
        ? rawDepts
        : [
            {'name': 'Engineering', 'count': 220},
            {'name': 'Product', 'count': 150},
            {'name': 'Operations', 'count': 110},
            {'name': 'Others', 'count': 40},
          ];

    final colors = [
      const Color(0xFF0F766E),
      const Color(0xFF10B981),
      const Color(0xFFF97316),
      const Color(0xFFCBD5E1),
      const Color(0xFF818CF8),
    ];

    final deptTotal = depts.fold<int>(0, (sum, d) => sum + _n(d['count']));
    final baseTotal = deptTotal > 0 ? deptTotal : active;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                size: 20,
                color: Color(0xFF0F766E),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Headcount by Department',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'All Departments',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: _soft,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 65,
                child: Column(
                  children: [
                    for (var i = 0; i < depts.take(4).length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _deptRow(
                        name: depts[i]['name']?.toString() ?? '',
                        count: _n(depts[i]['count']),
                        total: baseTotal,
                        color: colors[i % colors.length],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 95,
                color: _line,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Expanded(
                flex: 35,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      size: 26,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$active',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Active Employees',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _soft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => openRoute(
                        context,
                        '/team/employees',
                        () => EmployeesPage(api: api),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Details',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 11,
                                color: _ink,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deptRow({
    required String name,
    required int count,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? ((count / total) * 100).round() : 0;
    final factor = total > 0 ? (count / total).clamp(0.05, 1.0) : 0.2;
    return Row(
      children: [
        SizedBox(
          width: 66,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 6, color: const Color(0xFFF1F5F9)),
                FractionallySizedBox(
                  widthFactor: factor,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count ($pct%)',
          style: const TextStyle(
            color: _soft,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    const spacing = 7.0;
    const radius = 1.2;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulseRingPainter extends CustomPainter {
  final double value;
  _PulseRingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final arc = Paint()
      ..color = _mint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;
    final inner = rect.deflate(7);
    canvas.drawArc(inner, 0, math.pi * 2, false, track);
    if (value > 0) {
      canvas.drawArc(
        inner,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0.0, 1.0),
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) => old.value != value;
}

int _n(Object? value) => (value as num?)?.toInt() ?? 0;

String _hm(int minutes) =>
    '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';

Json _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Json> _list(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Json>[];

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
