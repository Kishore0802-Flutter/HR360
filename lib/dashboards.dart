import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'api.dart';
import 'clock_in.dart';
import 'design.dart';
import 'directory.dart';
import 'nav.dart';
import 'requests.dart';
import 'shell.dart' show dashMood, friendlyDay;
export 'task_dashboard.dart';

const _ink = Color(0xFF1B2A4A);
const _soft = Color(0xFF8B93A7);
const _line = Color(0xFFE9EDF1);
const _amber = Color(0xFFE59A2F);
const _red = Color(0xFFE15B64);
const _blue = Color(0xFF4F7DF3);
const _violet = Color(0xFF7A5CE0);

enum DashPeriod { today, week, month }

/// Home tab for Admin, HR, and Manager roles. Employees keep the designed
/// personal home in `shell.dart`.
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
    final d = data!;
    final today = _map(d['attendanceToday']);
    final children = <Widget>[
      _header(),
      if (widget.moduleSwitch != null) ...[
        const SizedBox(height: 14),
        widget.moduleSwitch!,
      ],
      const SizedBox(height: 16),
      _hero(d),
      if (status != null) ...[
        const SizedBox(height: 14),
        _MyDay(status!, punch),
      ],
      ..._body(d, today),
    ];
    return ColoredBox(
      color: const Color(0xFFF4F7F8),
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
          children: children,
        ),
      ),
    );
  }

  List<Widget> _body(Json d, Json today) {
    final leave = _map(d['leave']);
    final regularisation = _map(d['regularisation']);
    final pipeline = _Card(
      title: 'Leave & regularisation',
      subtitle: _rangeText(),
      child: _Pipeline(
        leave: leave,
        regularisation: regularisation,
        onLeaveTap: (api.can('leave:approve') || api.manager)
            ? () => _navigateToApprovals('Leave')
            : null,
        onRegularisationTap: (api.can('regularisations:approve') || api.manager)
            ? () => _navigateToApprovals('Attendance')
            : null,
      ),
    );
    final headcount = _map(d['headcount']);
    final departments = _Card(
      title: 'Headcount by department',
      subtitle: '${_n(headcount['active'])} active people',
      child: _Bars(_list(headcount['byDepartment']), color: primary),
    );
    final designations = _Card(
      title: 'Designation mix',
      subtitle: 'Roles across the organisation',
      child: _Chips(_list(headcount['byDesignation'])),
    );
    final shortcuts = _Shortcuts(api);
    Widget gap(Widget w) =>
        Padding(padding: const EdgeInsets.only(top: 14), child: w);
    switch (role) {
      case 'hr':
        return [
          gap(shortcuts),
          gap(departments),
          gap(designations),
          gap(pipeline),
        ];
      case 'admin':
        return [
          gap(shortcuts),
          gap(departments),
          gap(pipeline),
        ];
      default:
        return [
          gap(
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
          ),
          gap(shortcuts),
        ];
    }
  }

  String _rangeText() {
    final (from, to) = range;
    if (period == DashPeriod.today) return _dayLabel(to);
    return '${_dayLabel(from)} – ${_dayLabel(to)}';
  }

  Widget _header() {
    final now = tz.TZDateTime.now(tz.getLocation(officeTimezone));
    final mood = dashMood(now);
    final profile = api.profile ?? const {};
    final name = profile['name']?.toString() ?? '';
    final first = name.trim().split(RegExp(r'\s+')).first;
    final roleName = profile['role_name']?.toString() ?? '';
    final scope = switch (api.scope.toUpperCase()) {
      'ALL' => 'Organisation-wide',
      'TEAM' => 'My team',
      _ => 'Only me',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                friendlyDay(now),
                style: const TextStyle(color: _soft, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(
                '${mood.greeting}, $first',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _roleTone(role).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_roleIcon(role), size: 14, color: _roleTone(role)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        [if (roleName.isNotEmpty) roleName, scope].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _roleTone(role),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsPage(api: api)),
            );
            load();
          },
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            backgroundColor: const Color(0xFFE85D4C),
            child: const Icon(Icons.notifications_none_rounded, color: _ink),
          ),
        ),
        GestureDetector(
          onTap: () => widget.onTab(profileTab),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: _roleTone(role).withValues(alpha: 0.15),
            child: Text(
              _initials(name),
              style: TextStyle(
                color: _roleTone(role),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero(Json d) {
    final today = _map(d['attendanceToday']);
    final headcount = _map(d['headcount']);
    final leave = _map(d['leave']);
    final total = _n(today['total']);
    final present = _n(today['present']) + _n(today['checkedIn']);
    final ratio = total == 0 ? 0.0 : present / total;
    switch (role) {
      case 'hr':
        return _Hero(
          colors: const [Color(0xFF0F6B4B), Color(0xFF2FA77A)],
          eyebrow: 'People overview',
          value: '${_n(headcount['total'])}',
          suffix: ' people',
          caption:
              '${_n(headcount['active'])} active · ${_n(headcount['inactive'])} inactive',
          ring: ratio,
          ringLabel: 'present',
          chips: [
            ('New joiners', _n(headcount['newJoiners'])),
            ('Departments', _list(headcount['byDepartment']).length),
            ('Leave pending', _n(leave['pending'])),
          ],
        );
      case 'admin':
        return _Hero(
          colors: const [Color(0xFF1E2A4A), Color(0xFF34477A)],
          eyebrow: 'Organisation pulse',
          value: '$present',
          suffix: ' / $total present',
          caption:
              '${_n(today['notCheckedIn'])} not checked in · ${_n(today['late'])} late',
          ring: ratio,
          ringLabel: 'present',
          chips: [
            ('Headcount', _n(headcount['total'])),
            ('New joiners', _n(headcount['newJoiners'])),
            ('Leave pending', _n(leave['pending'])),
          ],
        );
      default:
        return _Hero(
          colors: const [Color(0xFF5B3FD6), Color(0xFF8E72F2)],
          eyebrow: 'Your team today',
          value: '$present',
          suffix: ' / $total in',
          caption:
              '${_n(today['notCheckedIn'])} yet to check in · ${_n(today['onLeave'])} on leave',
          ring: ratio,
          ringLabel: 'present',
          chips: [
            ('Late', _n(today['late'])),
            ('Absent', _n(today['absent'])),
            ('To review', _n(leave['pending'])),
          ],
        );
    }
  }
}

// Building blocks

class _Hero extends StatelessWidget {
  final List<Color> colors;
  final String eyebrow, value, suffix, caption, ringLabel;
  final double ring;
  final List<(String, int)> chips;
  const _Hero({
    required this.colors,
    required this.eyebrow,
    required this.value,
    required this.suffix,
    required this.caption,
    required this.ring,
    required this.ringLabel,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                      eyebrow.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: value,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                          children: [
                            TextSpan(
                              text: suffix,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      caption,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 84,
                height: 84,
                child: CustomPaint(
                  painter: _RingPainter(ring),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(ring * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          ringLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${chips[i].$2}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          chips[i].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;
    final inner = rect.deflate(6);
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
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// Check-in card for leaders who also record their own attendance.
class _MyDay extends StatelessWidget {
  final Json status;
  final VoidCallback onPunch;
  const _MyDay(this.status, this.onPunch);

  @override
  Widget build(BuildContext context) {
    final today = _map(status['today']);
    final open = status['isCheckedIn'] == true;
    final canIn = status['canCheckIn'] == true;
    final sessions = _n(today['completedSessions']);
    final minutes = _n(today['netMinutes']);
    final dayStatus = today['status']?.toString() ?? '';
    final title = open
        ? 'Checked in since ${clockText(status['openSince'])}'
        : sessions > 0
        ? '$sessions session${sessions == 1 ? '' : 's'} done · ${_hm(minutes)}'
        : 'You have not checked in yet';
    final late = today['isLate'] == true
        ? 'Late by ${_hm(_n(today['lateMinutes']))}'
        : 'On time so far';
    final action = open
        ? 'Check out'
        : canIn
        ? 'Check in'
        : 'Day complete';
    return _Card(
      title: 'My day',
      subtitle: late,
      trailing: dayStatus.isEmpty
          ? null
          : _Pill(_pretty(dayStatus), _statusTone(dayStatus)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (open ? primary : _blue).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              open ? Icons.timer_outlined : Icons.fingerprint_rounded,
              color: open ? primary : _blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: open || canIn ? onPunch : null,
            style: FilledButton.styleFrom(
              backgroundColor: open ? const Color(0xFFE85D4C) : primary,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              open ? Icons.logout_rounded : Icons.login_rounded,
              size: 18,
            ),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  const _Card({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: _soft, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Pipeline extends StatelessWidget {
  final Json leave, regularisation;
  final VoidCallback? onLeaveTap;
  final VoidCallback? onRegularisationTap;
  const _Pipeline({
    required this.leave,
    required this.regularisation,
    this.onLeaveTap,
    this.onRegularisationTap,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _row(
        'Leave',
        Icons.beach_access_outlined,
        leave,
        '${_n(leave['approvedDays'])} approved days',
        onTap: onLeaveTap,
      ),
      const Divider(height: 22, color: _line),
      _row(
        'Regularisation',
        Icons.edit_calendar_outlined,
        regularisation,
        'Attendance corrections',
        onTap: onRegularisationTap,
      ),
    ],
  );

  Widget _row(
    String title,
    IconData icon,
    Json data,
    String note, {
    VoidCallback? onTap,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: _ink),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(color: _soft, fontSize: 11),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: _soft),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final item in [
              ('Pending', data['pending'], _amber),
              ('Approved', data['approved'], primary),
              ('Rejected', data['rejected'], _red),
            ]) ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  margin: EdgeInsets.only(right: item.$1 == 'Rejected' ? 0 : 8),
                  decoration: BoxDecoration(
                    color: item.$3.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_n(item.$2)}',
                        style: TextStyle(
                          color: item.$3,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        item.$1,
                        style: const TextStyle(color: _soft, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: content,
          ),
        ),
      );
    }
    return content;
  }
}

class _Bars extends StatelessWidget {
  final List<Json> rows;
  final Color color;
  const _Bars(this.rows, {required this.color});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No data yet.', style: TextStyle(color: _soft));
    }
    final sorted = [...rows]
      ..sort((a, b) => _n(b['count']).compareTo(_n(a['count'])));
    final peak = math.max(1, _n(sorted.first['count']));
    return Column(
      children: [
        for (final row in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    row['name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _ink, fontSize: 12.5),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(height: 10, color: const Color(0xFFF0F2F5)),
                        FractionallySizedBox(
                          widthFactor: _n(row['count']) / peak,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.6)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${_n(row['count'])}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  final List<Json> rows;
  const _Chips(this.rows);
  @override
  Widget build(BuildContext context) {
    const tones = [primary, _blue, _violet, _amber, _red, Color(0xFF0E9AA7)];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: tones[i % tones.length].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${rows[i]['name']} · ${_n(rows[i]['count'])}',
              style: TextStyle(
                color: tones[i % tones.length],
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
      ],
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
    VoidCallback? onLeaveReview,
    this.onRegularisationReview,
    VoidCallback? onReview,
  }) : onLeaveReview = onLeaveReview ?? onReview;

  @override
  Widget build(BuildContext context) {
    Widget card(
      String title,
      int count,
      IconData icon,
      Color color,
      VoidCallback? onTap,
    ) => Expanded(
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
                    fontWeight: FontWeight.w800,
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
              _violet,
              onLeaveReview,
            ),
            const SizedBox(width: 10),
            card(
              'Regularisations',
              regularisation,
              Icons.edit_calendar_outlined,
              _amber,
              onRegularisationReview,
            ),
          ],
        ),
      ],
    );
  }
}

class _Shortcuts extends StatelessWidget {
  final Api api;
  const _Shortcuts(this.api);
  @override
  Widget build(BuildContext context) {
    final items = [
      if (api.can('employees:view'))
        (
          'Employees',
          Icons.badge_outlined,
          primary,
          () => openRoute(
            context,
            '/team/employees',
            () => EmployeesPage(api: api),
          ),
        ),
      if (api.can('attendance:review'))
        (
          'Team log',
          Icons.fact_check_outlined,
          _blue,
          () => openRoute(
            context,
            '/team/attendance',
            () => TeamAttendancePage(api: api),
          ),
        ),
      if (api.can('holidays:view'))
        (
          'Holidays',
          Icons.celebration_outlined,
          _amber,
          () => openRoute(context, '/holidays', () => HolidaysPage(api: api)),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: items[i].$4,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    children: [
                      Icon(items[i].$2, color: items[i].$3),
                      const SizedBox(height: 6),
                      Text(
                        items[i].$1,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Helpers

const _months = [
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

String _dayLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

int _n(Object? value) => (value as num?)?.toInt() ?? 0;

String _hm(int minutes) =>
    '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';

Json _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Json> _list(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Json>[];

String _pretty(String raw) {
  final text = raw.toLowerCase().replaceAll('_', ' ');
  return text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1);
}

Color _statusTone(String raw) => switch (raw.toUpperCase()) {
  'PRESENT' || 'APPROVED' || 'COMPLETED' => primary,
  'PENDING' || 'LATE' || 'NOT_CHECKED_IN' => _amber,
  'ABSENT' || 'REJECTED' || 'MISSING_CHECKOUT' => _red,
  'ON_LEAVE' || 'HALF_DAY_LEAVE' => _violet,
  _ => _blue,
};

Color _roleTone(String role) => switch (role) {
  'admin' => const Color(0xFF34477A),
  'hr' => primary,
  'manager' => _violet,
  _ => _blue,
};

IconData _roleIcon(String role) => switch (role) {
  'admin' => Icons.admin_panel_settings_outlined,
  'hr' => Icons.diversity_3_outlined,
  'manager' => Icons.supervisor_account_outlined,
  _ => Icons.person_outline,
};

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
