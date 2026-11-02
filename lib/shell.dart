import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'api.dart';
import 'design.dart';
import 'attendance.dart';
import 'clock_in.dart';
import 'dashboards.dart';
import 'directory.dart';
import 'leave.dart';
import 'module_switch.dart';
// import 'nav.dart';
// import 'payslip.dart';
import 'requests.dart';
import 'tasks.dart';
import 'all_tasks.dart';
import 'projects.dart';
import 'scheduled_tasks.dart';
import 'roles.dart';
import 'leave_policies.dart';

class Shell extends StatefulWidget {
  final Api api;
  const Shell({super.key, required this.api});
  @override
  State<Shell> createState() => _ShellState();
}

class _Tab {
  final String label;
  final IconData icon, selected;
  final Widget page;
  const _Tab(this.label, this.icon, this.selected, this.page);
}

class _ShellState extends State<Shell> {
  int index = 0;
  int taskIndex = 0;
  String approvalsKind = 'Leave';
  AppModule module = AppModule.hrms;

  Api get api => widget.api;

  @override
  void initState() {
    super.initState();
    _restoreModule();
  }

  Future<void> _restoreModule() async {
    if (!api.hasTasks) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getString('module') == AppModule.tasks.name && mounted) {
        setState(() => module = AppModule.tasks);
      }
    } catch (_) {}
  }

  Future<void> switchModule(AppModule next) async {
    if (next == module) return;
    setState(() => module = next);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('module', next.name);
    } catch (_) {}
  }

  Widget? get moduleSwitch => api.hasTasks
      ? ModuleSwitch(module: module, onChanged: switchModule)
      : null;

  List<_Tab> get hrmsTabs {
    void go(int i, {String? kind}) => setState(() {
      index = i;
      if (kind != null) approvalsKind = kind;
    });
    final leader = api.live && api.role != null && api.role != 'employee';
    return [
      _Tab(
        'Home',
        Icons.home_outlined,
        Icons.home_rounded,
        leader
            ? RoleDashboard(
                api: api,
                onTab: (i) => go(i),
                onNavigate: (i, {subTab}) => go(i, kind: subTab),
                moduleSwitch: moduleSwitch,
              )
            : HomePage(
                api: api,
                onTab: (i) => go(i),
                moduleSwitch: moduleSwitch,
              ),
      ),
      _Tab(
        'Attendance',
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
        AttendancePage(api: api),
      ),
      _Tab('Leave', Icons.spa_outlined, Icons.spa_rounded, LeavePage(api: api)),
      if (api.manager)
        _Tab(
          'Approvals',
          Icons.verified_user_outlined,
          Icons.verified_user_rounded,
          RequestsPage(
            key: ValueKey('approvals_$approvalsKind'),
            api: api,
            mode: 'approvals',
            initialKind: approvalsKind,
          ),
        ),
      _Tab(
        'Profile',
        Icons.person_outline,
        Icons.person_rounded,
        ProfilePage(api: api),
      ),
    ];
  }

  List<_Tab> get taskTabs {
    void go(int i) => setState(() => taskIndex = i);
    final issues = api.can('issues:view');
    final calendar = api.can('calendar:view');
    final profileTab = 2 + (issues ? 1 : 0) + (calendar ? 1 : 0);
    return [
      _Tab(
        'Dashboard',
        Icons.space_dashboard_outlined,
        Icons.space_dashboard_rounded,
        TaskDashboard(
          api: api,
          onTab: go,
          profileTab: profileTab,
          issuesTab: issues ? 2 : null,
          moduleSwitch: moduleSwitch,
        ),
      ),
      _Tab(
        'My tasks',
        Icons.checklist_rtl_rounded,
        Icons.checklist_rounded,
        MyTasksPage(api: api),
      ),
      if (issues)
        _Tab(
          'Issues',
          Icons.report_gmailerrorred_outlined,
          Icons.report_rounded,
          IssuesPage(api: api),
        ),
      if (calendar)
        _Tab(
          'Calendar',
          Icons.event_note_outlined,
          Icons.event_note_rounded,
          TaskCalendarPage(api: api),
        ),
      _Tab(
        'Profile',
        Icons.person_outline,
        Icons.person_rounded,
        ProfilePage(api: api),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tasks = module == AppModule.tasks && api.hasTasks;
    final tabs = tasks ? taskTabs : hrmsTabs;
    final selected = (tasks ? taskIndex : index).clamp(0, tabs.length - 1);
    final accent = tasks ? AppModule.tasks.accent : const Color(0xFF1B8F6E);
    final soft = tasks ? AppModule.tasks.soft : const Color(0xFFDFF6EA);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: tasks
            ? const Color(0xFFF7F4F0)
            : const Color(0xFFF4F7F8),
        body: SafeArea(
          bottom: false,
          child: ModuleReveal(
            module: tasks ? AppModule.tasks : AppModule.hrms,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey('${tasks ? 't' : 'h'}$selected'),
                child: tabs[selected].page,
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              color: Colors.white,
              elevation: 10,
              shadowColor: const Color(0x1A1B3A4B),
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (api.hasTasks)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: tasks
                              ? AppModule.tasks.gradient
                              : AppModule.hrms.gradient,
                        ),
                      ),
                    ),
                  NavigationBarTheme(
                    data: NavigationBarThemeData(
                      height: 64,
                      backgroundColor: Colors.white,
                      indicatorColor: soft,
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final on = states.contains(WidgetState.selected);
                        return TextStyle(
                          fontSize: 11,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                          color: on ? accent : const Color(0xFF8B93A7),
                        );
                      }),
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        final on = states.contains(WidgetState.selected);
                        return IconThemeData(
                          size: 22,
                          color: on ? accent : const Color(0xFF8B93A7),
                        );
                      }),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.35),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: NavigationBar(
                        key: ValueKey(tasks),
                        selectedIndex: selected,
                        onDestinationSelected: (i) => setState(() {
                          if (tasks) {
                            taskIndex = i;
                          } else {
                            index = i;
                          }
                        }),
                        height: 64,
                        elevation: 0,
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.white,
                        indicatorColor: soft,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        destinations: [
                          for (final tab in tabs)
                            NavigationDestination(
                              icon: Icon(tab.icon),
                              selectedIcon: Icon(tab.selected),
                              label: tab.label,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum HomeDashboardFilter { thisMonth, last14Days, lastMonth, custom }

class HomePage extends StatefulWidget {
  final Api api;
  final ValueChanged<int> onTab;
  final Widget? moduleSwitch;
  const HomePage({
    super.key,
    required this.api,
    required this.onTab,
    this.moduleSwitch,
  });
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Json? data, location, report, attendanceStatus;
  HomeDashboardFilter filter = HomeDashboardFilter.thisMonth;
  DateTime focusMonth = DateTime.now();
  DateTimeRange? customRange;
  Object? error;
  bool loading = true, busy = false, showBirthday = true;
  Timer? timer;
  DateTime received = DateTime.now();
  int ticks = 0;

  List<Map<String, dynamic>> get _todayEvents {
    final raw =
        attendanceStatus?['events'] ??
        data?['events'] ??
        (data?['status'] is Map ? (data!['status'] as Map)['events'] : null);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic>? get _todayData {
    final raw =
        attendanceStatus?['today'] ??
        data?['attendance_today'] ??
        (data?['status'] is Map ? (data!['status'] as Map)['today'] : null);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  bool get _hasActivityToday {
    if (_todayEvents.isNotEmpty) return true;
    final td = _todayData;
    if (td != null && (td['firstInAt'] != null || td['lastOutAt'] != null)) {
      return true;
    }
    if (data?['active'] != null) return true;
    final sessions =
        (attendanceStatus?['sessionsToday'] ??
                data?['sessionsToday'] ??
                td?['sessionsCount'] as num?)
            ?.toInt() ??
        0;
    if (sessions > 0) return true;
    return false;
  }

  (DateTime, DateTime) get dashboardRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (filter) {
      HomeDashboardFilter.thisMonth => (
        DateTime(focusMonth.year, focusMonth.month, 1),
        today.year == focusMonth.year && today.month == focusMonth.month
            ? today
            : DateTime(focusMonth.year, focusMonth.month + 1, 0),
      ),
      HomeDashboardFilter.last14Days => (
        today.subtract(const Duration(days: 13)),
        today,
      ),
      HomeDashboardFilter.lastMonth => (
        DateTime(today.year, today.month - 1, 1),
        DateTime(today.year, today.month, 0),
      ),
      HomeDashboardFilter.custom => (
        customRange?.start ?? DateTime(today.year, today.month, 1),
        customRange?.end ?? today,
      ),
    };
  }

  String get filterLabel {
    final (from, to) = dashboardRange;
    switch (filter) {
      case HomeDashboardFilter.thisMonth:
        return '${_shortMonth(from.month)} ${from.year}';
      case HomeDashboardFilter.last14Days:
        return 'Last 14 days (${from.day} ${_shortMonth(from.month)} – ${to.day} ${_shortMonth(to.month)})';
      case HomeDashboardFilter.lastMonth:
        return 'Last month (${_shortMonth(from.month)} ${from.year})';
      case HomeDashboardFilter.custom:
        return '${from.day} ${_shortMonth(from.month)} – ${to.day} ${_shortMonth(to.month)} ${to.year}';
    }
  }

  void shiftMonth(int delta) {
    focusMonth = DateTime(focusMonth.year, focusMonth.month + delta);
    filter = HomeDashboardFilter.thisMonth;
    load();
  }

  void openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Select Dashboard Period',
                  style: TextStyle(
                    color: Color(0xFF1B2A4A),
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              _filterTile(
                'This Month',
                HomeDashboardFilter.thisMonth,
                Icons.calendar_month_outlined,
                onTap: () {
                  Navigator.pop(sheet);
                  setState(() {
                    filter = HomeDashboardFilter.thisMonth;
                    focusMonth = DateTime.now();
                  });
                  load();
                },
              ),
              _filterTile(
                'Last 14 Days',
                HomeDashboardFilter.last14Days,
                Icons.date_range_outlined,
                onTap: () {
                  Navigator.pop(sheet);
                  setState(() => filter = HomeDashboardFilter.last14Days);
                  load();
                },
              ),
              _filterTile(
                'Last Month',
                HomeDashboardFilter.lastMonth,
                Icons.history_outlined,
                onTap: () {
                  Navigator.pop(sheet);
                  setState(() => filter = HomeDashboardFilter.lastMonth);
                  load();
                },
              ),
              _filterTile(
                'Custom Range...',
                HomeDashboardFilter.custom,
                Icons.edit_calendar_outlined,
                onTap: () async {
                  Navigator.pop(sheet);
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 2),
                    lastDate: DateTime(now.year + 2),
                    initialDateRange:
                        customRange ??
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
                  if (picked != null) {
                    setState(() {
                      customRange = picked;
                      filter = HomeDashboardFilter.custom;
                    });
                    load();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterTile(
    String label,
    HomeDashboardFilter target,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    final selected = filter == target;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7F6EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? const Color(0xFF1B7F56)
                  : const Color(0xFF6E7C8A),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF1B7F56)
                      : const Color(0xFF1B2A4A),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: Color(0xFF1B7F56),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => ticks++);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final (from, to) = dashboardRange;
    try {
      final results = await Future.wait<dynamic>([
        widget.api
            .get('/attendance/status')
            .catchError((_) => <String, dynamic>{}),
        _loadDashboardReport(from, to),
        widget.api.v1('GET', '/attendance/status').catchError((_) => null),
      ]);
      final r = (results[0] is Map ? results[0] as Map : <String, dynamic>{})
          .cast<String, dynamic>();
      final rep = (results[1] is Map ? results[1] as Map : <String, dynamic>{})
          .cast<String, dynamic>();
      final v1Raw = results[2];
      final v1Status = v1Raw is Map
          ? (v1Raw['data'] is Map ? v1Raw['data'] as Map : v1Raw)
                .cast<String, dynamic>()
          : null;
      final homeProfile = r['profile'];
      if (homeProfile is Map && widget.api.profile == null) {
        widget.api.profile = Map<String, dynamic>.from(homeProfile);
      }
      if (mounted) {
        setState(() {
          data = r;
          report = rep;
          attendanceStatus =
              v1Status ??
              (r['status'] is Map
                  ? (r['status'] as Map).cast<String, dynamic>()
                  : null);
          error = null;
          loading = false;
          received = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<Json> _loadDashboardReport(DateTime from, DateTime to) async {
    final query = {'from': dateOnly(from), 'to': dateOnly(to)};
    try {
      final res = await widget.api.v1(
        'GET',
        '/reports/hrms/dashboard',
        query: query,
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return _mockDashboardData(from, to);
  }

  Future<void> check() async {
    setState(() => busy = true);
    try {
      final gps = await captureLocation();
      final r = await widget.api.checkLocation(gps);
      if (mounted) setState(() => location = r);
    } catch (e) {
      if (mounted) {
        setState(() => location = null);
        message(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> punch() async {
    final active = data?['active'];
    final checkingIn = active == null;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => checkingIn
            ? ClockInPage(api: widget.api)
            : widget.api.live
            ? ClockInPage(api: widget.api, action: 'out')
            : LocationPage(api: widget.api, action: 'out'),
      ),
    );
    if (result == true) await load();
  }

  Future<void> openPending() async {
    final leave = (report?['leave'] is Map) ? report!['leave'] as Map : null;
    final upcoming = (leave?['upcoming'] is List)
        ? leave!['upcoming'] as List
        : const [];
    final requests = upcoming
        .whereType<Map>()
        .where((r) => r['status']?.toString().toUpperCase() == 'PENDING')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    if (requests.isEmpty || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => _PendingSheet(
        requests: requests,
        onView: (row) async {
          Navigator.pop(sheet);
          if (!mounted) return;
          final leave = row['kind'] == 'Leave';
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => leave
                  ? LeaveDetailsPage(api: widget.api, id: row['id'].toString())
                  : RequestDetails(
                      api: widget.api,
                      id: row['id'].toString(),
                      review: false,
                    ),
            ),
          );
          if (mounted) load();
        },
        onRemind: () => message(
          sheet,
          'This request is already waiting with your manager.',
        ),
      ),
    );
  }

  Future<void> resolve() async {
    setState(() => busy = true);
    try {
      await widget.api.retryPending();
      await load();
      if (mounted) message(context, 'Your earlier action is confirmed.');
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const DashboardShimmer();
    if (error != null) return FailureView(error!, load);
    final d = data!,
        p =
            (d['profile'] is Map
                    ? d['profile'] as Map
                    : (widget.api.profile ?? const <String, dynamic>{}))
                .cast<String, dynamic>(),
        active = d['active'] as Json?;
    final records = (d['today_records'] as List?) ?? const [];
    final policy = d['policy'] is Map ? (d['policy'] as Map) : const {};
    final done =
        active == null &&
        records.isNotEmpty &&
        policy['multiple_sessions'] != true;
    final seconds = active != null
        ? ((active['seconds'] as num?) ?? 0) +
              DateTime.now().difference(received).inSeconds +
              records
                  .whereType<Map>()
                  .where((r) => r['id'] != active['id'])
                  .fold<num>(
                    0,
                    (sum, r) => sum + (((r['seconds'] as num?) ?? 0)),
                  )
        : records.whereType<Map>().fold<num>(
            0,
            (sum, r) => sum + (((r['seconds'] as num?) ?? 0)),
          );
    final now = tz.TZDateTime.now(tz.getLocation(officeTimezone));
    final mood = dashMood(now);
    final first = (p['name'] ?? 'User')
        .toString()
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    final photo = p['photo_url']?.toString() ?? '';
    final status = active != null
        ? 'Working · ${durationText(seconds)}'
        : done
        ? 'Your day is complete'
        : location == null
        ? 'Reached office yet?'
        : location!['inside'] == true
        ? 'You are at the office'
        : 'You are on a visit';
    final action = done
        ? 'View'
        : active != null
        ? 'Check out'
        : 'Check in';
    return ColoredBox(
      color: const Color(0xFFF4F7F8),
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/logo_mark.png',
                        height: 28,
                        alignment: Alignment.centerLeft,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'From Joining to Growing',
                        style: TextStyle(
                          color: Color(0xFF8E99A8),
                          fontSize: 11,
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
                      MaterialPageRoute(
                        builder: (_) => NotificationsPage(api: widget.api),
                      ),
                    );
                    load();
                  },
                  icon: Badge(
                    isLabelVisible: ((d['unread'] as num?) ?? 0) > 0,
                    smallSize: 8,
                    backgroundColor: const Color(0xFFE85D4C),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF1B3A4B),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onTab(widget.api.manager ? 4 : 3),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFD7EFE4),
                        backgroundImage: photo.isNotEmpty
                            ? NetworkImage(photo)
                            : null,
                        child: photo.isEmpty
                            ? const Icon(
                                Icons.person_rounded,
                                color: Color(0xFF1B8F6E),
                                size: 20,
                              )
                            : null,
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF1B3A4B),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.moduleSwitch != null) ...[
              const SizedBox(height: 12),
              widget.moduleSwitch!,
            ],
            const SizedBox(height: 16),
            if (widget.api.pending != null)
              Panel(
                color: const Color(0xFFFFF0DC),
                child: Column(
                  children: [
                    const Text(
                      'An earlier action is unconfirmed. Reconcile it before creating another request.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ActionButton(
                      'Resolve previous action',
                      busy: busy,
                      onPressed: resolve,
                    ),
                  ],
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: mood.card,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friendlyDay(now),
                                style: const TextStyle(
                                  color: Color(0xFF7C8794),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${mood.greeting},\n$first.',
                                  style: const TextStyle(
                                    color: Color(0xFF1B2A4A),
                                    fontSize: 26,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                mood.message,
                                style: const TextStyle(
                                  color: Color(0xFF6E7C8A),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            mood.image,
                            width: 108,
                            height: 136,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, 0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x141B3A4B),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: Row(
                          children: [
                            Material(
                              color: const Color(0xFFFFF1E8),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: busy ? null : check,
                                child: const SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Icon(
                                    Icons.door_front_door_outlined,
                                    color: Color(0xFFE07A3D),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                status,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1B3A4B),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 40),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: busy
                                  ? null
                                  : done
                                  ? () => widget.onTab(1)
                                  : punch,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(action),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_hasActivityToday) ...[
              _TodayActivityContainer(
                todayData: _todayData,
                events: _todayEvents,
                isCheckedIn:
                    (attendanceStatus?['isCheckedIn'] ??
                        data?['isCheckedIn'] ??
                        (_todayData?['hasOpenSession'] == true) ??
                        (data?['active'] != null)) ==
                    true,
                sessionsToday:
                    (attendanceStatus?['sessionsToday'] ??
                            data?['sessionsToday'] ??
                            _todayData?['sessionsCount'] as num?)
                        ?.toInt() ??
                    0,
                onViewDetails: () => widget.onTab(1),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'Apply Leave',
                    subtitle: 'Plan your time off',
                    image: 'assets/apply_leave_icon.png',
                    background: const Color(0xFFE7F6EE),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ApplyLeavePage(api: widget.api),
                        ),
                      );
                      if (mounted) load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    title: 'Raise a Request',
                    subtitle: 'Support & claims',
                    image: 'assets/raise_request_icon.png',
                    background: const Color(0xFFF3F0FF),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CorrectionPage(api: widget.api),
                        ),
                      );
                      if (mounted) load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DashTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeesPage(api: widget.api),
                ),
              ),
              child: Row(
                children: [
                  const _IconBadge(
                    icon: Icons.groups_outlined,
                    color: Color(0xFF1B8F6E),
                    background: Color(0xFFE7F6EE),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View all employees',
                          style: TextStyle(
                            color: Color(0xFF1B2A4A),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Company directory and mapped direct reports',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF8B93A7),
                    size: 18,
                  ),
                ],
              ),
            ),
            if (widget.api.manager && ((d['pending'] as num?) ?? 0) > 0) ...[
              const SizedBox(height: 12),
              _DashTile(
                onTap: () => widget.onTab(3),
                child: Row(
                  children: [
                    const _IconBadge(
                      icon: Icons.verified_user_outlined,
                      color: Color(0xFF1B8F6E),
                      background: Color(0xFFE7F6EE),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${d['pending']} requests to review',
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF8B93A7),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
            if (widget.api.manager) ...[
              const SizedBox(height: 12),
              _buildAdminTaskOperationsCard(context),
            ],
            const SizedBox(height: 16),
            _HomeDashboardView(
              api: widget.api,
              report:
                  report ??
                  _mockDashboardData(dashboardRange.$1, dashboardRange.$2),
              filterLabel: filterLabel,
              onPickFilter: openFilterSheet,
              onShiftMonth: shiftMonth,
              onTab: widget.onTab,
              onRefresh: load,
            ),
            // Commented out: Birthday Banner (Image 1)
            // if (showBirthday) ...[
            //   const SizedBox(height: 14),
            //   _BirthdayBanner(
            //     onWish: () {
            //       setState(() => showBirthday = false);
            //       message(context, 'Wish sent.');
            //     },
            //   ),
            // ],
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/progress_banner.jpg',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTaskOperationsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E2D9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE9DA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFFBE5E38),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administration & Operations',
                      style: TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Admin console & operations',
                      style: TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE9DA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    color: Color(0xFFBE5E38),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'OPERATIONS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _adminQuickChip(
                  icon: Icons.playlist_add_check_rounded,
                  label: 'Outlet Tasks',
                  color: const Color(0xFFD97706),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllTasksPage(
                          api: widget.api,
                          initialTaskType: 'OUTLET',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _adminQuickChip(
                  icon: Icons.storefront_outlined,
                  label: 'Outlets',
                  color: const Color(0xFF0F766E),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllTasksPage(
                          api: widget.api,
                          initialTaskType: 'OUTLET',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _adminQuickChip(
                  icon: Icons.warning_amber_rounded,
                  label: 'Issues',
                  color: const Color(0xFFDC2626),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IssuesPage(api: widget.api),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _adminQuickChip(
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendar',
                  color: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskCalendarPage(api: widget.api),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'ADMINISTRATION',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _adminQuickChip(
                  icon: Icons.local_offer_outlined,
                  label: 'Categories & Templates',
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduledTasksPage(api: widget.api),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _adminQuickChip(
                  icon: Icons.repeat_rounded,
                  label: 'Scheduled Tasks',
                  color: const Color(0xFFBE5E38),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduledTasksPage(api: widget.api),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _adminQuickChip(
                  icon: Icons.folder_outlined,
                  label: 'Projects',
                  color: const Color(0xFF059669),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectsPage(api: widget.api),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminQuickChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2A4A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationPage extends StatefulWidget {
  final Api api;
  final String action;
  const LocationPage({super.key, required this.api, required this.action});
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Json? location, gps;
  bool busy = false, success = false;
  Object? error;
  Json? record;
  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    setState(() {
      busy = true;
      error = null;
      location = null;
    });
    try {
      gps = await captureLocation();
      final r = await widget.api.checkLocation(gps!);
      if (mounted) setState(() => location = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> punch() async {
    setState(() => busy = true);
    try {
      final fresh = await captureLocation();
      final r = await widget.api.mutate(
        widget.action == 'out'
            ? '/attendance/check-out'
            : '/attendance/check-in',
        fresh,
      );
      if (mounted) {
        setState(() {
          record = r;
          success = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(success ? 'Attendance confirmed' : 'Office location'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (success) ...[
          const SizedBox(height: 35),
          const Center(
            child: CircleAvatar(
              radius: 38,
              backgroundColor: mint,
              child: Icon(Icons.check, size: 40, color: ink),
            ),
          ),
          heading(
            widget.action == 'in' ? 'Have a great day.' : 'A day well done.',
          ),
          const Text(
            'Your attendance has been saved.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          Panel(
            child: Column(
              children: [
                detail('Clock in', clockText(record!['clock_in'])),
                detail('Clock out', clockText(record!['clock_out'])),
                detail('Working hours', durationText(record!['seconds'])),
              ],
            ),
          ),
          ActionButton(
            'Back to my day',
            onPressed: () => Navigator.pop(context, true),
          ),
        ] else ...[
          heading('Your day starts here.'),
          const Text(
            'Location is used only to verify attendance. It is not tracked continuously.',
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 25),
          if (busy)
            const Center(child: TileLoader())
          else if (location != null)
            Panel(
              color: mint,
              child: Column(
                children: [
                  Icon(
                    location!['inside']
                        ? Icons.location_on_outlined
                        : Icons.location_off_outlined,
                    size: 54,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    location!['inside']
                        ? 'Inside your office radius'
                        : 'Outside your office radius',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  detail('Office', location!['office']['name']),
                  detail('Distance', '${location!['distance']} m'),
                  detail(
                    'Allowed radius',
                    '${location!['office']['radius']} m',
                  ),
                  detail('GPS accuracy', '${location!['accuracy']} m'),
                ],
              ),
            ),
          if (error != null) notice(error.toString()),
          const SizedBox(height: 20),
          ActionButton(
            'Confirm clock ${widget.action}',
            busy: busy,
            onPressed:
                location?['inside'] == true ||
                    (widget.api.offline && location != null)
                ? punch
                : null,
            icon: Icons.check,
          ),
          TextButton(
            onPressed: busy ? null : check,
            child: const Text('Refresh location'),
          ),
          TextButton(
            onPressed: () => Geolocator.openAppSettings(),
            child: const Text('App permissions'),
          ),
          TextButton(
            onPressed: () => Geolocator.openLocationSettings(),
            child: const Text('Location settings'),
          ),
        ],
      ],
    ),
  );
}

class ProfilePage extends StatefulWidget {
  final Api api;
  const ProfilePage({super.key, required this.api});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedTab = 0;
  bool busy = false;
  bool loadingProfile = false;
  Object? profileError;

  // Change password form state
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _updatingPassword = false;
  String? _passwordError;
  String? _passwordSuccess;

  // Preferences toggles state
  bool _dueReminders = true;
  bool _overdueReminders = true;
  bool _emailNotifications = false;
  bool _reducedMotion = false;
  bool _preferencesLoaded = false;

  @override
  void initState() {
    super.initState();
    _syncPreferences();
    if (widget.api.profile == null) {
      loadingProfile = true;
      loadProfile();
    }
  }

  void _syncPreferences() {
    final prefs = widget.api.profile?['preferences'];
    if (prefs is Map) {
      _preferencesLoaded = true;
      if (prefs.containsKey('dueReminders')) {
        _dueReminders = prefs['dueReminders'] == true;
      }
      if (prefs.containsKey('overdueReminders')) {
        _overdueReminders = prefs['overdueReminders'] == true;
      }
      if (prefs.containsKey('emailNotifications')) {
        _emailNotifications = prefs['emailNotifications'] == true;
      }
      if (prefs.containsKey('reducedMotion')) {
        _reducedMotion = prefs['reducedMotion'] == true;
      }
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    if (mounted && !loadingProfile) {
      setState(() {
        loadingProfile = true;
        profileError = null;
      });
    }
    try {
      await widget.api.refreshProfile();
      profileError = null;
      if (!_preferencesLoaded) _syncPreferences();
    } catch (e) {
      profileError = e;
    } finally {
      if (mounted) setState(() => loadingProfile = false);
    }
  }

  Future<void> logout() async {
    if (!await confirm(
      context,
      'Log out?',
      'Your attendance session will remain unchanged.',
    )) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.api.logout();
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _getRoleBadge(Json p) {
    final roleName = p['role_name']?.toString().trim();
    if (roleName != null && roleName.isNotEmpty) {
      return roleName;
    }
    final r = (p['role'] ?? widget.api.role ?? 'Employee').toString().trim();
    if (r.isEmpty) return 'Employee';
    return r[0].toUpperCase() + r.substring(1).toLowerCase();
  }

  String _formatLastSignIn(Json p) {
    final raw = p['last_sign_in'] ?? p['last_login'] ?? p['last_active'];
    DateTime dt;
    if (raw != null) {
      dt = DateTime.tryParse(raw.toString()) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }
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
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hh:$mm';
  }

  Widget _tabButton(String title, int idx) {
    final active = _selectedTab == idx;
    return InkWell(
      onTap: () => setState(() => _selectedTab = idx),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active
              ? Border.all(color: const Color(0xFFE2D8CC), width: 1)
              : null,
          boxShadow: active
              ? [
                  const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? const Color(0xFF1E242B) : const Color(0xFF706B65),
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityCard(
    Json p,
    String name,
    String designation,
    String roleBadgeText,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE3D7), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFFBA4728),
            child: Text(
              _profileInitials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1E242B),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            designation,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0E7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              roleBadgeText,
              style: const TextStyle(
                color: Color(0xFFBA4728),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(Json p) {
    final code = (p['code']?.toString().isNotEmpty == true)
        ? p['code'].toString()
        : (p['id']?.toString().isNotEmpty == true
              ? p['id'].toString()
              : 'DEMO-E01');
    final email = (p['email']?.toString().isNotEmpty == true)
        ? p['email'].toString()
        : 'employee@giraffai.in';
    final department = (p['department']?.toString().isNotEmpty == true)
        ? p['department'].toString()
        : 'Engineering';
    final manager = (p['manager_name']?.toString().isNotEmpty == true)
        ? p['manager_name'].toString()
        : ((p['manager'] is Map ? p['manager']['name']?.toString() : null) ??
              'Priya Raman');

    final scope = (p['scope'] ?? widget.api.scope).toString().toUpperCase();
    final String dataAccess;
    if (scope == 'ALL' || widget.api.role == 'admin') {
      dataAccess = 'All records';
    } else if (scope == 'DEPARTMENT' || widget.api.manager) {
      dataAccess = 'Department records';
    } else {
      dataAccess = 'Own records';
    }

    final timezone =
        ((p['office'] is Map) ? p['office']['timezone']?.toString() : null) ??
        officeTimezone;

    final lastSignIn = _formatLastSignIn(p);

    final items = [
      ('Employee code', code),
      ('Email', email),
      ('Department', department),
      ('Reporting manager', manager),
      ('Data access', dataAccess),
      ('Last sign-in', lastSignIn),
      ('Company timezone', timezone),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE3D7), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Text(
              'Details',
              style: TextStyle(
                color: Color(0xFF1E242B),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEFE8DE)),
          for (int i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      items[i].$1,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Text(
                      items[i].$2,
                      style: const TextStyle(
                        color: Color(0xFF1E242B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFEFE8DE)),
          ],
        ],
      ),
    );
  }

  Future<void> _updatePref(String key, bool val) async {
    setState(() {
      switch (key) {
        case 'dueReminders':
          _dueReminders = val;
        case 'overdueReminders':
          _overdueReminders = val;
        case 'emailNotifications':
          _emailNotifications = val;
        case 'reducedMotion':
          _reducedMotion = val;
      }
    });
    try {
      final res = await widget.api.updatePreferences({key: val});
      if (res['preferences'] is Map) {
        final updated = res['preferences'] as Map;
        if (mounted) {
          setState(() {
            if (updated.containsKey('dueReminders')) {
              _dueReminders = updated['dueReminders'] == true;
            }
            if (updated.containsKey('overdueReminders')) {
              _overdueReminders = updated['overdueReminders'] == true;
            }
            if (updated.containsKey('emailNotifications')) {
              _emailNotifications = updated['emailNotifications'] == true;
            }
            if (updated.containsKey('reducedMotion')) {
              _reducedMotion = updated['reducedMotion'] == true;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiFailure
            ? e.message
            : e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update preference: $msg'),
            backgroundColor: const Color(0xFFC24127),
          ),
        );
      }
    }
  }

  Widget _buildPreferencesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 4, child: _buildThemeCard()),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: _buildNotificationsCard()),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildThemeCard(),
            const SizedBox(height: 16),
            _buildNotificationsCard(),
          ],
        );
      },
    );
  }

  Widget _buildThemeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE3D7), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Text(
              'Theme',
              style: TextStyle(
                color: Color(0xFF1E242B),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEFE8DE)),
          const Padding(
            padding: EdgeInsets.all(22),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 14,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: 'Your workspace uses the '),
                  TextSpan(
                    text: 'Warm Sand',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E242B),
                    ),
                  ),
                  TextSpan(text: ' theme, chosen by your administrator.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE3D7), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Text(
              'Notifications & accessibility',
              style: TextStyle(
                color: Color(0xFF1E242B),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEFE8DE)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _preferenceRow(
                  value: _dueReminders,
                  onChanged: (v) => _updatePref('dueReminders', v),
                  label: 'Remind me before tasks are due',
                ),
                const SizedBox(height: 18),
                _preferenceRow(
                  value: _overdueReminders,
                  onChanged: (v) => _updatePref('overdueReminders', v),
                  label: 'Remind me about overdue tasks',
                ),
                const SizedBox(height: 18),
                _preferenceRow(
                  value: _emailNotifications,
                  onChanged: (v) => _updatePref('emailNotifications', v),
                  label:
                      'Also send notifications by email (when enabled by admin)',
                ),
                const SizedBox(height: 18),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFEFE8DE),
                ),
                const SizedBox(height: 18),
                _preferenceRow(
                  value: _reducedMotion,
                  onChanged: (v) => _updatePref('reducedMotion', v),
                  label: 'Reduce motion and animations',
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 64),
                  child: Text(
                    "Your operating system's reduced-motion setting is always respected.",
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferenceRow({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CustomSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1E242B),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleUpdatePassword() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    setState(() {
      _passwordError = null;
      _passwordSuccess = null;
    });

    if (current.isEmpty) {
      setState(() => _passwordError = 'Please enter your current password.');
      return;
    }
    if (newPass.length < 10) {
      setState(
        () => _passwordError = 'New password must be at least 10 characters.',
      );
      return;
    }
    if (newPass != confirm) {
      setState(() => _passwordError = 'New passwords do not match.');
      return;
    }

    setState(() => _updatingPassword = true);
    try {
      await widget.api.changePassword(current, newPass);
      if (mounted) {
        setState(() {
          _passwordSuccess = 'Password updated successfully.';
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            elevation: 6,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF22C55E), width: 1),
            ),
            backgroundColor: const Color(0xFF14532D),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Password updated successfully!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _passwordError = e.toString().replaceFirst(
            RegExp(r'^Exception:\s*'),
            '',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPassword = false);
    }
  }

  Widget _passwordTextField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFF1E242B), fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2D8CC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2D8CC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFBA4728), width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            color: const Color(0xFF8B93A7),
          ),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }

  Widget _buildSecurityTab(Json p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE3D7), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 6),
            child: Text(
              'Change password',
              style: TextStyle(
                color: Color(0xFF1E242B),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Text(
              'Changing your password signs out all other sessions.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEFE8DE)),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_passwordError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _passwordError!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                if (_passwordSuccess != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F6EE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBDECD9)),
                    ),
                    child: Text(
                      _passwordSuccess!,
                      style: const TextStyle(
                        color: Color(0xFF1B7F56),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const Text(
                  'Current password',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _passwordTextField(
                  controller: _currentPasswordController,
                  obscure: !_showCurrentPassword,
                  onToggleObscure: () => setState(
                    () => _showCurrentPassword = !_showCurrentPassword,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'New password',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _passwordTextField(
                  controller: _newPasswordController,
                  obscure: !_showNewPassword,
                  onToggleObscure: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                ),
                const SizedBox(height: 6),
                const Text(
                  'At least 10 characters with upper, lower case and a number.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Confirm new password',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _passwordTextField(
                  controller: _confirmPasswordController,
                  obscure: !_showConfirmPassword,
                  onToggleObscure: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB84E1A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _updatingPassword ? null : _handleUpdatePassword,
                    child: _updatingPassword
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Update password',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminQuickActionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF9F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEFE8DE)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1E242B),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.api.profile;
    if (p == null) {
      if (profileError != null) return FailureView(profileError!, loadProfile);
      return const DashboardShimmer();
    }
    final name = (p['name']?.toString() ?? '').trim();
    final displayName = name.isNotEmpty ? name : 'Arun Kumar';
    final designation = (p['designation']?.toString() ?? '').trim();
    final displayDesignation = designation.isNotEmpty
        ? designation
        : 'Software Engineer';
    final roleBadgeText = _getRoleBadge(p);

    return Container(
      color: const Color(0xFFFAF7F2),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My profile',
                      style: TextStyle(
                        color: Color(0xFF1E242B),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your account, preferences and security settings.',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : logout,
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 15,
                  color: Color(0xFFDC2626),
                ),
                label: const Text(
                  'Log out',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  backgroundColor: const Color(0xFFFEF2F2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EFE6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5DDD4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tabButton('Profile', 0),
                    _tabButton('Preferences', 1),
                    _tabButton('Security', 2),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedTab == 0) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 680;
                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 280,
                          child: _buildIdentityCard(
                            p,
                            displayName,
                            displayDesignation,
                            roleBadgeText,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDetailsCard(p)),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildIdentityCard(
                      p,
                      displayName,
                      displayDesignation,
                      roleBadgeText,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailsCard(p),
                  ],
                );
              },
            ),
            if (widget.api.isSuperAdmin) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFEBE3D7),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF0E7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Color(0xFFBA4728),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick actions',
                                style: TextStyle(
                                  color: Color(0xFF1E242B),
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Super admin privileged controls & configuration',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12.5,
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
                            color: const Color(0xFFFDF0E7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Super Admin',
                            style: TextStyle(
                              color: Color(0xFFBA4728),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEFE8DE),
                    ),
                    const SizedBox(height: 16),
                    _buildAdminQuickActionTile(
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEBF3FE),
                      title: 'Roles & permissions',
                      subtitle: 'Permissions, scope rules & user assignments',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RolesPage(api: widget.api),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildAdminQuickActionTile(
                      icon: Icons.assignment_outlined,
                      iconColor: const Color(0xFF16A34A),
                      iconBg: const Color(0xFFE7F6EE),
                      title: 'Leave types & policies',
                      subtitle:
                          'Entitlements, accrual frequencies & policy ledger',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LeavePoliciesPage(api: widget.api),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildAdminQuickActionTile(
                      icon: Icons.badge_outlined,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      title: 'Employees directory',
                      subtitle:
                          'Manage directory, employment & reporting lines',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmployeesPage(api: widget.api),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (_selectedTab == 1) ...[
            _buildPreferencesTab(),
          ] else ...[
            _buildSecurityTab(p),
          ],
          const SizedBox(height: 24),
          //_buildLogoutCard(),
        ],
      ),
    );
  }

  // Widget _buildLogoutCard() {
  // return Container(
  //   width: double.infinity,
  //   decoration: BoxDecoration(
  //     color: Colors.white,
  //     borderRadius: BorderRadius.circular(16),
  //     border: Border.all(
  //       color: const Color(0xFFFCA5A5).withValues(alpha: 0.6),
  //       width: 1.2,
  //     ),
  //     boxShadow: const [
  //       BoxShadow(
  //         color: Color(0x06000000),
  //         blurRadius: 8,
  //         offset: Offset(0, 2),
  //       ),
  //     ],
  //   ),
  //   child: Material(
  //     color: Colors.transparent,
  //     child: InkWell(
  //       onTap: busy ? null : logout,
  //       borderRadius: BorderRadius.circular(16),
  //       child: Padding(
  //         padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             if (busy)
  //               const SizedBox(
  //                 width: 18,
  //                 height: 18,
  //                 child: CircularProgressIndicator(
  //                   strokeWidth: 2,
  //                   color: Color(0xFFDC2626),
  //                 ),
  //               )
  //             else ...[
  //               // Container(
  //               //   padding: const EdgeInsets.all(7),
  //               //   decoration: BoxDecoration(
  //               //     color: const Color(0xFFFEF2F2),
  //               //     borderRadius: BorderRadius.circular(8),
  //               //   ),
  //               //   child: const Icon(
  //               //     Icons.logout_rounded,
  //               //     color: Color(0xFFDC2626),
  //               //     size: 18,
  //               //   ),
  //               // ),
  //               // const SizedBox(width: 10),
  //               // const Text(
  //               //   'Log out of HRMS',
  //               //   style: TextStyle(
  //               //     color: Color(0xFFDC2626),
  //               //     fontSize: 14.5,
  //               //     fontWeight: FontWeight.w700,
  //               //   ),
  //               // ),
  //             ],
  //           ],
  //         ),
  //       ),
  //     ),
  //   ),
  // );
  //}
}

class _CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value ? const Color(0xFFBA4728) : const Color(0xFFD5CFC7),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: value
              ? const Icon(Icons.check, size: 14, color: Color(0xFFBA4728))
              : null,
        ),
      ),
    );
  }
}

String _profileInitials(String name) {
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

class _HomeDashboardView extends StatelessWidget {
  final Api api;
  final Json report;
  final String filterLabel;
  final VoidCallback onPickFilter;
  final ValueChanged<int> onShiftMonth;
  final ValueChanged<int> onTab;
  final VoidCallback onRefresh;

  const _HomeDashboardView({
    required this.api,
    required this.report,
    required this.filterLabel,
    required this.onPickFilter,
    required this.onShiftMonth,
    required this.onTab,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final personal = (report['personal'] is Map)
        ? Map<String, dynamic>.from(report['personal'] as Map)
        : <String, dynamic>{};
    final rawDays = (personal['days'] is List)
        ? List<dynamic>.from(personal['days'] as List)
        : <dynamic>[];
    final days = rawDays
        .whereType<Map>()
        .map((d) => Map<String, dynamic>.from(d))
        .toList();

    // Show newest first (e.g. Sun 25 Oct down to Mon 12 Oct as in Image 2)
    final reversedDays = days.reversed.toList();

    final leave = (report['leave'] is Map)
        ? Map<String, dynamic>.from(report['leave'] as Map)
        : <String, dynamic>{};
    // ignore: unused_local_variable
    final regularisation = (report['regularisation'] is Map)
        ? Map<String, dynamic>.from(report['regularisation'] as Map)
        : <String, dynamic>{};
    final workingHours = (report['workingHours'] is Map)
        ? Map<String, dynamic>.from(report['workingHours'] as Map)
        : <String, dynamic>{};
    final exceptions = (report['exceptions'] is Map)
        ? Map<String, dynamic>.from(report['exceptions'] as Map)
        : <String, dynamic>{};
    final upcomingList = (leave['upcoming'] is List)
        ? List<dynamic>.from(
            leave['upcoming'] as List,
          ).whereType<Map>().map((u) => Map<String, dynamic>.from(u)).toList()
        : <Map<String, dynamic>>[];
    final leaveBalances = (personal['leaveBalances'] is List)
        ? List<dynamic>.from(
            personal['leaveBalances'] as List,
          ).whereType<Map>().map((b) => Map<String, dynamic>.from(b)).toList()
        : <Map<String, dynamic>>[];
    final byType = (leave['byType'] is List)
        ? List<dynamic>.from(
            leave['byType'] as List,
          ).whereType<Map>().map((t) => Map<String, dynamic>.from(t)).toList()
        : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header / Filter Bar (Image 5 - Period Filter) ──────────────────────────────
        // Commented out: Period Filter
        // _buildFilterHeader(context),
        // const SizedBox(height: 14),

        // ── Container 1: Last 14 days / Selected Period Days (Image 2 Top)
        _buildDaysSection(context, reversedDays),
        const SizedBox(height: 16),

        // ── Container 2: Leave & regularisation Metrics (Image 3 - Leave & regularisation)
        // Commented out: Leave & regularisation
        // _buildRequestsSection(context, leave, regularisation),
        // const SizedBox(height: 16),

        // ── Container 3: Working Hours & Summary
        _buildWorkingHoursSummary(workingHours, exceptions),
        const SizedBox(height: 16),

        // ── Container 4 & 5: Approved Leave by Type & Upcoming Absences (Image 2 Bottom)
        _buildApprovedAndUpcomingSection(context, byType, upcomingList),
        const SizedBox(height: 16),

        // ── Container 6: Leave Balances Overview
        if (leaveBalances.isNotEmpty) ...[
          _buildLeaveBalances(context, leaveBalances),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // ignore: unused_element
  Widget _buildFilterHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1B2A4A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFEAEFF5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPickFilter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F6EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Period Filter',
                            style: TextStyle(
                              color: Color(0xFF8B93A7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  filterLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1B2A4A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF8B93A7),
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  color: const Color(0xFF1B2A4A),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () => onShiftMonth(-1),
                ),
                Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  color: const Color(0xFF1B2A4A),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () => onShiftMonth(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSection(
    BuildContext context,
    List<Map<String, dynamic>> reversedDays,
  ) {
    final title = reversedDays.length == 14 ? 'Last 14 days' : 'Daily logs';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EDF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2A4A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Select a day for sessions and evidence.',
                      style: TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTab(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F6EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'View logs',
                        style: TextStyle(
                          color: primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (reversedDays.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text(
                'No attendance logs available for this period',
                style: TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
              ),
            )
          else
            _buildDaysCarousel(context, reversedDays),
        ],
      ),
    );
  }

  Widget _buildDaysCarousel(
    BuildContext context,
    List<Map<String, dynamic>> reversedDays,
  ) {
    // 2-row layout matching Image 2
    final half = (reversedDays.length / 2).ceil();
    final row1 = reversedDays.take(half).toList();
    final row2 = reversedDays.skip(half).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final day in row1)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _DayMiniCard(
                    day: day,
                    onTap: () => _showDaySheet(context, day, api, onRefresh),
                  ),
                ),
            ],
          ),
          if (row2.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (final day in row2)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _DayMiniCard(
                      day: day,
                      onTap: () => _showDaySheet(context, day, api, onRefresh),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRequestsSection(
    BuildContext context,
    Map<String, dynamic> leave,
    Map<String, dynamic> regularisation,
  ) {
    final leavePending = (leave['pending'] as num?)?.toInt() ?? 0;
    final leaveApproved = (leave['approved'] as num?)?.toInt() ?? 0;
    final leaveApprovedDays = (leave['approvedDays'] as num?)?.toInt() ?? 0;
    final leaveRejected = (leave['rejected'] as num?)?.toInt() ?? 0;

    final regPending = (regularisation['pending'] as num?)?.toInt() ?? 0;
    final regApproved = (regularisation['approved'] as num?)?.toInt() ?? 0;
    final regRejected = (regularisation['rejected'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EDF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2A4A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave & regularisation',
            style: TextStyle(
              color: Color(0xFF1B2A4A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Your requests in the selected period.',
            style: TextStyle(
              color: Color(0xFF8B93A7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _ReqMetricCard(
                  label: 'My pending',
                  count: leavePending,
                  sublabel: null,
                  icon: Icons.hourglass_top_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFFF6E5),
                  onTap: () => onTab(2),
                ),
                const SizedBox(width: 8),
                _ReqMetricCard(
                  label: 'Leave approved',
                  count: leaveApproved,
                  sublabel:
                      '$leaveApprovedDays ${leaveApprovedDays == 1 ? 'day' : 'days'}',
                  icon: Icons.event_available_rounded,
                  iconColor: const Color(0xFF1B7F56),
                  iconBg: const Color(0xFFE7F6EE),
                  onTap: () => onTab(2),
                ),
                const SizedBox(width: 8),
                _ReqMetricCard(
                  label: 'Leave rejected',
                  count: leaveRejected,
                  sublabel: null,
                  icon: Icons.event_busy_rounded,
                  iconColor: const Color(0xFFE15B64),
                  iconBg: const Color(0xFFFDECEC),
                  onTap: () => onTab(2),
                ),
                const SizedBox(width: 8),
                _ReqMetricCard(
                  label: 'Correction pend.',
                  count: regPending,
                  sublabel: null,
                  icon: Icons.pending_actions_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFFF6E5),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CorrectionPage(api: api)),
                  ),
                ),
                const SizedBox(width: 8),
                _ReqMetricCard(
                  label: 'Correction appr.',
                  count: regApproved,
                  sublabel: null,
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF1B7F56),
                  iconBg: const Color(0xFFE7F6EE),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CorrectionPage(api: api)),
                  ),
                ),
                const SizedBox(width: 8),
                _ReqMetricCard(
                  label: 'Correction rej.',
                  count: regRejected,
                  sublabel: null,
                  icon: Icons.cancel_outlined,
                  iconColor: const Color(0xFFE15B64),
                  iconBg: const Color(0xFFFDECEC),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CorrectionPage(api: api)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursSummary(
    Map<String, dynamic> workingHours,
    Map<String, dynamic> exceptions,
  ) {
    final totalMin = (workingHours['totalMinutes'] as num?)?.toInt() ?? 0;
    final avgMin = (workingHours['averageMinutes'] as num?)?.toInt() ?? 0;
    final overtimeMin = (workingHours['overtimeMinutes'] as num?)?.toInt() ?? 0;
    final lateCount = (exceptions['late'] as num?)?.toInt() ?? 0;
    final missingCheckout =
        (exceptions['missingCheckout'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EDF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2A4A),
            blurRadius: 18,
            offset: Offset(0, 6),
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.timelapse_rounded,
                  color: Color(0xFF3B82F6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Working hours & exceptions',
                      style: TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Total, daily averages and attendance exceptions',
                      style: TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
                child: _miniStatTile(
                  label: 'Total Hours',
                  value: _formatMinutes(totalMin),
                  color: const Color(0xFF1B7F56),
                  bg: const Color(0xFFE7F6EE),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStatTile(
                  label: 'Daily Average',
                  value: _formatMinutes(avgMin),
                  color: const Color(0xFF3B82F6),
                  bg: const Color(0xFFEFF6FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniStatTile(
                  label: 'Late Arrivals',
                  value: '$lateCount',
                  color: lateCount > 0
                      ? const Color(0xFFD97706)
                      : const Color(0xFF6E7C8A),
                  bg: lateCount > 0
                      ? const Color(0xFFFFF6E5)
                      : const Color(0xFFF4F6F9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStatTile(
                  label: 'Missing Checkout',
                  value: '$missingCheckout',
                  color: missingCheckout > 0
                      ? const Color(0xFFE15B64)
                      : const Color(0xFF6E7C8A),
                  bg: missingCheckout > 0
                      ? const Color(0xFFFDECEC)
                      : const Color(0xFFF4F6F9),
                ),
              ),
              if (overtimeMin > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStatTile(
                    label: 'Overtime',
                    value: _formatMinutes(overtimeMin),
                    color: const Color(0xFF8B5CF6),
                    bg: const Color(0xFFF5F3FF),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStatTile({
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6E7C8A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedAndUpcomingSection(
    BuildContext context,
    List<Map<String, dynamic>> byType,
    List<Map<String, dynamic>> upcomingList,
  ) {
    if (upcomingList.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        /*
        // Commented out: Approved leave by type (Image 2)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE9EDF3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A1B2A4A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
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
                          'Approved leave by type',
                          style: TextStyle(
                            color: Color(0xFF1B2A4A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Days in period',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.dashboard_customize_outlined,
                    color: Colors.grey.shade400,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (byType.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F4EB),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Icon(
                          Icons.inbox_outlined,
                          color: Color(0xFF8B93A7),
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No data for this period',
                        style: TextStyle(
                          color: Color(0xFF6E7C8A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (final item in byType)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              item['name']?.toString() ?? 'Leave',
                              style: const TextStyle(
                                color: Color(0xFF1B2A4A),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${item['count'] ?? 0} days',
                              style: const TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
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
        const SizedBox(height: 16),
        */

        // Upcoming absences
        _UpcomingAbsencesCard(
          upcoming: upcomingList,
          onOpenCalendar: () => onTab(2),
        ),
      ],
    );
  }

  Widget _buildLeaveBalances(
    BuildContext context,
    List<Map<String, dynamic>> balances,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EDF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2A4A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
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
                      'Leave Balances',
                      style: TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Available allowance for current year',
                      style: TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onTab(2),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Apply Leave',
                    style: TextStyle(
                      color: primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final item in balances)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildLeaveBalanceChip(item),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceChip(Map<String, dynamic> item) {
    final leaveType = (item['leaveType'] is Map)
        ? Map<String, dynamic>.from(item['leaveType'] as Map)
        : <String, dynamic>{};
    final code = leaveType['code']?.toString() ?? 'LV';
    final name = leaveType['name']?.toString() ?? 'Leave';
    final colorHex = leaveType['color']?.toString() ?? '#3b82f6';
    final color = _hexToColor(colorHex);
    final available = (item['available'] as num?)?.toDouble() ?? 0;
    final entitled = (item['entitled'] as num?)?.toDouble() ?? 0;
    final balance = (item['balance'] as num?)?.toDouble() ?? 0;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
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
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  available.toStringAsFixed(
                    available.truncateToDouble() == available ? 0 : 1,
                  ),
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'avail.',
                  style: TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Balance: ${balance.toStringAsFixed(0)} / ${entitled.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Color(0xFF6E7C8A),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Day Mini Card (Image 2 Top Section Day Grid Item)
// ─────────────────────────────────────────────────────────────
class _DayMiniCard extends StatelessWidget {
  final Map<String, dynamic> day;
  final VoidCallback onTap;

  const _DayMiniCard({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = day['date']?.toString() ?? '';
    final dt = DateTime.tryParse(dateStr);
    final dayLabel = dt != null ? _formatDayLabel(dt) : dateStr;

    final status = day['status']?.toString().toUpperCase() ?? 'ABSENT';
    final isLate = day['isLate'] == true;
    final netMinutes = (day['netMinutes'] as num?)?.toInt() ?? 0;
    final grossMinutes = (day['grossMinutes'] as num?)?.toInt() ?? 0;
    final effectiveMinutes = netMinutes > 0 ? netMinutes : grossMinutes;

    final badge = _dayStatusBadge(status: status, isLate: isLate);

    String durationText = '—';
    if (status == 'PRESENT') {
      final h = effectiveMinutes ~/ 60;
      final m = effectiveMinutes % 60;
      durationText = '${h}h ${m}m';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 106,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1B2A4A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badge.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: badge.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      badge.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: badge.textColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                durationText,
                style: const TextStyle(
                  color: Color(0xFF4A5568),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadgeSpec {
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color dotColor;
  const _StatusBadgeSpec({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.dotColor,
  });
}

_StatusBadgeSpec _dayStatusBadge({
  required String status,
  required bool isLate,
}) {
  if (status == 'WEEKEND') {
    return const _StatusBadgeSpec(
      label: 'Weekend',
      bgColor: Color(0xFFF6F4EB),
      textColor: Color(0xFF716E5A),
      dotColor: Color(0xFF8B8775),
    );
  }
  if (status == 'HOLIDAY') {
    return const _StatusBadgeSpec(
      label: 'Holiday',
      bgColor: Color(0xFFF3F0FF),
      textColor: Color(0xFF6B46C1),
      dotColor: Color(0xFF7C6BF2),
    );
  }
  if (status == 'ON_LEAVE' || status == 'LEAVE') {
    return const _StatusBadgeSpec(
      label: 'On Leave',
      bgColor: Color(0xFFEFF6FF),
      textColor: Color(0xFF2563EB),
      dotColor: Color(0xFF3B82F6),
    );
  }
  if (status == 'PRESENT') {
    if (isLate) {
      return const _StatusBadgeSpec(
        label: 'Late',
        bgColor: Color(0xFFFFF6E5),
        textColor: Color(0xFFC05621),
        dotColor: Color(0xFFD97706),
      );
    }
    return const _StatusBadgeSpec(
      label: 'Present',
      bgColor: Color(0xFFE7F6EE),
      textColor: Color(0xFF1B7F56),
      dotColor: Color(0xFF1B7F56),
    );
  }
  return const _StatusBadgeSpec(
    label: 'Absent',
    bgColor: Color(0xFFFDECEC),
    textColor: Color(0xFFE15B64),
    dotColor: Color(0xFFE15B64),
  );
}

// ─────────────────────────────────────────────────────────────
// Leave & Regularisation Request Metric Card (Image 2 Middle)
// ─────────────────────────────────────────────────────────────
class _ReqMetricCard extends StatelessWidget {
  final String label;
  final int count;
  final String? sublabel;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _ReqMetricCard({
    required this.label,
    required this.count,
    required this.sublabel,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 104,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6E7C8A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 14, color: iconColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFF1B2A4A),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              if (sublabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  sublabel!,
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Upcoming Absences Card (Image 2 Bottom-Right)
// ─────────────────────────────────────────────────────────────
class _UpcomingAbsencesCard extends StatelessWidget {
  final List<Map<String, dynamic>> upcoming;
  final VoidCallback onOpenCalendar;

  const _UpcomingAbsencesCard({
    required this.upcoming,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EDF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2A4A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
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
                      'Upcoming absences',
                      style: TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Approved and pending leave starting in next 14 days.',
                      style: TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onOpenCalendar,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Open calendar',
                    style: TextStyle(
                      color: Color(0xFFC05621),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (upcoming.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                'No upcoming absences scheduled',
                style: TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcoming.length,
              separatorBuilder: (_, __) => const Divider(
                height: 18,
                thickness: 0.8,
                color: Color(0xFFF0F3F7),
              ),
              itemBuilder: (context, i) {
                final item = upcoming[i];
                final name = item['employeeName']?.toString() ?? 'Employee';
                final leaveType = item['leaveType']?.toString() ?? 'Leave';
                final days = item['days']?.toString() ?? '1';
                final start = item['startDate']?.toString() ?? '';
                final dt = DateTime.tryParse(start);
                final dateText = dt != null
                    ? '${dt.day} ${_shortMonth(dt.month)}'
                    : start;
                final status =
                    item['status']?.toString().toUpperCase() ?? 'PENDING';
                final isApproved = status == 'APPROVED';

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Color(0xFF1B2A4A),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$leaveType · $dateText · $days ${days == '1' ? 'day' : 'days'}',
                            style: const TextStyle(
                              color: Color(0xFF6E7C8A),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? const Color(0xFFE7F6EE)
                            : const Color(0xFFFFF6E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isApproved
                                  ? const Color(0xFF1B7F56)
                                  : const Color(0xFFD97706),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isApproved ? 'Approved' : 'Pending',
                            style: TextStyle(
                              color: isApproved
                                  ? const Color(0xFF1B7F56)
                                  : const Color(0xFFD97706),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Day Details Sheet (Opened when tapping any day card)
// ─────────────────────────────────────────────────────────────
void _showDaySheet(
  BuildContext context,
  Map<String, dynamic> day,
  Api api,
  VoidCallback onRefresh,
) {
  final dateStr = day['date']?.toString() ?? '';
  final dt = DateTime.tryParse(dateStr);
  final formattedDate = dt != null
      ? '${_shortDay(dt.weekday)}, ${dt.day} ${_shortMonth(dt.month)} ${dt.year}'
      : dateStr;

  final status = day['status']?.toString().toUpperCase() ?? 'ABSENT';
  final isLate = day['isLate'] == true;
  final lateMin = (day['lateMinutes'] as num?)?.toInt() ?? 0;
  final grossMin = (day['grossMinutes'] as num?)?.toInt() ?? 0;
  final netMin = (day['netMinutes'] as num?)?.toInt() ?? 0;
  final breakMin = (day['breakMinutes'] as num?)?.toInt() ?? 0;
  final sessionsCount = (day['sessionsCount'] as num?)?.toInt() ?? 0;
  final completedSessions = (day['completedSessions'] as num?)?.toInt() ?? 0;

  final firstIn = day['firstInAt']?.toString();
  final lastOut = day['lastOutAt']?.toString();
  final firstInDt = firstIn != null
      ? DateTime.tryParse(firstIn)?.toLocal()
      : null;
  final lastOutDt = lastOut != null
      ? DateTime.tryParse(lastOut)?.toLocal()
      : null;

  final exceptions = (day['exceptions'] is List)
      ? List<dynamic>.from(
          day['exceptions'] as List,
        ).map((e) => e.toString()).toList()
      : <String>[];

  final badge = _dayStatusBadge(status: status, isLate: isLate);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Attendance & session details',
                        style: TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: badge.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: badge.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        badge.label,
                        style: TextStyle(
                          color: badge.textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Timing overview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _timeCol(
                      'First Check-In',
                      firstInDt != null
                          ? '${firstInDt.hour.toString().padLeft(2, '0')}:${firstInDt.minute.toString().padLeft(2, '0')}'
                          : '—',
                      Icons.login_rounded,
                      const Color(0xFF1B7F56),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: _timeCol(
                      'Last Check-Out',
                      lastOutDt != null
                          ? '${lastOutDt.hour.toString().padLeft(2, '0')}:${lastOutDt.minute.toString().padLeft(2, '0')}'
                          : '—',
                      Icons.logout_rounded,
                      const Color(0xFFC05621),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Hours breakdown
            Row(
              children: [
                Expanded(
                  child: _infoBox('Gross Hours', _formatMinutes(grossMin)),
                ),
                const SizedBox(width: 8),
                Expanded(child: _infoBox('Net Hours', _formatMinutes(netMin))),
                const SizedBox(width: 8),
                Expanded(
                  child: _infoBox(
                    breakMin > 0 ? 'Break' : 'Sessions',
                    breakMin > 0
                        ? _formatMinutes(breakMin)
                        : '$completedSessions/$sessionsCount',
                  ),
                ),
              ],
            ),
            if (isLate || lateMin > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Late arrival detected: $lateMin minutes delayed.',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (exceptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: exceptions.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.replaceAll('_', ' '),
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B2A4A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CorrectionPage(api: api),
                        ),
                      ).then((_) => onRefresh());
                    },
                    child: const Text(
                      'Raise Correction',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget _timeCol(String label, String value, IconData icon, Color color) {
  return Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B93A7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFF1B2A4A),
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

Widget _infoBox(String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6E7C8A),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1B2A4A),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Formatters & Helpers
// ─────────────────────────────────────────────────────────────
String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0h 0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}

String _shortMonth(int month) {
  const m = [
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
  if (month < 1 || month > 12) return '';
  return m[month - 1];
}

String _shortDay(int weekday) {
  const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (weekday < 1 || weekday > 7) return '';
  return d[weekday - 1];
}

String _formatDayLabel(DateTime dt) {
  return '${_shortDay(dt.weekday)} ${dt.day} ${_shortMonth(dt.month)}';
}

Color _hexToColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.tryParse(buffer.toString(), radix: 16) ?? 0xFF3B82F6);
}

// ─────────────────────────────────────────────────────────────
// Fallback Mock Dashboard Data (Exact JSON from user API)
// ─────────────────────────────────────────────────────────────
Json _mockDashboardData(DateTime from, DateTime to) {
  return {
    "scope": "SELF",
    "from": dateOnly(from),
    "to": dateOnly(to),
    "headcount": {
      "total": 1,
      "active": 1,
      "inactive": 0,
      "newJoiners": 0,
      "byDepartment": [
        {"name": "Engineering", "count": 1},
      ],
      "byDesignation": [
        {"name": "Software Engineer", "count": 1},
      ],
    },
    "attendanceToday": {
      "total": 1,
      "present": 0,
      "checkedIn": 0,
      "notCheckedIn": 0,
      "absent": 0,
      "onLeave": 0,
      "late": 0,
      "nonWorking": 1,
    },
    "workingHours": {
      "totalMinutes": 4948,
      "averageMinutes": 381,
      "overtimeMinutes": 0,
      "trend": [
        {
          "date": "2026-10-01",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-02",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-03",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-04",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-05",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-06",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-07",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-08",
          "totalMinutes": 499,
          "employees": 1,
          "averageMinutes": 499,
          "late": 0,
        },
        {
          "date": "2026-10-09",
          "totalMinutes": 498,
          "employees": 1,
          "averageMinutes": 498,
          "late": 0,
        },
        {
          "date": "2026-10-10",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-11",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-12",
          "totalMinutes": 497,
          "employees": 1,
          "averageMinutes": 497,
          "late": 0,
        },
        {
          "date": "2026-10-13",
          "totalMinutes": 496,
          "employees": 1,
          "averageMinutes": 496,
          "late": 0,
        },
        {
          "date": "2026-10-14",
          "totalMinutes": 495,
          "employees": 1,
          "averageMinutes": 495,
          "late": 0,
        },
        {
          "date": "2026-10-15",
          "totalMinutes": 494,
          "employees": 1,
          "averageMinutes": 494,
          "late": 0,
        },
        {
          "date": "2026-10-16",
          "totalMinutes": 493,
          "employees": 1,
          "averageMinutes": 493,
          "late": 0,
        },
        {
          "date": "2026-10-17",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-18",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
        {
          "date": "2026-10-19",
          "totalMinutes": 492,
          "employees": 1,
          "averageMinutes": 492,
          "late": 0,
        },
        {
          "date": "2026-10-20",
          "totalMinutes": 491,
          "employees": 1,
          "averageMinutes": 491,
          "late": 0,
        },
        {
          "date": "2026-10-21",
          "totalMinutes": 490,
          "employees": 1,
          "averageMinutes": 490,
          "late": 0,
        },
        {
          "date": "2026-10-22",
          "totalMinutes": 1,
          "employees": 1,
          "averageMinutes": 1,
          "late": 1,
        },
        {
          "date": "2026-10-23",
          "totalMinutes": 1,
          "employees": 1,
          "averageMinutes": 1,
          "late": 1,
        },
        {
          "date": "2026-10-24",
          "totalMinutes": 1,
          "employees": 1,
          "averageMinutes": 1,
          "late": 1,
        },
        {
          "date": "2026-10-25",
          "totalMinutes": 0,
          "employees": 0,
          "averageMinutes": 0,
          "late": 0,
        },
      ],
    },
    "exceptions": {
      "missingCheckout": 0,
      "late": 3,
      "underHours": 0,
      "pendingEvidenceReview": 0,
    },
    "leave": {
      "pending": 2,
      "approved": 0,
      "rejected": 0,
      "approvedDays": 0,
      "byType": [],
      "upcoming": [
        {
          "id": "878bfb00-558d-408d-874b-60fc1cbb52ee",
          "startDate": "2026-10-26",
          "endDate": "2026-10-26",
          "days": 1,
          "status": "APPROVED",
          "leaveType": "Casual Leave",
          "employeeId": "ffe7154f-ba0e-4988-84a5-320bbd6bac53",
          "employeeName": "Arun Kumar",
        },
        {
          "id": "88384c8e-dda0-4b9e-a7a0-edc437cdd67f",
          "startDate": "2026-10-27",
          "endDate": "2026-10-27",
          "days": 1,
          "status": "PENDING",
          "leaveType": "Casual Leave",
          "employeeId": "ffe7154f-ba0e-4988-84a5-320bbd6bac53",
          "employeeName": "Arun Kumar",
        },
        {
          "id": "be10c657-0411-4cd2-976e-58b499781f0e",
          "startDate": "2026-10-28",
          "endDate": "2026-10-28",
          "days": 1,
          "status": "PENDING",
          "leaveType": "Casual Leave",
          "employeeId": "ffe7154f-ba0e-4988-84a5-320bbd6bac53",
          "employeeName": "Arun Kumar",
        },
      ],
    },
    "regularisation": {"pending": 0, "approved": 0, "rejected": 0},
    "personal": {
      "employee": {
        "id": "ffe7154f-ba0e-4988-84a5-320bbd6bac53",
        "employeeCode": "DEMO-E01",
        "fullName": "Arun Kumar",
        "email": "employee@giraffai.in",
        "status": "ACTIVE",
      },
      "days": [
        {
          "date": "2026-10-12",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-12T03:57:00.000Z",
          "lastOutAt": "2026-10-12T12:59:00.000Z",
          "sessionsCount": 2,
          "completedSessions": 2,
          "grossMinutes": 497,
          "netMinutes": 497,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-13",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-13T03:56:00.000Z",
          "lastOutAt": "2026-10-13T12:57:00.000Z",
          "sessionsCount": 2,
          "completedSessions": 2,
          "grossMinutes": 496,
          "netMinutes": 496,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-14",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-14T03:55:00.000Z",
          "lastOutAt": "2026-10-14T12:55:00.000Z",
          "sessionsCount": 2,
          "completedSessions": 2,
          "grossMinutes": 495,
          "netMinutes": 495,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-15",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-15T03:54:00.000Z",
          "lastOutAt": "2026-10-15T12:53:00.000Z",
          "sessionsCount": 2,
          "completedSessions": 2,
          "grossMinutes": 494,
          "netMinutes": 494,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-16",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-16T03:53:00.000Z",
          "lastOutAt": "2026-10-16T12:51:00.000Z",
          "sessionsCount": 2,
          "completedSessions": 2,
          "grossMinutes": 493,
          "netMinutes": 493,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-17",
          "status": "WEEKEND",
          "leaveType": null,
          "holiday": null,
          "firstInAt": null,
          "lastOutAt": null,
          "sessionsCount": 0,
          "completedSessions": 0,
          "grossMinutes": 0,
          "netMinutes": 0,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-18",
          "status": "WEEKEND",
          "leaveType": null,
          "holiday": null,
          "firstInAt": null,
          "lastOutAt": null,
          "sessionsCount": 0,
          "completedSessions": 0,
          "grossMinutes": 0,
          "netMinutes": 0,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-19",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-19T03:52:00.000Z",
          "lastOutAt": "2026-10-19T12:49:00.000Z",
          "sessionsCount": 2,
          "completedSessions": 2,
          "grossMinutes": 492,
          "netMinutes": 492,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-20",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-20T03:51:00.000Z",
          "lastOutAt": "2026-10-20T12:47:00.000Z",
          "sessionsCount": 2,
          "completedSessions": 2,
          "grossMinutes": 491,
          "netMinutes": 491,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-21",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-21T03:50:00.000Z",
          "lastOutAt": "2026-10-21T12:45:00.000Z",
          "sessionsCount": 2,
          "completedSessions": 2,
          "grossMinutes": 490,
          "netMinutes": 490,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
        {
          "date": "2026-10-22",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-22T14:08:22.802Z",
          "lastOutAt": "2026-10-22T14:10:02.178Z",
          "sessionsCount": 1,
          "completedSessions": 1,
          "grossMinutes": 1,
          "netMinutes": 1,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": true,
          "lateMinutes": 608,
          "hasOpenSession": false,
          "exceptions": ["LATE_ARRIVAL"],
          "adjusted": false,
        },
        {
          "date": "2026-10-23",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-23T10:02:22.308Z",
          "lastOutAt": "2026-10-23T10:03:24.778Z",
          "sessionsCount": 1,
          "completedSessions": 1,
          "grossMinutes": 1,
          "netMinutes": 1,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": true,
          "lateMinutes": 362,
          "hasOpenSession": false,
          "exceptions": ["LATE_ARRIVAL"],
          "adjusted": false,
        },
        {
          "date": "2026-10-24",
          "status": "PRESENT",
          "leaveType": null,
          "holiday": null,
          "firstInAt": "2026-10-24T17:42:44.626Z",
          "lastOutAt": "2026-10-24T17:43:48.154Z",
          "sessionsCount": 1,
          "completedSessions": 1,
          "grossMinutes": 1,
          "netMinutes": 1,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": true,
          "lateMinutes": 822,
          "hasOpenSession": false,
          "exceptions": ["LATE_ARRIVAL"],
          "adjusted": false,
        },
        {
          "date": "2026-10-25",
          "status": "WEEKEND",
          "leaveType": null,
          "holiday": null,
          "firstInAt": null,
          "lastOutAt": null,
          "sessionsCount": 0,
          "completedSessions": 0,
          "grossMinutes": 0,
          "netMinutes": 0,
          "breakMinutes": 0,
          "overtimeMinutes": 0,
          "isLate": false,
          "lateMinutes": 0,
          "hasOpenSession": false,
          "exceptions": [],
          "adjusted": false,
        },
      ],
      "leaveBalances": [
        {
          "leaveType": {
            "id": "25eecca1-ee3e-4cb3-a728-07e35ca461d6",
            "code": "CL",
            "name": "Casual Leave",
            "color": "#3b82f6",
            "isPaid": true,
          },
          "policyId": "f6e8359d-7422-4d57-9cd8-669f40617924",
          "year": 2026,
          "entitled": 10,
          "carriedForward": 0,
          "adjustments": 0,
          "used": 1,
          "balance": 9,
          "pending": 2,
          "available": 7,
          "allowNegativeBalance": false,
          "negativeBalanceLimit": 0,
          "halfDayAllowed": true,
        },
        {
          "leaveType": {
            "id": "607085bb-0ffb-4e0d-9ac6-89939e63f73b",
            "code": "SL",
            "name": "Sick Leave",
            "color": "#ef4444",
            "isPaid": true,
          },
          "policyId": "dfd38e0f-c94d-443a-aae6-794d730d3e42",
          "year": 2026,
          "entitled": 8,
          "carriedForward": 0,
          "adjustments": 0,
          "used": 0,
          "balance": 8,
          "pending": 0,
          "available": 8,
          "allowNegativeBalance": false,
          "negativeBalanceLimit": 0,
          "halfDayAllowed": true,
        },
        {
          "leaveType": {
            "id": "88d84137-1720-45b0-a65c-efc26039b814",
            "code": "EL",
            "name": "Earned Leave",
            "color": "#10b981",
            "isPaid": true,
          },
          "policyId": "d2c278cc-fb62-4ed4-8b08-08f5f1b27a47",
          "year": 2026,
          "entitled": 15,
          "carriedForward": 0,
          "adjustments": 0,
          "used": 0,
          "balance": 15,
          "pending": 0,
          "available": 15,
          "allowNegativeBalance": false,
          "negativeBalanceLimit": 0,
          "halfDayAllowed": true,
        },
        {
          "leaveType": {
            "id": "b86d3aa8-7cc5-4c35-8648-68a912e87721",
            "code": "LOP",
            "name": "Loss of Pay",
            "color": "#6b7280",
            "isPaid": false,
          },
          "policyId": "86996b37-92b7-4291-9fb8-a36b1635be5c",
          "year": 2026,
          "entitled": 0,
          "carriedForward": 0,
          "adjustments": 0,
          "used": 0,
          "balance": 0,
          "pending": 0,
          "available": 0,
          "allowNegativeBalance": true,
          "negativeBalanceLimit": 30,
          "halfDayAllowed": true,
        },
      ],
    },
  };
}

String _requestWhen(Json row) {
  final start = DateTime.tryParse(row['start']?.toString() ?? '');
  final end = DateTime.tryParse(row['end']?.toString() ?? '');
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
  final type = row['type_name']?.toString() ?? 'Request';
  if (start == null) return type;
  String day(DateTime value) => '${value.day} ${months[value.month - 1]}';
  if (end == null || dateOnly(start) == dateOnly(end)) {
    return '$type  ·  ${day(start)} ${start.year}';
  }
  return '$type  ·  ${day(start)} – ${day(end)} ${end.year}';
}

// ignore: unused_element
class _BirthdayBanner extends StatelessWidget {
  final VoidCallback onWish;
  const _BirthdayBanner({required this.onWish});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFF8F2FF), Color(0xFFF3ECFF), Color(0xFFEDE4FF)],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          const Text('🎂', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Today is\n',
                        style: TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: "Priya's Birthday!",
                        style: TextStyle(
                          color: Color(0xFF5B4DFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Let's wish them a fantastic year ahead!",
                  style: TextStyle(color: Color(0xFF8B93A7), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF5B4DFF),
                      elevation: 0,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onWish,
                    child: const Text(
                      'Send Wish',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text('🎈', style: TextStyle(fontSize: 28)),
        ],
      ),
    ),
  );
}

class _PendingSheet extends StatefulWidget {
  final List<Json> requests;
  final ValueChanged<Json> onView;
  final VoidCallback onRemind;
  const _PendingSheet({
    required this.requests,
    required this.onView,
    required this.onRemind,
  });
  @override
  State<_PendingSheet> createState() => _PendingSheetState();
}

class _PendingSheetState extends State<_PendingSheet> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final request = widget.requests[index];
    final many = widget.requests.length > 1;
    final reason = request['reason']?.toString().trim() ?? '';
    final days = request['days'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFFDECEC),
                  child: Icon(
                    Icons.schedule,
                    color: Color(0xFFE07A5F),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        many
                            ? 'Request ${index + 1} of ${widget.requests.length}'
                            : '1 request pending',
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Your manager’s approval is pending.',
                        style: TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (many) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: index == 0
                        ? null
                        : () => setState(() => index -= 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: index == widget.requests.length - 1
                        ? null
                        : () => setState(() => index += 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _requestWhen(request),
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (days != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$days day${days == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Color(0xFF6E7C8A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        reason,
                        style: const TextStyle(
                          color: Color(0xFF6E7C8A),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE07A5F),
                      side: const BorderSide(color: Color(0xFFF0C2B8)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => widget.onView(request),
                    child: const Text('View request'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE07A5F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: widget.onRemind,
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Remind manager'),
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

class DashMood {
  final String greeting;
  final String message;
  final String image;
  final Color card;
  const DashMood(this.greeting, this.message, this.image, this.card);
}

DashMood dashMood(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) {
    return const DashMood(
      'Good Morning',
      'Have a great day with full of productivity and good vibes!',
      'assets/dash_morning.png',
      Color(0xFFFFF3E2),
    );
  }
  if (hour >= 12 && hour < 17) {
    return const DashMood(
      'Good Afternoon',
      'Hope your afternoon stays bright and productive.',
      'assets/dash_afternoon.png',
      Color(0xFFE7F6EE),
    );
  }
  return const DashMood(
    'Good Evening',
    'The day is winding down. Finish strong and rest well.',
    'assets/dash_evening.png',
    Color(0xFFEDE7F8),
  );
}

String friendlyDay(DateTime d) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
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
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

final Map<String, String> _addressCache = {};

String _formatEventTime(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return '--:--';
  final dt = DateTime.tryParse(timeStr)?.toLocal();
  if (dt == null) return timeStr;
  final hour = dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = hour >= 12 ? 'PM' : 'AM';
  final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$h12:$minute $ampm';
}

class _EventLocationWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const _EventLocationWidget({this.latitude, this.longitude});

  @override
  State<_EventLocationWidget> createState() => _EventLocationWidgetState();
}

class _EventLocationWidgetState extends State<_EventLocationWidget> {
  String? _resolvedAddress;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _EventLocationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final lat = widget.latitude;
    final lon = widget.longitude;
    if (lat == null || lon == null) return;
    final key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    if (_addressCache.containsKey(key)) {
      if (mounted) setState(() => _resolvedAddress = _addressCache[key]);
      return;
    }

    try {
      final res = await resolveLocationName(
        lat,
        lon,
      ).timeout(const Duration(seconds: 2));
      if (res.isNotEmpty) {
        _addressCache[key] = res;
        if (mounted) setState(() => _resolvedAddress = res);
        return;
      }
    } catch (_) {}

    final fallback = '${lat.toStringAsFixed(4)}°, ${lon.toStringAsFixed(4)}°';
    _addressCache[key] = fallback;
    if (mounted) setState(() => _resolvedAddress = fallback);
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latitude;
    final lon = widget.longitude;
    final coords = (lat != null && lon != null)
        ? '${lat.toStringAsFixed(4)}°, ${lon.toStringAsFixed(4)}°'
        : null;
    final text = _resolvedAddress ?? coords ?? 'Location recorded';

    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: Color(0xFF6E7C8A),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatFullDate(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return '';
  final dt = DateTime.tryParse(timeStr)?.toLocal();
  if (dt == null) return timeStr;
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
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
  return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _formatExactTime(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return '—';
  final dt = DateTime.tryParse(timeStr)?.toLocal();
  if (dt == null) return timeStr;
  final hour = dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final second = dt.second.toString().padLeft(2, '0');
  final ampm = hour >= 12 ? 'PM' : 'AM';
  final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$h12:$minute:$second $ampm';
}

class _TodayActivityContainer extends StatelessWidget {
  final Map<String, dynamic>? todayData;
  final List<Map<String, dynamic>> events;
  final bool isCheckedIn;
  final int sessionsToday;
  final VoidCallback onViewDetails;

  const _TodayActivityContainer({
    required this.todayData,
    required this.events,
    required this.isCheckedIn,
    required this.sessionsToday,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1B2A4A);
    const soft = Color(0xFF6E7C8A);
    const border = Color(0xFFE8E2D9);
    const green = Color(0xFF16A34A);
    const greenBg = Color(0xFFE7F6EE);

    final completedSessions =
        (todayData?['completedSessions'] as num?)?.toInt() ?? 0;
    final sessionsCount =
        (todayData?['sessionsCount'] as num?)?.toInt() ??
        (sessionsToday > 0
            ? sessionsToday
            : (completedSessions + (isCheckedIn ? 1 : 0)));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showTodayActivitiesBottomSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A1B2A4A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: greenBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1FAE5), width: 1),
                ),
                child: const Icon(
                  Icons.history_toggle_off_rounded,
                  color: Color(0xFF16A34A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "See Today's Activities",
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isCheckedIn
                                ? green
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCheckedIn ? 'Clocked In' : 'Clocked Out',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isCheckedIn ? green : soft,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '•',
                          style: TextStyle(fontSize: 11, color: soft),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$sessionsCount ${sessionsCount == 1 ? 'session' : 'sessions'} • ${events.length} ${events.length == 1 ? 'punch' : 'punches'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: soft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTodayActivitiesBottomSheet(BuildContext context) {
    const ink = Color(0xFF1B2A4A);
    const soft = Color(0xFF6E7C8A);
    const green = Color(0xFF16A34A);
    const greenBg = Color(0xFFE7F6EE);
    const amber = Color(0xFFEA580C);
    const amberBg = Color(0xFFFFF1E8);

    final completedSessions =
        (todayData?['completedSessions'] as num?)?.toInt() ?? 0;
    final sessionsCount =
        (todayData?['sessionsCount'] as num?)?.toInt() ??
        (sessionsToday > 0
            ? sessionsToday
            : (completedSessions + (isCheckedIn ? 1 : 0)));
    final netMinutes = (todayData?['netMinutes'] as num?)?.toInt() ?? 0;
    final isLate = todayData?['isLate'] == true;
    final lateMinutes = (todayData?['lateMinutes'] as num?)?.toInt() ?? 0;
    final hasOpenSession = todayData?['hasOpenSession'] == true || isCheckedIn;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: greenBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_toggle_off_rounded,
                    color: Color(0xFF1B8F6E),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Activity & Punches",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$sessionsCount ${sessionsCount == 1 ? 'session' : 'sessions'} • ${events.length} ${events.length == 1 ? 'punch' : 'punches'} recorded',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: soft,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCheckedIn
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCheckedIn
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isCheckedIn ? green : const Color(0xFF64748B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isCheckedIn ? 'Clocked In' : 'Clocked Out',
                        style: TextStyle(
                          color: isCheckedIn
                              ? const Color(0xFF15803D)
                              : const Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: soft),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Stats Strip in Modal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF9F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0EBE1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sessions',
                          style: TextStyle(
                            fontSize: 11,
                            color: soft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$sessionsCount ($completedSessions done${hasOpenSession ? ', 1 open' : ''})',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 26,
                    color: const Color(0xFFE5DDD4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Net Duration',
                          style: TextStyle(
                            fontSize: 11,
                            color: soft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatMinutes(netMinutes),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 26,
                    color: const Color(0xFFE5DDD4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Arrival',
                          style: TextStyle(
                            fontSize: 11,
                            color: soft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLate ? 'Late (+${lateMinutes}m)' : 'On Time',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isLate ? const Color(0xFFB45309) : green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section Header: Punches Timeline
            Row(
              children: [
                const Icon(
                  Icons.timeline_rounded,
                  size: 16,
                  color: Color(0xFF1B8F6E),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Punch Activity Timeline',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${events.length} punches',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Events & Punches Timeline
            if (events.isNotEmpty) ...[
              for (int i = 0; i < events.length; i++) ...[
                _buildPunchEventCard(context, events[i], i, events),
                if (i < events.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
                    child: Container(
                      width: 2,
                      height: 14,
                      color: const Color(0xFFE5DDD4),
                    ),
                  ),
              ],
            ] else ...[
              if (todayData?['firstInAt'] != null)
                _buildSimplePunchCard(
                  type: 'CHECK_IN',
                  label: 'First Check In',
                  time: todayData!['firstInAt'].toString(),
                  color: green,
                  bg: greenBg,
                  icon: Icons.login_rounded,
                ),
              if (todayData?['lastOutAt'] != null) ...[
                const SizedBox(height: 8),
                _buildSimplePunchCard(
                  type: 'CHECK_OUT',
                  label: 'Last Check Out',
                  time: todayData!['lastOutAt'].toString(),
                  color: amber,
                  bg: amberBg,
                  icon: Icons.logout_rounded,
                ),
              ],
            ],

            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                onViewDetails();
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Full attendance timeline',
                      style: TextStyle(
                        color: Color(0xFF1B8F6E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF1B8F6E),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Dismiss Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPunchEventCard(
    BuildContext context,
    Map<String, dynamic> event,
    int index,
    List<Map<String, dynamic>> allEvents,
  ) {
    const ink = Color(0xFF1B2A4A);
    const green = Color(0xFF16A34A);
    const greenBg = Color(0xFFE7F6EE);
    const amber = Color(0xFFEA580C);
    const amberBg = Color(0xFFFFF1E8);

    final eventType =
        event['eventType']?.toString().toUpperCase() ?? 'CHECK_IN';
    final isIn = eventType == 'CHECK_IN';
    final serverTime =
        event['serverTime']?.toString() ?? event['deviceTime']?.toString();
    final timeStr = _formatEventTime(serverTime);
    final lat = (event['latitude'] as num?)?.toDouble();
    final lon = (event['longitude'] as num?)?.toDouble();
    final hasPhoto = event['hasPhoto'] == true;

    // Calculate session number for this event
    int sessionIndex = 1;
    for (int j = 0; j <= index; j++) {
      if (allEvents[j]['eventType']?.toString().toUpperCase() == 'CHECK_IN' &&
          j != 0 &&
          j % 2 == 0) {
        sessionIndex++;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPunchDetailsBottomSheet(context, event, sessionIndex),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isIn ? const Color(0xFFF9FDFB) : const Color(0xFFFFFBF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isIn ? const Color(0xFFD1FAE5) : const Color(0xFFFFEDD5),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isIn ? greenBg : amberBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isIn ? Icons.login_rounded : Icons.logout_rounded,
                      color: isIn ? green : amber,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isIn ? 'Check In' : 'Check Out',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isIn
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFC2410C),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isIn
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFFFED7AA),
                            ),
                          ),
                          child: Text(
                            'Session $sessionIndex',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isIn
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF9A3412),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _EventLocationWidget(latitude: lat, longitude: lon),
                  ),
                  if (hasPhoto) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 11,
                            color: Color(0xFF15803D),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Photo verified',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPunchDetailsBottomSheet(
    BuildContext context,
    Map<String, dynamic> event,
    int sessionIndex,
  ) {
    const ink = Color(0xFF1B2A4A);
    const soft = Color(0xFF6E7C8A);
    const green = Color(0xFF16A34A);
    const greenBg = Color(0xFFE7F6EE);
    const amber = Color(0xFFEA580C);
    const amberBg = Color(0xFFFFF1E8);

    final eventType =
        event['eventType']?.toString().toUpperCase() ?? 'CHECK_IN';
    final isIn = eventType == 'CHECK_IN';
    final serverTime =
        event['serverTime']?.toString() ?? event['deviceTime']?.toString();
    final deviceTime = event['deviceTime']?.toString();
    final timeStr = _formatEventTime(serverTime);
    final fullDate = _formatFullDate(serverTime);
    final source = event['source']?.toString().toUpperCase() ?? 'WEB';
    final lat = (event['latitude'] as num?)?.toDouble();
    final lon = (event['longitude'] as num?)?.toDouble();
    final accuracy = (event['accuracy'] as num?)?.toDouble();
    final hasPhoto = event['hasPhoto'] == true;
    final timezone = event['timezone']?.toString() ?? 'Asia/Kolkata';
    final reviewStatus = event['reviewStatus']?.toString() ?? 'NOT_REQUIRED';

    // Retrieve cached address if any
    String? resolvedAddress;
    if (lat != null && lon != null) {
      final key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
      resolvedAddress = _addressCache[key];
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isIn ? greenBg : amberBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isIn
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFED7AA),
                    ),
                  ),
                  child: Icon(
                    isIn ? Icons.login_rounded : Icons.logout_rounded,
                    color: isIn ? green : amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            isIn ? 'Check In Details' : 'Check Out Details',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isIn
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Session $sessionIndex',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isIn
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFC2410C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fullDate.isNotEmpty
                            ? '$fullDate • $timezone'
                            : timezone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: soft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: soft),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Hero Punch Time Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isIn
                      ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                      : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isIn
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFED7AA),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIn
                              ? 'PUNCH TIME (CHECK IN)'
                              : 'PUNCH TIME (CHECK OUT)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isIn
                                ? const Color(0xFF047857)
                                : const Color(0xFF9A3412),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isIn
                                ? const Color(0xFF065F46)
                                : const Color(0xFF7C2D12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          source == 'WEB'
                              ? Icons.laptop_mac_rounded
                              : Icons.smartphone_rounded,
                          size: 15,
                          color: ink,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          source,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Location & Coordinates Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: Color(0xFF1B8F6E),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Location & GPS Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPunchSheetDetailRow(
                    label: 'Address / Area',
                    value:
                        resolvedAddress ??
                        (lat != null && lon != null
                            ? '${lat.toStringAsFixed(4)}°, ${lon.toStringAsFixed(4)}°'
                            : 'Recorded at floor/counter'),
                  ),
                  if (lat != null && lon != null) ...[
                    const Divider(height: 14),
                    _buildPunchSheetDetailRow(
                      label: 'Coordinates',
                      value:
                          '${lat.toStringAsFixed(6)}°, ${lon.toStringAsFixed(6)}°',
                    ),
                  ],
                  if (accuracy != null && accuracy > 0) ...[
                    const Divider(height: 14),
                    _buildPunchSheetDetailRow(
                      label: 'Accuracy',
                      value: '±${accuracy.toInt()}m (High accuracy GPS)',
                      badge: '±${accuracy.toInt()}m',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Verification & Device Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Verification & Audit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPunchSheetDetailRow(
                    label: 'Photo Verified',
                    value: hasPhoto
                        ? 'Yes, selfie verified'
                        : 'No photo required',
                    isHighlight: hasPhoto,
                  ),
                  const Divider(height: 14),
                  _buildPunchSheetDetailRow(
                    label: 'Source Channel',
                    value: source == 'WEB'
                        ? 'Web Portal / Floor Terminal'
                        : 'Mobile Application',
                  ),
                  if (serverTime != null) ...[
                    const Divider(height: 14),
                    _buildPunchSheetDetailRow(
                      label: 'Server Timestamp',
                      value: _formatExactTime(serverTime),
                    ),
                  ],
                  if (deviceTime != null) ...[
                    const Divider(height: 14),
                    _buildPunchSheetDetailRow(
                      label: 'Device Timestamp',
                      value: _formatExactTime(deviceTime),
                    ),
                  ],
                  const Divider(height: 14),
                  _buildPunchSheetDetailRow(
                    label: 'Audit Status',
                    value: reviewStatus == 'NOT_REQUIRED'
                        ? 'Approved & Recorded'
                        : reviewStatus,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dismiss Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPunchSheetDetailRow({
    required String label,
    required String value,
    String? badge,
    bool isHighlight = false,
  }) {
    const ink = Color(0xFF1B2A4A);
    const soft = Color(0xFF6E7C8A);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: soft,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isHighlight ? const Color(0xFF16A34A) : ink,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimplePunchCard({
    required String type,
    required String label,
    required String time,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0EBE1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            _formatEventTime(time),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Color(0xFF1B2A4A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String image;
  final Color background;
  final VoidCallback onTap;
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.background,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  image,
                  height: 40,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
                const Spacer(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Color(0xFF8B93A7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _DashTile({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 1.5,
    shadowColor: const Color(0x331B3A4B),
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.background,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}
