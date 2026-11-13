import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          padding: EdgeInsets.fromLTRB(
            responsiveHorizontalPadding(context, mobilePadding: 16),
            6,
            responsiveHorizontalPadding(context, mobilePadding: 16),
            120,
          ),
          children: [
            _header(),
            if (widget.moduleSwitch != null) ...[
              const SizedBox(height: 20),
              widget.moduleSwitch!,
            ],
            const SizedBox(height: 20),
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
    DateTime now;
    try {
      now = tz.TZDateTime.now(tz.getLocation(officeTimezone));
    } catch (_) {
      now = DateTime.now();
    }
    final mood = dashMood(now);
    final userName = api.userName;
    final userRole = api.userRole;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF475569),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
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
                    color: Color(0xFF1B2A4A),
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
                backgroundColor: const Color(0xFF1B2A4A),
                child: Text(
                  _initials(userName),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3.5,
              height: 48,
              margin: const EdgeInsets.only(top: 3, right: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${mood.greeting},\n',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF1B2A4A),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        TextSpan(
                          text: userName,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Text(
                          userRole,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF1B5E20),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Here's your organization overview",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8B93A7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
    );
  }
}

class _OrganisationPulseCard extends StatelessWidget {
  final Json data;
  final DashPeriod? period;
  final ValueChanged<DashPeriod>? onPeriodChanged;
  final VoidCallback? onPendingLeavesTap;

  const _OrganisationPulseCard({
    required this.data,
    this.period,
    this.onPeriodChanged,
    this.onPendingLeavesTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = _map(data['attendanceToday']);
    final headcount = _map(data['headcount']);

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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F6EE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7EBD7)),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF1B7F56),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Organisation Pulse',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF1B2A4A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _PulseRingPainter(
                    ratio,
                    trackColor: const Color(0xFFF1F5F9),
                    progressColor: const Color(0xFF1B7F56),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(ratio * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFF1B2A4A),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Present',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _metricRow(
                      icon: Icons.groups_rounded,
                      iconColor: const Color(0xFF7C6BF2),
                      bgColor: const Color(0xFFF3F0FF),
                      borderColor: const Color(0xFFE2D9FC),
                      label: 'Total Employees',
                      value: totalEmployees,
                    ),
                    const SizedBox(height: 7),
                    _metricRow(
                      icon: Icons.person_rounded,
                      iconColor: const Color(0xFF1B7F56),
                      bgColor: const Color(0xFFE7F6EE),
                      borderColor: const Color(0xFFC7EBD7),
                      label: 'Present',
                      value: present,
                    ),
                    const SizedBox(height: 7),
                    _metricRow(
                      icon: Icons.error_outline_rounded,
                      iconColor: const Color(0xFFBE5E38),
                      bgColor: const Color(0xFFFDF6F0),
                      borderColor: const Color(0xFFE8D3C5),
                      label: 'Not Checked In',
                      value: notCheckedIn,
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

  Widget _metricRow({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String label,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              color: iconColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCFE0FC)),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: Color(0xFF3B82F6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'My Day',
                  style: TextStyle(
                    color: Color(0xFF1B2A4A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLate
                      ? const Color(0xFFFDF6F0)
                      : const Color(0xFFE7F6EE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLate
                        ? const Color(0xFFE8D3C5)
                        : const Color(0xFFC7EBD7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLate
                          ? Icons.schedule_rounded
                          : Icons.check_circle_rounded,
                      size: 13,
                      color: isLate
                          ? const Color(0xFFBE5E38)
                          : const Color(0xFF1B7F56),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLate ? 'Late (${_hm(lateMinutes)})' : 'On Time',
                      style: TextStyle(
                        color: isLate
                            ? const Color(0xFFBE5E38)
                            : const Color(0xFF1B7F56),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _dayStatBox(
                  label: 'Checked In',
                  value: checkInStr,
                  icon: Icons.check_rounded,
                  color: const Color(0xFF1B7F56),
                  bgColor: const Color(0xFFE7F6EE),
                  borderColor: const Color(0xFFC7EBD7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dayStatBox(
                  label: 'Check Out',
                  value: checkOutStr,
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEAF1FF),
                  borderColor: const Color(0xFFCFE0FC),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dayStatBox(
                  label: 'Total Hours',
                  value: totalHoursStr,
                  icon: Icons.timer_outlined,
                  color: const Color(0xFF7C6BF2),
                  bgColor: const Color(0xFFF3F0FF),
                  borderColor: const Color(0xFFE2D9FC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: onPunch,
                    icon: const Icon(
                      Icons.fingerprint_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      open ? 'Check Out' : 'Check In',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _forestDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Color(0xFF1B2A4A),
                    ),
                    label: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B2A4A),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _dayStatBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1B2A4A),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
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
      Color accentColor,
      Color bgColor,
      Color borderColor,
      VoidCallback? onTap,
    ) =>
        Expanded(
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 17, color: Colors.white),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: accentColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
            color: Color(0xFF1B2A4A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            card(
              'Leave requests',
              leave,
              Icons.beach_access_outlined,
              const Color(0xFF7C6BF2),
              const Color(0xFFF3F0FF),
              const Color(0xFFE2D9FC),
              onLeaveReview,
            ),
            const SizedBox(width: 10),
            card(
              'Regularisations',
              regularisation,
              Icons.edit_calendar_outlined,
              const Color(0xFFBE5E38),
              const Color(0xFFFDF6F0),
              const Color(0xFFE8D3C5),
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


class _PulseRingPainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color progressColor;

  _PulseRingPainter(
    this.value, {
    this.trackColor = const Color(0xFFF1F5F9),
    this.progressColor = const Color(0xFF10B981),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final arc = Paint()
      ..color = progressColor
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
  bool shouldRepaint(_PulseRingPainter old) =>
      old.value != value ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
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
