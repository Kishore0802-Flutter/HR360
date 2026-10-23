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
import 'nav.dart';
import 'payslip.dart';
import 'requests.dart';
import 'tasks.dart';
import 'welcome.dart';

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
    void go(int i) => setState(() => index = i);
    final leader = api.live && api.role != null && api.role != 'employee';
    return [
      _Tab(
        'Home',
        Icons.home_outlined,
        Icons.home_rounded,
        leader
            ? RoleDashboard(api: api, onTab: go, moduleSwitch: moduleSwitch)
            : HomePage(api: api, onTab: go, moduleSwitch: moduleSwitch),
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
          RequestsPage(api: api, mode: 'approvals'),
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
  Json? data, location;
  _MonthAttendance month = _MonthAttendance.empty;
  Object? error;
  bool loading = true, busy = false, showBirthday = true;
  Timer? timer;
  DateTime received = DateTime.now();
  int ticks = 0;
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
    try {
      final r = await widget.api.get('/attendance/status');
      var summary = _MonthAttendance.empty;
      try {
        summary = await _monthAttendance(widget.api, r);
      } catch (_) {}
      final homeProfile = r['profile'];
      if (homeProfile is Map && widget.api.profile == null) {
        widget.api.profile = Map<String, dynamic>.from(homeProfile);
      }
      if (mounted) {
        setState(() {
          data = r;
          month = summary;
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
    final requests = List<Json>.from(month.waiting);
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
    final d = data!, p = d['profile'] as Json, active = d['active'] as Json?;
    final records = (d['today_records'] as List);
    final done =
        active == null &&
        records.isNotEmpty &&
        d['policy']['multiple_sessions'] != true;
    final seconds = active != null
        ? (active['seconds'] as num) +
              DateTime.now().difference(received).inSeconds +
              records
                  .where((r) => r['id'] != active['id'])
                  .fold<num>(0, (sum, r) => sum + (r['seconds'] as num))
        : records.fold<num>(0, (sum, r) => sum + (r['seconds'] as num));
    final now = tz.TZDateTime.now(tz.getLocation(officeTimezone));
    final mood = dashMood(now);
    final first = p['name'].toString().trim().split(RegExp(r'\s+')).first;
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
                    isLabelVisible: (d['unread'] as num) > 0,
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
            if (month.waiting.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PendingStrip(
                count: month.waiting.length,
                request: month.waiting.first,
                onTap: openPending,
              ),
            ],
            const SizedBox(height: 14),
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
                      if (widget.api.live) {
                        await comingSoon(
                          context,
                          'Attendance request',
                          'Regularizing attendance is on hold for now.',
                        );
                        return;
                      }
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
            if (widget.api.manager && (d['pending'] as num) > 0) ...[
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
            const SizedBox(height: 14),
            _MonthAttendanceCard(
              month: month,
              onLogs: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegularizeListPage(api: widget.api),
                  ),
                );
                if (mounted) load();
              },
            ),
            if (showBirthday) ...[
              const SizedBox(height: 14),
              _BirthdayBanner(
                onWish: () {
                  setState(() => showBirthday = false);
                  message(context, 'Wish sent.');
                },
              ),
            ],
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
  bool busy = false;
  bool loadingProfile = false;
  Object? profileError;

  @override
  void initState() {
    super.initState();
    if (widget.api.profile == null) {
      loadingProfile = true;
      loadProfile();
    }
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
    } catch (e) {
      profileError = e;
    } finally {
      if (mounted) setState(() => loadingProfile = false);
    }
  }

  Future<void> soon(String title, String detail, IconData icon) => showDialog(
    context: context,
    builder: (dialog) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F6EE),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primary, size: 26),
            ),
            const SizedBox(height: 14),
            const Text(
              'Coming soon',
              style: TextStyle(
                color: Color(0xFF1B2A4A),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8B93A7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Okay'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> taskSoon() => showDialog(
    context: context,
    builder: (dialog) => Dialog(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/profile_illustration.jpg',
            height: 168,
            width: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: Column(
              children: [
                const Text(
                  'Task Management',
                  style: TextStyle(
                    color: Color(0xFF1B2A4A),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Coming soon',
                  style: TextStyle(
                    color: primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tasks, projects and collaboration will be available in a later update.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Okay'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

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

  @override
  Widget build(BuildContext context) {
    final p = widget.api.profile;
    if (p == null) {
      if (profileError != null) return FailureView(profileError!, loadProfile);
      return const DashboardShimmer();
    }
    final name = p['name']?.toString() ?? '';
    final office = (p['office'] is Map)
        ? p['office']['name']?.toString()
        : null;
    final chips = [
      if ((p['department']?.toString() ?? '').isNotEmpty)
        (Icons.apartment_outlined, p['department'].toString()),
      if ((p['designation']?.toString() ?? '').isNotEmpty)
        (Icons.work_outline, p['designation'].toString()),
      if (office != null && office.isNotEmpty)
        (Icons.location_on_outlined, office),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const Text(
          'My profile',
          style: TextStyle(
            color: Color(0xFF1B2A4A),
            fontSize: 26,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage your account and preferences',
          style: TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
        ),
        const SizedBox(height: 16),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE4DFF8),
                      child: Text(
                        _profileInitials(name),
                        style: const TextStyle(
                          color: Color(0xFF6B5BD6),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
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
                              color: Color(0xFF1B2A4A),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p['designation'] ?? 'Team member'}  ·  ID: ${p['code'] ?? p['id']}',
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
                    InkWell(
                      onTap: () => soon(
                        'Edit profile',
                        'Updating your name and photo will be available soon.',
                        Icons.edit_outlined,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: Color(0xFF1B7F56),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: Color(0xFF1B7F56),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7F8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              chip.$1,
                              size: 14,
                              color: const Color(0xFF6E7C8A),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              chip.$2,
                              style: const TextStyle(
                                color: Color(0xFF5C6770),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/profile_illustration.jpg',
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.35, 0),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _profileInfo(
                Icons.calendar_today_outlined,
                'Joined on',
                p['joined'] == null ? '—' : shortDate(p['joined'].toString()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _profileInfo(
                Icons.mail_outline,
                'Email',
                p['email']?.toString() ?? '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _ProfileHeading('Account settings'),
        const SizedBox(height: 10),
        if (widget.api.can('employees:view'))
          _setting(
            Icons.groups_outlined,
            const Color(0xFFE7F6EE),
            primary,
            'Employees',
            'Search the company directory',
            () => openRoute(
              context,
              '/team/employees',
              () => EmployeesPage(api: widget.api),
            ),
          ),
        _setting(
          Icons.person_outline,
          const Color(0xFFF3F0FF),
          const Color(0xFF7C6BF2),
          'Personal information',
          'View and update your personal details',
          () => soon(
            'Personal information',
            'Viewing and updating your details will be available soon.',
            Icons.person_outline,
          ),
        ),
        _setting(
          Icons.lock_outline,
          const Color(0xFFE7F6EE),
          primary,
          'Update password',
          'Change your account password',
          () => soon(
            'Update password',
            'Password changes will be available soon.',
            Icons.lock_outline,
          ),
        ),
        _setting(
          Icons.palette_outlined,
          const Color(0xFFF3F0FF),
          const Color(0xFF7C6BF2),
          'Appearance',
          'Theme, language and display settings',
          () => soon(
            'Appearance',
            'Theme and language options will be available soon.',
            Icons.palette_outlined,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Light',
              style: TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        _setting(
          Icons.description_outlined,
          const Color(0xFFFDECEC),
          const Color(0xFFE15B64),
          'Documents',
          'View and manage your documents',
          () => soon(
            'Documents',
            'Your documents will be available soon.',
            Icons.description_outlined,
          ),
        ),
        _setting(
          Icons.receipt_long_outlined,
          const Color(0xFFE7F6EE),
          primary,
          'Payslip',
          'View and download your salary slips',
          () => widget.api.live
              ? soon(
                  'Payslip',
                  'Salary slips will appear here once payroll is connected.',
                  Icons.receipt_long_outlined,
                )
              : Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayslipPage(api: widget.api),
                  ),
                ),
        ),
        _setting(
          Icons.article_outlined,
          const Color(0xFFFFF1EA),
          const Color(0xFFE98462),
          'Resignation',
          'Submit your resignation request',
          () => soon(
            'Resignation',
            'Resignation requests will be available soon.',
            Icons.logout,
          ),
        ),
        _setting(
          Icons.auto_stories_outlined,
          const Color(0xFFF3F0FF),
          const Color(0xFF6C4DFF),
          'Intro screens',
          'Preview the welcome stories',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryPage(onFinish: () => Navigator.pop(context)),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: _ProfileHeading('Switch application')),
            InkWell(
              onTap: () => soon(
                'More applications',
                'Additional apps will be listed here soon.',
                Icons.apps_outlined,
              ),
              child: const Row(
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      color: primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: primary, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _appCard(
                icon: Icons.groups_outlined,
                iconColor: primary,
                iconBg: const Color(0xFFE7F6EE),
                title: 'HRMS',
                subtitle: 'Leave, Attendance, Profile and more',
                current: true,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _appCard(
                icon: Icons.fact_check_outlined,
                iconColor: const Color(0xFF7C6BF2),
                iconBg: const Color(0xFFF3F0FF),
                title: 'Task Management',
                subtitle: 'Tasks, Projects and Collaboration',
                onTap: taskSoon,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _setting(
          Icons.logout_rounded,
          const Color(0xFFFDECEC),
          const Color(0xFFE15B64),
          busy ? 'Signing out' : 'Log out',
          'Sign out of this device',
          busy ? () {} : logout,
        ),
      ],
    );
  }

  Widget _setting(
    IconData icon,
    Color bg,
    Color fg,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[trailing, const SizedBox(width: 4)],
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFC5CAD3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _appCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool current = false,
  }) => Material(
    color: current ? const Color(0xFFF3FBF7) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: current ? primary : const Color(0xFFE8EDF2)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const Spacer(),
                if (current)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Current',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFC5CAD3),
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF8B93A7),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileHeading extends StatelessWidget {
  final String text;
  const _ProfileHeading(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF1B2A4A),
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
  );
}

Widget _profileInfo(IconData icon, String label, String value) => Material(
  color: const Color(0xFFE7F6EE),
  borderRadius: BorderRadius.circular(16),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(icon, size: 16, color: primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF6E7C8A), fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1B2A4A),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

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

class _MonthAttendance {
  final int present, absent, home, leave;
  final List<Json> waiting;
  const _MonthAttendance({
    required this.present,
    required this.absent,
    required this.home,
    required this.leave,
    this.waiting = const [],
  });
  static const empty = _MonthAttendance(
    present: 0,
    absent: 0,
    home: 0,
    leave: 0,
  );
  int get total => present + absent + home + leave;
  int get percent => total == 0 ? 0 : ((present / total) * 100).round();
}

Future<_MonthAttendance> _monthAttendance(Api api, Json home) async {
  final today = DateTime.parse(home['today'].toString());
  final start = DateTime(today.year, today.month, 1);
  final from = dateOnly(start);
  final to = dateOnly(today);
  final attendance = await api.get(
    '/attendance/me',
    query: {'from': from, 'to': to},
  );
  final requests = await api.get('/leave-requests', query: {'mine': 'true'});
  final policy = home['policy'] as Map? ?? const {};
  final weekends = ((policy['weekends'] as List?) ?? const [5, 6])
      .map((day) => (day as num).toInt())
      .toSet();
  final holidays = ((policy['holidays'] as List?) ?? const [])
      .map((day) => day.toString())
      .toSet();
  final punched = items(attendance).map((row) => row['day'].toString()).toSet();
  final leaves = (attendance['leaves'] as List?) ?? const [];
  final rows = items(requests);
  bool covers(List source, String key, bool Function(Json row) match) {
    for (final item in source) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      if (!match(row)) continue;
      if (row['start'].toString().compareTo(key) <= 0 &&
          row['end'].toString().compareTo(key) >= 0) {
        return true;
      }
    }
    return false;
  }

  var present = 0, absent = 0, homeDays = 0, leaveDays = 0;
  for (
    var day = start;
    !day.isAfter(DateTime(today.year, today.month, today.day));
    day = day.add(const Duration(days: 1))
  ) {
    final key = dateOnly(day);
    if (weekends.contains(day.weekday - 1) || holidays.contains(key)) continue;
    final away = covers(
      rows,
      key,
      (row) =>
          row['kind'] == 'Attendance' &&
          row['status'] == 'Approved' &&
          row['type_name'] == 'Work from home',
    );
    final onLeave = covers(leaves, key, (_) => true);
    if (punched.contains(key)) {
      if (away) {
        homeDays++;
      } else {
        present++;
      }
    } else if (onLeave) {
      leaveDays++;
    } else if (key.compareTo(to) < 0) {
      absent++;
    }
  }
  final waiting = rows
      .where(
        (row) =>
            row['status'] == 'Pending' &&
            (row['kind'] == 'Leave' || row['kind'] == 'Attendance'),
      )
      .toList();
  return _MonthAttendance(
    present: present,
    absent: absent,
    home: homeDays,
    leave: leaveDays,
    waiting: waiting,
  );
}

class _MonthAttendanceCard extends StatelessWidget {
  final _MonthAttendance month;
  final VoidCallback onLogs;
  const _MonthAttendanceCard({required this.month, required this.onLogs});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121B2A4A),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This month',
                        style: TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Attendance',
                        style: TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: const Color(0xFFE7F6EE),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onLogs,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(12, 7, 8, 7),
                      child: Row(
                        children: [
                          Text(
                            'View logs',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: primary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 156,
              height: 156,
              child: CustomPaint(
                painter: _AttendanceRing(month),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${month.percent}%',
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Present',
                        style: TextStyle(
                          color: Color(0xFF6E7C8A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _stat(
                  const Color(0xFF1B7F56),
                  const Color(0xFFE7F6EE),
                  'Present',
                  month.present,
                ),
                const SizedBox(width: 10),
                _stat(
                  const Color(0xFF8B93A7),
                  const Color(0xFFF3F5F8),
                  'Absent',
                  month.absent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stat(
                  const Color(0xFF7C6BF2),
                  const Color(0xFFF3F0FF),
                  'Work from home',
                  month.home,
                ),
                const SizedBox(width: 10),
                _stat(
                  const Color(0xFFE0A100),
                  const Color(0xFFFFF6E0),
                  'On leave',
                  month.leave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(Color color, Color background, String label, int days) =>
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$days',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  days == 1 ? 'day' : 'days',
                  style: const TextStyle(
                    color: Color(0xFF6E7C8A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _AttendanceRing extends CustomPainter {
  final _MonthAttendance month;
  const _AttendanceRing(this.month);
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final area = (Offset.zero & size).deflate(stroke / 2 + 4);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEEF2F6);
    canvas.drawArc(area, 0, 6.28318, false, track);
    final parts = [
      (month.present, const Color(0xFF148F5B), const Color(0xFF3DCA86)),
      (month.absent, const Color(0xFFC5CAD6), const Color(0xFFDDE1E8)),
      (month.home, const Color(0xFF6D5CE7), const Color(0xFFB7AEF8)),
      (month.leave, const Color(0xFFE0A100), const Color(0xFFF3D36A)),
    ].where((part) => part.$1 > 0).toList();
    if (parts.isEmpty) return;
    final gap = parts.length == 1 ? 0.0 : 0.22;
    final usable = 6.28318 - gap * parts.length;
    var start = -1.5708 + gap / 2;
    final center = size.center(Offset.zero);
    for (final part in parts) {
      final sweep = part.$1 / month.total * usable;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [part.$2, part.$3],
        ).createShader(Rect.fromCircle(center: center, radius: size.width));
      canvas.drawArc(area, start, sweep, false, paint);
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceRing old) =>
      old.month.present != month.present ||
      old.month.absent != month.absent ||
      old.month.home != month.home ||
      old.month.leave != month.leave;
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

class _PendingStrip extends StatelessWidget {
  final int count;
  final Json request;
  final VoidCallback onTap;
  const _PendingStrip({
    required this.count,
    required this.request,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF1F3),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFFDECEC),
              child: Icon(Icons.schedule, color: Color(0xFFE07A5F), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count request${count == 1 ? '' : 's'} pending',
                    style: const TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Your manager’s approval is pending.',
                    style: TextStyle(color: Color(0xFF8B93A7), fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _requestWhen(request),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6E7C8A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF8B93A7),
                size: 18,
              ),
            ),
          ],
        ),
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
