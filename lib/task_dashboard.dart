import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'all_tasks.dart';
import 'api.dart';
import 'create_task.dart';
import 'design.dart';
import 'projects.dart';
import 'scheduled_tasks.dart';
import 'tasks.dart';

enum TaskGrain { day, week, month }

/// Tasks module home with mobile-adapted layout, filter drawer/sheet with API
/// lookups (projects, teams, assignees with search field), 10 metric stat cards,
/// priority gauge, donut charts, and grouped vertical bar charts.
class TaskDashboard extends StatefulWidget {
  final Api api;
  final ValueChanged<int> onTab;
  final int profileTab;
  final int? issuesTab;
  final Widget? moduleSwitch;

  const TaskDashboard({
    super.key,
    required this.api,
    required this.onTab,
    required this.profileTab,
    this.issuesTab,
    this.moduleSwitch,
  });

  @override
  State<TaskDashboard> createState() => _TaskDashboardState();
}

class _TaskDashboardState extends State<TaskDashboard> {
  TaskGrain grain = TaskGrain.day;
  Json? data;
  Object? error;
  bool loading = true;

  // Active filters
  String? selectedProjectId;
  String? selectedTeamId;
  String? selectedAssigneeId;
  String? selectedStatus;
  String? selectedPriority;
  String? selectedTaskType;
  DateTime? customFrom;
  DateTime? customTo;

  // Loaded options for filters
  List<Json> projectList = [];
  List<Json> teamList = [];
  List<Json> employeeList = [];

  Api get api => widget.api;
  bool get selfOnly => api.scope.toUpperCase() == 'SELF';
  bool get isAdmin =>
      api.manager ||
      (api.role ?? api.profile?['role'])?.toString().toLowerCase() == 'admin' ||
      api.scope.toUpperCase() == 'ALL';

  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _line = Color(0xFFE2E8F0);
  static const Color _taskBrown = Color(0xFFBE5E38);
  static const Color _green = Color(0xFF16A34A);
  static const Color _red = Color(0xFFDC2626);
  static const Color _amber = Color(0xFFD97706);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _teal = Color(0xFF0F766E);
  static const Color _purple = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    load();
    loadFilterOptions();
  }

  (DateTime, DateTime) get range {
    if (customFrom != null && customTo != null) {
      return (customFrom!, customTo!);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = switch (grain) {
      TaskGrain.day => today.subtract(const Duration(days: 29)),
      TaskGrain.week => today.subtract(const Duration(days: 7 * 11)),
      TaskGrain.month => DateTime(today.year, today.month - 5, 1),
    };
    return (from, today);
  }

  Future<void> load() async {
    setState(() {
      loading = data == null;
      error = null;
    });
    final (from, to) = range;
    try {
      final query = <String, dynamic>{
        'from': dateOnly(from),
        'to': dateOnly(to),
        'granularity': grain.name,
        if (selectedProjectId != null) 'projectId': selectedProjectId!,
        if (selectedTeamId != null) 'teamId': selectedTeamId!,
        if (selectedAssigneeId != null) 'assigneeId': selectedAssigneeId!,
        if (selectedStatus != null) 'status': selectedStatus!,
        if (selectedPriority != null) 'priority': selectedPriority!,
        if (selectedTaskType != null) 'taskType': selectedTaskType!,
        if (selfOnly) 'mine': 'true',
      };
      final result = await api.v1(
        'GET',
        '/reports/tasks/dashboard',
        query: query,
      );
      if (!mounted) return;
      setState(() {
        data = _asMap(result);
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

  Future<void> loadFilterOptions() async {
    try {
      final results = await Future.wait([
        api.v1(
          'GET',
          '/projects',
          query: {
            'pageSize': 50,
            'sortBy': 'name',
            'sortDir': 'asc',
            'includeArchived': true,
          },
        ).catchError((_) => null),
        api.v1(
          'GET',
          '/teams',
          query: {
            'pageSize': 100,
            'status': 'ACTIVE',
            'sortBy': 'name',
            'sortDir': 'asc',
          },
        ).catchError((_) => null),
        api.v1(
          'GET',
          '/employees/lookup',
          query: {'limit': 50},
        ).catchError((_) => null),
      ]);

      if (!mounted) return;
      setState(() {
        final pData = results[0];
        if (pData is Map && pData['items'] is List) {
          projectList = _asList(pData['items']);
        } else if (pData is List) {
          projectList = _asList(pData);
        }

        final tData = results[1];
        if (tData is Map && tData['items'] is List) {
          teamList = _asList(tData['items']);
        } else if (tData is List) {
          teamList = _asList(tData);
        }

        final eData = results[2];
        if (eData is List) {
          employeeList = _asList(eData);
        } else if (eData is Map && eData['items'] is List) {
          employeeList = _asList(eData['items']);
        }
      });
    } catch (_) {}
  }

  void _clearAllFilters() {
    setState(() {
      selectedProjectId = null;
      selectedTeamId = null;
      selectedAssigneeId = null;
      selectedStatus = null;
      selectedPriority = null;
      selectedTaskType = null;
      customFrom = null;
      customTo = null;
    });
    load();
  }

  bool get _hasActiveFilters =>
      selectedProjectId != null ||
      selectedTeamId != null ||
      selectedAssigneeId != null ||
      selectedStatus != null ||
      selectedPriority != null ||
      selectedTaskType != null ||
      (customFrom != null && customTo != null);

  String? get _selectedProjectName {
    if (selectedProjectId == null) return null;
    final match = projectList.cast<Json?>().firstWhere(
      (p) => p?['id']?.toString() == selectedProjectId,
      orElse: () => null,
    );
    return match?['name']?.toString() ?? 'Project';
  }

  String? get _selectedTeamName {
    if (selectedTeamId == null) return null;
    final match = teamList.cast<Json?>().firstWhere(
      (t) => t?['id']?.toString() == selectedTeamId,
      orElse: () => null,
    );
    return match?['name']?.toString() ?? 'Team';
  }

  String? get _selectedAssigneeName {
    if (selectedAssigneeId == null) return null;
    final match = employeeList.cast<Json?>().firstWhere(
      (e) => e?['id']?.toString() == selectedAssigneeId,
      orElse: () => null,
    );
    return match?['fullName']?.toString() ?? 'Assignee';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const DashboardShimmer();
    if (error != null) return FailureView(error!, load);

    final d = data ?? const {};
    final counts = _asMap(d['counts']);
    final issues = _asMap(d['issues']);
    final (from, to) = range;

    final trendList = _asList(d['trend']);
    final byPriorityList = _asList(d['byPriority']);
    final byTypeList = _asList(d['byType']);
    final byProjectList = _asList(d['byProject']);
    final byTeamList = _asList(d['byTeam']);

    final scopeSubtitle = switch (api.scope.toUpperCase()) {
      'ALL' => 'Organisation-wide view',
      'TEAM' => 'Your team',
      _ => 'Tasks assigned to or created by you',
    };

    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        color: _taskBrown,
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            // Top module switcher if provided
            if (widget.moduleSwitch != null) ...[
              widget.moduleSwitch!,
              const SizedBox(height: 14),
            ],

            // ── Header Section ──────────────────────────────────────────
            _buildHeader(scopeSubtitle, from, to),
            const SizedBox(height: 14),

            // ── Admin Operations & Administration Section ───────────────
            if (isAdmin) ...[
              _buildAdminOperationsAndAdministrationSection(context),
              const SizedBox(height: 16),
            ],

            // ── Filters Section ─────────────────────────────────────────
            _buildFilterCard(context, from, to),
            const SizedBox(height: 16),

            // ── 10 Stat Cards Grid ──────────────────────────────────────
            _buildStatCards(counts, issues),
            const SizedBox(height: 16),

            // ── Section 1: Distribution & Priority ──────────────────────
            _buildDistributionAndPriorityRow(context, counts, byPriorityList, issues),
            const SizedBox(height: 16),

            // ── Section 2: Created vs Completed ─────────────────────────
            _buildCreatedVsCompletedCard(trendList),
            const SizedBox(height: 16),

            // ── Section 3: By Task Type ─────────────────────────────────
            _buildByTaskTypeCard(byTypeList),
            const SizedBox(height: 16),

            // ── Section 4: By Project ───────────────────────────────────
            _buildByProjectCard(byProjectList),
            const SizedBox(height: 16),

            // ── Section 5: By Team ──────────────────────────────────────
            if (!selfOnly || byTeamList.isNotEmpty) ...[
              _buildByTeamCard(byTeamList),
              const SizedBox(height: 16),
            ],

            // ── Section 6: Overdue by Project ───────────────────────────
            _buildOverdueByProjectCard(byProjectList),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(String scope, DateTime from, DateTime to) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Task dashboard',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$scope · trend ${_formatDay(from)} – ${_formatDay(to)}',
                    style: const TextStyle(
                      color: _soft,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => widget.onTab(widget.profileTab),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFFFCE9DA),
                child: Text(
                  _userInitials(api.profile?['name']?.toString() ?? ''),
                  style: const TextStyle(
                    color: _taskBrown,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Action buttons: [ My tasks ], [ All tasks icon ], and [ + Create task ]
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => widget.onTab(1),
                icon: const Icon(Icons.checklist_rounded, size: 17),
                label: const Text(
                  'My tasks',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: Color(0xFFD0D7DE)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'All tasks',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AllTasksPage(api: api),
                  ),
                );
              },
              icon: const Icon(Icons.list_alt_rounded, color: _taskBrown),
              style: IconButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD0D7DE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Scheduled tasks',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScheduledTasksPage(api: api),
                  ),
                );
              },
              icon: const Icon(Icons.repeat_rounded, color: _taskBrown),
              style: IconButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD0D7DE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Projects',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectsPage(api: api),
                    ),
                  );
                },
                icon: const Icon(Icons.folder_outlined, color: _taskBrown),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD0D7DE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTaskPage(
                        api: api,
                        onCreated: load,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Create task',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _taskBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Admin Operations & Administration Section ─────────────────────────────
  Widget _buildAdminOperationsAndAdministrationSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E2D9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE9DA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: _taskBrown,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administration & Operations',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Management console — operations, taxonomy, and system tools.',
                      style: TextStyle(
                        color: _soft,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE9DA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    color: _taskBrown,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // OPERATIONS SECTION
          const Text(
            'OPERATIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 720
                  ? 4
                  : (constraints.maxWidth >= 480 ? 3 : 2);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: [
                  _buildAdminTile(
                    title: 'Outlet Tasks',
                    subtitle: 'Store & site tasks',
                    icon: Icons.playlist_add_check_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFFFEF3C7),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllTasksPage(api: api, initialTaskType: 'OUTLET'),
                        ),
                      );
                    },
                  ),
                  _buildAdminTile(
                    title: 'Outlets',
                    subtitle: 'Branches & stores',
                    icon: Icons.storefront_outlined,
                    iconColor: const Color(0xFF0F766E),
                    iconBg: const Color(0xFFCCFBF1),
                    onTap: () => _showOutletsSheet(context),
                  ),
                  _buildAdminTile(
                    title: 'Issues',
                    subtitle: 'Blockers & reports',
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFDC2626),
                    iconBg: const Color(0xFFFEE2E2),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IssuesPage(api: api),
                        ),
                      );
                    },
                  ),
                  _buildAdminTile(
                    title: 'Calendar',
                    subtitle: 'Monthly timeline',
                    icon: Icons.calendar_month_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFDBEAFE),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskCalendarPage(api: api),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // ADMINISTRATION SECTION
          const Text(
            'ADMINISTRATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 720 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: [
                  _buildAdminTile(
                    title: 'Categories & Templates',
                    subtitle: 'Taxonomy & presets',
                    icon: Icons.local_offer_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFEDE9FE),
                    onTap: () => _showCategoriesAndTemplatesSheet(context),
                  ),
                  _buildAdminTile(
                    title: 'Scheduled Tasks',
                    subtitle: 'Recurring routines',
                    icon: Icons.repeat_rounded,
                    iconColor: _taskBrown,
                    iconBg: const Color(0xFFFCE9DA),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScheduledTasksPage(api: api),
                        ),
                      );
                    },
                  ),
                  _buildAdminTile(
                    title: 'Projects',
                    subtitle: 'Active rollouts',
                    icon: Icons.folder_outlined,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFD1FAE5),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectsPage(api: api),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _soft,
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

  // ── Outlets Modal Sheet ───────────────────────────────────────────────────
  void _showOutletsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String filter = '';
        return FutureBuilder<List<Json>>(
          future: _fetchOutlets(),
          builder: (context, snapshot) {
            return StatefulBuilder(
              builder: (context, setLocalState) {
                final allOutlets = snapshot.data ?? [];
                final filtered = allOutlets.where((o) {
                  if (filter.isEmpty) return true;
                  final q = filter.toLowerCase();
                  final name = (o['name'] ?? '').toString().toLowerCase();
                  final code = (o['code'] ?? '').toString().toLowerCase();
                  final city = (o['city'] ?? o['address'] ?? '').toString().toLowerCase();
                  return name.contains(q) || code.contains(q) || city.contains(q);
                }).toList();

                return DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  maxChildSize: 0.95,
                  minChildSize: 0.4,
                  expand: false,
                  builder: (context, scrollController) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined, color: Color(0xFF0F766E), size: 24),
                              const SizedBox(width: 8),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Outlets & Locations',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
                                  ),
                                  Text(
                                    'Branches and retail locations for outlet tasks',
                                    style: TextStyle(fontSize: 11.5, color: _soft),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search outlets by name, code or city...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) => setLocalState(() => filter = val),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: snapshot.connectionState == ConnectionState.waiting
                                ? const Center(child: CircularProgressIndicator(color: _taskBrown))
                                : filtered.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.storefront_outlined, size: 36, color: _soft),
                                            const SizedBox(height: 8),
                                            Text(
                                              allOutlets.isEmpty ? 'No outlets configured' : 'No matching outlets',
                                              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Outlet tasks are assigned to locations.',
                                              style: TextStyle(fontSize: 12, color: _soft),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        controller: scrollController,
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, _) => const Divider(height: 1),
                                        itemBuilder: (context, idx) {
                                          final o = filtered[idx];
                                          final name = o['name']?.toString() ?? 'Outlet';
                                          final code = o['code']?.toString() ?? '';
                                          final address = (o['address'] ?? o['city'] ?? '').toString();

                                          return ListTile(
                                            leading: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFCCFBF1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.storefront, size: 18, color: Color(0xFF0F766E)),
                                            ),
                                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            subtitle: Text(
                                              code.isNotEmpty && address.isNotEmpty
                                                  ? '$code · $address'
                                                  : (code.isNotEmpty ? code : address),
                                              style: const TextStyle(fontSize: 12, color: _soft),
                                            ),
                                            trailing: FilledButton.tonal(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => AllTasksPage(
                                                      api: api,
                                                      initialTaskType: 'OUTLET',
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: FilledButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: const Size(0, 32),
                                              ),
                                              child: const Text('View tasks', style: TextStyle(fontSize: 11)),
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<Json>> _fetchOutlets() async {
    try {
      final res = await api.v1('GET', '/outlets', query: {'pageSize': 100});
      if (res is Map && res['items'] is List) {
        return (res['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (res is List) {
        return res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    // Fallback: check offices if outlets not separate
    try {
      final res = await api.v1('GET', '/offices', query: {'pageSize': 100});
      if (res is Map && res['items'] is List) {
        return (res['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (res is List) {
        return res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Categories & Templates Sheet ──────────────────────────────────────────
  void _showCategoriesAndTemplatesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.45,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.local_offer_outlined, color: Color(0xFF7C3AED), size: 24),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Categories & Templates',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
                            ),
                            Text(
                              'Standardize tasks across projects and outlets',
                              style: TextStyle(fontSize: 11.5, color: _soft),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const TabBar(
                      labelColor: _taskBrown,
                      unselectedLabelColor: _soft,
                      indicatorColor: _taskBrown,
                      tabs: [
                        Tab(text: 'Categories'),
                        Tab(text: 'Templates'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Categories Tab
                          FutureBuilder<List<Json>>(
                            future: _fetchCategories(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: _taskBrown));
                              }
                              final cats = snapshot.data ?? [];
                              if (cats.isEmpty) {
                                return const Center(
                                  child: Text('No categories found', style: TextStyle(color: _soft)),
                                );
                              }
                              return ListView.separated(
                                controller: scrollController,
                                itemCount: cats.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final c = cats[idx];
                                  final name = c['name']?.toString() ?? 'Category';
                                  final code = c['code']?.toString() ?? '';
                                  final appliesTo = c['appliesTo']?.toString() ?? 'GENERAL';

                                  return ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE9FE),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          color: Color(0xFF7C3AED),
                                        ),
                                      ),
                                    ),
                                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                    subtitle: Text(
                                      'Applies to: $appliesTo',
                                      style: const TextStyle(fontSize: 11.5, color: _soft),
                                    ),
                                    trailing: const Icon(Icons.check_circle_outline_rounded, size: 16, color: _green),
                                  );
                                },
                              );
                            },
                          ),

                          // Templates Tab
                          FutureBuilder<List<Json>>(
                            future: _fetchTemplates(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: _taskBrown));
                              }
                              final tmpls = snapshot.data ?? [];
                              if (tmpls.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.assignment_outlined, size: 36, color: _soft),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'No task templates configured yet',
                                        style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Templates allow 1-click recurring task creation.',
                                        style: TextStyle(fontSize: 12, color: _soft),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreateTaskPage(api: api),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.add_rounded, size: 16),
                                        label: const Text('Create task'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return ListView.separated(
                                controller: scrollController,
                                itemCount: tmpls.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final t = tmpls[idx];
                                  final title = t['title']?.toString() ?? 'Template';
                                  final desc = t['description']?.toString() ?? '';

                                  return ListTile(
                                    leading: const Icon(Icons.assignment_turned_in_outlined, color: _taskBrown),
                                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    subtitle: desc.isNotEmpty ? Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<List<Json>> _fetchCategories() async {
    try {
      final res = await api.v1(
        'GET',
        '/task-categories',
        query: {
          'pageSize': 200,
          'status': 'ACTIVE',
          'sortBy': 'name',
          'sortDir': 'asc',
        },
      );
      if (res is Map && res['items'] is List) {
        return (res['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (res is List) {
        return res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Json>> _fetchTemplates() async {
    try {
      final res = await api.v1('GET', '/task-templates', query: {'pageSize': 100});
      if (res is Map && res['items'] is List) {
        return (res['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (res is List) {
        return res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }



  // ── Filters Card ───────────────────────────────────────────────────────
  Widget _buildFilterCard(BuildContext context, DateTime from, DateTime to) {
    final dateLabel = customFrom != null && customTo != null
        ? '${_formatShortDate(customFrom!)} – ${_formatShortDate(customTo!)}'
        : 'By Date';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Icon + Title/Subtitle + Granularity Selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE9DA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: _taskBrown,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Narrow every widget by date, project, team, person, status, priority or type.',
                      style: TextStyle(
                        color: _soft,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Grain selector (Day | Week | Month)
              _buildGrainPill(),
            ],
          ),
          const SizedBox(height: 14),

          // Filter Dropdowns
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterButton(
                icon: Icons.calendar_today_outlined,
                label: dateLabel,
                isActive: customFrom != null,
                onTap: () => _pickDateRange(context),
              ),
              _filterButton(
                icon: Icons.folder_outlined,
                label: _selectedProjectName ?? 'By Project',
                isActive: selectedProjectId != null,
                onTap: () => _openProjectSheet(context),
              ),
              _filterButton(
                icon: Icons.groups_outlined,
                label: _selectedTeamName ?? 'By Team',
                isActive: selectedTeamId != null,
                onTap: () => _openTeamSheet(context),
              ),
              _filterButton(
                icon: Icons.person_outline_rounded,
                label: _selectedAssigneeName ?? 'By Assignee Name...',
                isActive: selectedAssigneeId != null,
                onTap: () => _openAssigneeSheet(context),
              ),
              _filterButton(
                icon: Icons.timelapse_rounded,
                label: selectedStatus != null ? _pretty(selectedStatus!) : 'By Status',
                isActive: selectedStatus != null,
                onTap: () => _openStatusSheet(context),
              ),
              _filterButton(
                icon: Icons.flag_outlined,
                label: selectedPriority != null ? _pretty(selectedPriority!) : 'By Priority',
                isActive: selectedPriority != null,
                onTap: () => _openPrioritySheet(context),
              ),
              _filterButton(
                icon: Icons.category_outlined,
                label: selectedTaskType != null ? _pretty(selectedTaskType!) : 'By Type',
                isActive: selectedTaskType != null,
                onTap: () => _openTypeSheet(context),
              ),
            ],
          ),

          // Active filter row with Clear all button
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE9DA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Filters applied',
                    style: TextStyle(
                      color: _taskBrown,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _clearAllFilters,
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      color: _taskBrown,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Disclaimer note
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: _soft),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Counts reflect all current tasks matching the filters; the date range applies to the created vs completed trend.',
                  style: TextStyle(
                    color: _soft,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrainPill() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in TaskGrain.values)
            GestureDetector(
              onTap: () {
                if (grain == item && customFrom == null) return;
                setState(() {
                  grain = item;
                  customFrom = null;
                  customTo = null;
                });
                load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: grain == item ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: grain == item
                      ? const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _pretty(item.name),
                  style: TextStyle(
                    color: grain == item ? _ink : _soft,
                    fontSize: 11,
                    fontWeight: grain == item ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive ? const Color(0xFFFCE9DA) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? _taskBrown : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? _taskBrown : _soft,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? _taskBrown : _ink,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? _taskBrown : _soft,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Date Range Picker ──────────────────────────────────────────────────
  Future<void> _pickDateRange(BuildContext context) async {
    final (from, to) = range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: from, end: to),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _taskBrown,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        customFrom = picked.start;
        customTo = picked.end;
      });
      load();
    }
  }

  // ── Filter Bottom Sheets ───────────────────────────────────────────────
  void _openProjectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Select Project',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  title: const Text('All Projects', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: selectedProjectId == null
                      ? const Icon(Icons.check, color: _taskBrown)
                      : null,
                  onTap: () {
                    setState(() => selectedProjectId = null);
                    Navigator.pop(ctx);
                    load();
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: projectList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = projectList[i];
                      final id = item['id']?.toString() ?? '';
                      final name = item['name']?.toString() ?? 'Project';
                      final code = item['code']?.toString() ?? '';
                      final isSelected = selectedProjectId == id;
                      return ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _parseHexColor(item['color']?.toString()) ?? _taskBrown,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: code.isNotEmpty ? Text(code, style: const TextStyle(fontSize: 12)) : null,
                        trailing: isSelected ? const Icon(Icons.check, color: _taskBrown) : null,
                        onTap: () {
                          setState(() => selectedProjectId = id);
                          Navigator.pop(ctx);
                          load();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTeamSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Select Team',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  title: const Text('All Teams', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: selectedTeamId == null
                      ? const Icon(Icons.check, color: _taskBrown)
                      : null,
                  onTap: () {
                    setState(() => selectedTeamId = null);
                    Navigator.pop(ctx);
                    load();
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: teamList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = teamList[i];
                      final id = item['id']?.toString() ?? '';
                      final name = item['name']?.toString() ?? 'Team';
                      final dept = item['department'] is Map ? item['department']['name'] : null;
                      final isSelected = selectedTeamId == id;
                      return ListTile(
                        leading: const Icon(Icons.groups_outlined, color: _teal),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: dept != null ? Text(dept.toString(), style: const TextStyle(fontSize: 12)) : null,
                        trailing: isSelected ? const Icon(Icons.check, color: _taskBrown) : null,
                        onTap: () {
                          setState(() => selectedTeamId = id);
                          Navigator.pop(ctx);
                          load();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAssigneeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssigneeSearchSheet(
        initialList: employeeList,
        selectedId: selectedAssigneeId,
        onSelected: (id) {
          setState(() => selectedAssigneeId = id);
          load();
        },
      ),
    );
  }

  void _openStatusSheet(BuildContext context) {
    final statuses = [
      (null, 'All Statuses'),
      ('TODO', 'To Do'),
      ('IN_PROGRESS', 'In Progress'),
      ('COMPLETED', 'Completed'),
      ('CANCELLED', 'Cancelled'),
    ];
    _openSimpleSheet(
      context: context,
      title: 'Select Status',
      options: statuses,
      selected: selectedStatus,
      onSelect: (val) {
        setState(() => selectedStatus = val);
        load();
      },
    );
  }

  void _openPrioritySheet(BuildContext context) {
    final priorities = [
      (null, 'All Priorities'),
      ('URGENT', 'Urgent'),
      ('HIGH', 'High'),
      ('MEDIUM', 'Medium'),
      ('LOW', 'Low'),
    ];
    _openSimpleSheet(
      context: context,
      title: 'Select Priority',
      options: priorities,
      selected: selectedPriority,
      onSelect: (val) {
        setState(() => selectedPriority = val);
        load();
      },
    );
  }

  void _openTypeSheet(BuildContext context) {
    final types = [
      (null, 'All Types'),
      ('GENERAL', 'General'),
      ('OUTLET', 'Outlet'),
    ];
    _openSimpleSheet(
      context: context,
      title: 'Select Task Type',
      options: types,
      selected: selectedTaskType,
      onSelect: (val) {
        setState(() => selectedTaskType = val);
        load();
      },
    );
  }

  void _openSimpleSheet({
    required BuildContext context,
    required String title,
    required List<(String?, String)> options,
    required String? selected,
    required ValueChanged<String?> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              for (final opt in options)
                ListTile(
                  title: Text(
                    opt.$2,
                    style: TextStyle(
                      fontWeight: opt.$1 == selected ? FontWeight.w800 : FontWeight.w600,
                      color: opt.$1 == selected ? _taskBrown : _ink,
                    ),
                  ),
                  trailing: opt.$1 == selected
                      ? const Icon(Icons.check, color: _taskBrown)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelect(opt.$1);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 10 Stat Cards ──────────────────────────────────────────────────────
  Widget _buildStatCards(Json counts, Json issues) {
    final total = _num(counts['total']);
    final todo = _num(counts['todo']);
    final inProgress = _num(counts['inProgress']);
    final completed = _num(counts['completed']);
    final completion = _num(counts['completionPercent']);
    final overdue = _num(counts['overdue']);
    final dueSoon = _num(counts['dueSoon']);
    final unassigned = _num(counts['unassigned']);
    final atRisk = _num(counts['atRisk']);
    final issuesTotal = _num(issues['total']);

    final cards = [
      _StatCardData(
        title: 'Total tasks',
        value: '$total',
        icon: Icons.format_list_bulleted_rounded,
        iconColor: _taskBrown,
        iconBg: const Color(0xFFFCE9DA),
      ),
      _StatCardData(
        title: 'To Do',
        value: '$todo',
        icon: Icons.radio_button_unchecked_rounded,
        iconColor: const Color(0xFF78716C),
        iconBg: const Color(0xFFF5F5F4),
      ),
      _StatCardData(
        title: 'In Progress',
        value: '$inProgress',
        icon: Icons.play_circle_outline_rounded,
        iconColor: _blue,
        iconBg: const Color(0xFFEFF6FF),
      ),
      _StatCardData(
        title: 'Completed',
        value: '$completed',
        icon: Icons.check_circle_outline_rounded,
        iconColor: _green,
        iconBg: const Color(0xFFF0FDF4),
      ),
      _StatCardData(
        title: 'Completion',
        value: '$completion%',
        subtitle: 'Completed of total',
        icon: Icons.percent_rounded,
        iconColor: _green,
        iconBg: const Color(0xFFF0FDF4),
      ),
      _StatCardData(
        title: 'Overdue',
        value: '$overdue',
        subtitle: 'Past due, not completed',
        icon: Icons.warning_amber_rounded,
        iconColor: _red,
        iconBg: const Color(0xFFFEF2F2),
      ),
      _StatCardData(
        title: 'Due soon',
        value: '$dueSoon',
        subtitle: 'Within the reminder window',
        icon: Icons.schedule_rounded,
        iconColor: _amber,
        iconBg: const Color(0xFFFFFBEB),
      ),
      _StatCardData(
        title: 'Unassigned',
        value: '$unassigned',
        icon: Icons.person_outline_rounded,
        iconColor: _purple,
        iconBg: const Color(0xFFF5F3FF),
      ),
      _StatCardData(
        title: 'At risk',
        value: '$atRisk',
        subtitle: 'Due soon, not started',
        icon: Icons.shield_outlined,
        iconColor: _red,
        iconBg: const Color(0xFFFEF2F2),
      ),
      _StatCardData(
        title: 'Issues',
        value: '$issuesTotal',
        subtitle: 'View all issues',
        subtitleTap: widget.issuesTab != null ? () => widget.onTab(widget.issuesTab!) : null,
        icon: Icons.report_gmailerrorred_rounded,
        iconColor: _amber,
        iconBg: const Color(0xFFFEF3C7),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns on phones, 3 on tablets, 5 on wide desktops
        final crossAxisCount = constraints.maxWidth >= 900
            ? 5
            : (constraints.maxWidth >= 600 ? 3 : 2);
        final width = (constraints.maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _buildSingleStatCard(card),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSingleStatCard(_StatCardData card) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _soft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: card.iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(card.icon, size: 17, color: card.iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            card.value,
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          if (card.subtitle != null)
            GestureDetector(
              onTap: card.subtitleTap,
              child: Text(
                card.subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: card.subtitleTap != null ? _taskBrown : _soft,
                  fontSize: 11,
                  fontWeight: card.subtitleTap != null ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Distribution & Priority Row ────────────────────────────────────────
  Widget _buildDistributionAndPriorityRow(
    BuildContext context,
    Json counts,
    List<Json> byPriority,
    Json issues,
  ) {
    return Column(
      children: [
        // Status distribution card
        _cardContainer(
          title: 'Status distribution',
          subtitle: 'Share of tasks by workflow status',
          child: _buildStatusDonut(counts),
        ),
        const SizedBox(height: 16),

        // By priority card
        _cardContainer(
          title: 'By priority',
          subtitle: 'All matching tasks',
          child: _buildPriorityGauge(byPriority),
        ),
        const SizedBox(height: 16),

        // Issues by status card
        _cardContainer(
          title: 'Issues by status',
          subtitle: '${_num(issues['highPriorityOpen'])} high/urgent still open',
          trailing: widget.issuesTab == null
              ? null
              : TextButton(
                  onPressed: () => widget.onTab(widget.issuesTab!),
                  child: const Text(
                    'View all',
                    style: TextStyle(color: _taskBrown, fontWeight: FontWeight.w700),
                  ),
                ),
          child: _buildIssuesWidget(issues),
        ),
      ],
    );
  }

  Widget _buildStatusDonut(Json counts) {
    final parts = [
      ('To do', _num(counts['todo']), const Color(0xFFB9A58F)),
      ('In progress', _num(counts['inProgress']), _blue),
      ('Completed', _num(counts['completed']), _green),
    ];
    final total = _num(counts['total']);

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutRingPainter([for (final p in parts) (p.$2, p.$3)]),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'tasks',
                    style: TextStyle(color: _soft, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              for (final p in parts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: p.$3,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.$1,
                          style: const TextStyle(color: _ink, fontSize: 12.5),
                        ),
                      ),
                      Text(
                        '${p.$2}',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityGauge(List<Json> byPriority) {
    final total = byPriority.fold<int>(0, (sum, p) => sum + _num(p['total']));
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('No tasks matching current filters', style: TextStyle(color: _soft)),
        ),
      );
    }

    Color colorForPriority(String key) {
      return switch (key.toUpperCase()) {
        'URGENT' => _red,
        'HIGH' => _taskBrown,
        'MEDIUM' => _amber,
        'LOW' => const Color(0xFF92400E),
        _ => _soft,
      };
    }

    final segments = [
      for (final p in byPriority)
        (
          _pretty(p['key']?.toString() ?? ''),
          _num(p['total']),
          colorForPriority(p['key']?.toString() ?? ''),
        ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 110,
          child: CustomPaint(
            size: const Size(180, 110),
            painter: _PriorityArcPainter(
              [for (final s in segments) (s.$2, s.$3)],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Tasks',
                      style: TextStyle(
                        color: _soft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: s.$3, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${s.$1} ${s.$2}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildIssuesWidget(Json issues) {
    final total = _num(issues['total']);
    if (total == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F4EB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                color: Color(0xFF8B93A7),
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No issues reported',
              style: TextStyle(
                color: _soft,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final items = [
      ('Open', _num(issues['open']), _red),
      ('In progress', _num(issues['inProgress']), _amber),
      ('Resolved', _num(issues['resolved']), _green),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items[i].$1,
                    style: const TextStyle(color: _soft, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${items[i].$2}',
                    style: TextStyle(
                      color: items[i].$3,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Created vs Completed Bar Chart ─────────────────────────────────────
  Widget _buildCreatedVsCompletedCard(List<Json> trend) {
    if (trend.isEmpty) {
      return _cardContainer(
        title: 'Created vs completed',
        subtitle: 'Per ${grain.name}',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'No task activity in this range.',
              style: TextStyle(color: _soft, fontSize: 12.5),
            ),
          ),
        ),
      );
    }

    final groups = <_BarGroupData>[];
    for (final p in trend) {
      final period = p['period']?.toString() ?? '';
      final created = _num(p['created']).toDouble();
      final completed = _num(p['completed']).toDouble();
      groups.add(
        _BarGroupData(
          label: _formatPeriodLabel(period),
          bars: [
            _BarData('Completed', completed, _green),
            _BarData('Created', created, _taskBrown),
          ],
        ),
      );
    }

    return _cardContainer(
      title: 'Created vs completed',
      subtitle: 'Per ${grain.name}',
      child: _VerticalGroupedBarChart(
        groups: groups,
        legend: const [
          ('Completed', _green),
          ('Created', _taskBrown),
        ],
      ),
    );
  }

  // ── By Task Type Donut Chart ───────────────────────────────────────────
  Widget _buildByTaskTypeCard(List<Json> byType) {
    final total = byType.fold<int>(0, (sum, p) => sum + _num(p['total']));
    if (total == 0) {
      return _cardContainer(
        title: 'By task type',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text('No task type data', style: TextStyle(color: _soft)),
          ),
        ),
      );
    }

    Color colorForType(int idx) {
      final palette = [_taskBrown, _blue, _purple, _teal, _amber];
      return palette[idx % palette.length];
    }

    final slices = <(int, Color)>[];
    final legendItems = <(String, int, double, Color)>[];
    for (var i = 0; i < byType.length; i++) {
      final item = byType[i];
      final key = _pretty(item['key']?.toString() ?? '');
      final count = _num(item['total']);
      final pct = total > 0 ? (count / total) * 100 : 0.0;
      final c = colorForType(i);
      slices.add((count, c));
      legendItems.add((key, count, pct, c));
    }

    return _cardContainer(
      title: 'By task type',
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _DonutRingPainter(slices),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Tasks',
                      style: TextStyle(
                        color: _soft,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final leg in legendItems)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: leg.$4, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${leg.$1}  ${leg.$2}  ${leg.$3.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── By Project Bar Chart ───────────────────────────────────────────────
  Widget _buildByProjectCard(List<Json> byProject) {
    if (byProject.isEmpty) {
      return _cardContainer(
        title: 'By project',
        subtitle: 'Open vs completed',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text('No project data', style: TextStyle(color: _soft)),
          ),
        ),
      );
    }

    final groups = <_BarGroupData>[];
    for (final p in byProject) {
      final name = p['key']?.toString() ?? 'Project';
      final total = _num(p['total']).toDouble();
      final completed = _num(p['completed']).toDouble();
      final open = math.max(0.0, total - completed);
      groups.add(
        _BarGroupData(
          label: name,
          bars: [
            _BarData('Completed', completed, _green),
            _BarData('Open', open, _taskBrown),
          ],
        ),
      );
    }

    return _cardContainer(
      title: 'By project',
      subtitle: 'Open vs completed',
      child: _VerticalGroupedBarChart(
        groups: groups,
        legend: const [
          ('Completed', _green),
          ('Open', _taskBrown),
        ],
      ),
    );
  }

  // ── By Team Bar Chart ──────────────────────────────────────────────────
  Widget _buildByTeamCard(List<Json> byTeam) {
    if (byTeam.isEmpty) {
      return _cardContainer(
        title: 'By team',
        subtitle: 'Open vs completed',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text('No team data', style: TextStyle(color: _soft)),
          ),
        ),
      );
    }

    final groups = <_BarGroupData>[];
    for (final t in byTeam) {
      final name = t['key']?.toString() ?? 'Team';
      final total = _num(t['total']).toDouble();
      final completed = _num(t['completed']).toDouble();
      final open = math.max(0.0, total - completed);
      groups.add(
        _BarGroupData(
          label: name,
          bars: [
            _BarData('Completed', completed, _green),
            _BarData('Open', open, _teal),
          ],
        ),
      );
    }

    return _cardContainer(
      title: 'By team',
      subtitle: 'Open vs completed',
      child: _VerticalGroupedBarChart(
        groups: groups,
        legend: const [
          ('Completed', _green),
          ('Open', _teal),
        ],
      ),
    );
  }

  // ── Overdue by Project Bar Chart ───────────────────────────────────────
  Widget _buildOverdueByProjectCard(List<Json> byProject) {
    final overdueProjects = byProject.where((p) => _num(p['overdue']) > 0).toList();

    if (overdueProjects.isEmpty) {
      return _cardContainer(
        title: 'Overdue by project',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'No overdue tasks across projects.',
              style: TextStyle(color: _soft, fontSize: 12.5),
            ),
          ),
        ),
      );
    }

    final groups = <_BarGroupData>[];
    for (final p in overdueProjects) {
      final name = p['key']?.toString() ?? 'Project';
      final overdue = _num(p['overdue']).toDouble();
      groups.add(
        _BarGroupData(
          label: name,
          bars: [
            _BarData('Overdue', overdue, _red),
          ],
        ),
      );
    }

    return _cardContainer(
      title: 'Overdue by project',
      child: _VerticalGroupedBarChart(
        groups: groups,
        legend: const [
          ('Overdue', _red),
        ],
      ),
    );
  }

  // ── Card Helper ────────────────────────────────────────────────────────
  Widget _cardContainer({
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
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
                        subtitle,
                        style: const TextStyle(color: _soft, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.grid_view_outlined,
                    color: Color(0xFFCBD5E1),
                    size: 18,
                  ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  String _formatDay(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatShortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String _formatPeriodLabel(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String _pretty(String key) {
    if (key.isEmpty) return '';
    return key
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _userInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return null;
  }
}

// ── Assignee Search Bottom Sheet ──────────────────────────────────────────
class _AssigneeSearchSheet extends StatefulWidget {
  final List<Json> initialList;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _AssigneeSearchSheet({
    required this.initialList,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_AssigneeSearchSheet> createState() => _AssigneeSearchSheetState();
}

class _AssigneeSearchSheetState extends State<_AssigneeSearchSheet> {
  final TextEditingController searchCtrl = TextEditingController();
  String filterQuery = '';

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  List<Json> get filteredList {
    if (filterQuery.isEmpty) return widget.initialList;
    final q = filterQuery.toLowerCase();
    return widget.initialList.where((emp) {
      final name = emp['fullName']?.toString().toLowerCase() ?? '';
      final code = emp['employeeCode']?.toString().toLowerCase() ?? '';
      final desig = emp['designation']?.toString().toLowerCase() ?? '';
      final dept = emp['department']?.toString().toLowerCase() ?? '';
      return name.contains(q) || code.contains(q) || desig.contains(q) || dept.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Select Assignee',
                  style: TextStyle(
                    color: Color(0xFF1B2A4A),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search text field
            TextField(
              controller: searchCtrl,
              onChanged: (val) => setState(() => filterQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search by name, code or department...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8B93A7)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF8B93A7)),
                suffixIcon: filterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          searchCtrl.clear();
                          setState(() => filterQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFBE5E38), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // "All Assignees" tile
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('All Assignees', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: widget.selectedId == null
                  ? const Icon(Icons.check, color: Color(0xFFBE5E38))
                  : null,
              onTap: () {
                widget.onSelected(null);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),

            // List of assignees
            Expanded(
              child: filteredList.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No assignees match your search.',
                          style: TextStyle(color: Color(0xFF6E7C8A), fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final emp = filteredList[i];
                        final id = emp['id']?.toString() ?? '';
                        final name = emp['fullName']?.toString() ?? 'Employee';
                        final code = emp['employeeCode']?.toString() ?? '';
                        final desig = emp['designation']?.toString() ?? '';
                        final dept = emp['department']?.toString() ?? '';
                        final isSelected = widget.selectedId == id;

                        final sub = [
                          if (code.isNotEmpty) code,
                          if (desig.isNotEmpty) desig,
                          if (dept.isNotEmpty) dept,
                        ].join(' · ');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: CircleAvatar(
                            radius: 17,
                            backgroundColor: const Color(0xFFFCE9DA),
                            child: Text(
                              _initials(name),
                              style: const TextStyle(
                                color: Color(0xFFBE5E38),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          subtitle: sub.isNotEmpty
                              ? Text(
                                  sub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF6E7C8A)),
                                )
                              : null,
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Color(0xFFBE5E38))
                              : null,
                          onTap: () {
                            widget.onSelected(id);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'E';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

// ── Stat Card Data Model ──────────────────────────────────────────────────
class _StatCardData {
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? subtitleTap;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  _StatCardData({
    required this.title,
    required this.value,
    this.subtitle,
    this.subtitleTap,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
}

// ── Bar Chart Data Models ─────────────────────────────────────────────────
class _BarData {
  final String name;
  final double value;
  final Color color;
  _BarData(this.name, this.value, this.color);
}

class _BarGroupData {
  final String label;
  final List<_BarData> bars;
  _BarGroupData({required this.label, required this.bars});
}

// ── Grouped Vertical Bar Chart with Gridlines & Y-Axis ────────────────────
class _VerticalGroupedBarChart extends StatelessWidget {
  final List<_BarGroupData> groups;
  final List<(String, Color)> legend;

  const _VerticalGroupedBarChart({
    required this.groups,
    required this.legend,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

    // Determine max value for Y-axis
    double peak = 1.0;
    for (final g in groups) {
      for (final b in g.bars) {
        if (b.value > peak) peak = b.value;
      }
    }
    // Round peak up to a nice integer
    final yMax = peak <= 4 ? 4.0 : (peak <= 10 ? 10.0 : ((peak / 5).ceil() * 5).toDouble());
    final ticks = [yMax, yMax * 0.75, yMax * 0.5, yMax * 0.25, 0.0];

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Y-Axis tick labels
              SizedBox(
                width: 22,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in ticks)
                      Text(
                        t.toInt().toString(),
                        style: const TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 18), // clearance for X-axis labels
                  ],
                ),
              ),

              // Bars & Grid lines
              Expanded(
                child: Stack(
                  children: [
                    // Dashed horizontal gridlines
                    Positioned.fill(
                      bottom: 22,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < ticks.length; i++)
                            const _DashedLine(color: Color(0xFFE2E8F0)),
                        ],
                      ),
                    ),

                    // Groups of bars
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final g in groups)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Bars
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        for (final b in g.bars)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2),
                                            child: FractionallySizedBox(
                                              heightFactor: (b.value / yMax).clamp(0.01, 1.0),
                                              alignment: Alignment.bottomCenter,
                                              child: Container(
                                                width: 14,
                                                decoration: BoxDecoration(
                                                  color: b.color,
                                                  borderRadius: const BorderRadius.vertical(
                                                    top: Radius.circular(4),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // X-axis label
                                  SizedBox(
                                    height: 16,
                                    child: Text(
                                      g.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF6E7C8A),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < legend.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: legend[i].$2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                legend[i].$1,
                style: const TextStyle(
                  color: Color(0xFF1B2A4A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Horizontal Dashed Line ────────────────────────────────────────────────
class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Priority Arc Gauge CustomPainter ──────────────────────────────────────
class _PriorityArcPainter extends CustomPainter {
  final List<(int count, Color color)> parts;
  _PriorityArcPainter(this.parts);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 22.0;
    final center = Offset(size.width / 2, size.height);
    final radius = size.height - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    final total = parts.fold<int>(0, (sum, p) => sum + p.$1);
    if (total == 0) return;

    var start = math.pi;
    for (final p in parts) {
      if (p.$1 <= 0) continue;
      final sweep = math.pi * (p.$1 / total);
      final segmentPaint = Paint()
        ..color = p.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, segmentPaint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PriorityArcPainter oldDelegate) => true;
}

// ── Donut Ring Painter ────────────────────────────────────────────────────
class _DonutRingPainter extends CustomPainter {
  final List<(int count, Color color)> parts;
  _DonutRingPainter(this.parts);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final total = parts.fold<int>(0, (sum, p) => sum + p.$1);

    final track = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (total == 0) return;
    final visible = parts.where((p) => p.$1 > 0).length;
    final gap = visible > 1 ? 0.05 : 0.0;
    var start = -math.pi / 2;

    for (final part in parts) {
      if (part.$1 <= 0) continue;
      final sweep = math.pi * 2 * part.$1 / total;
      final paint = Paint()
        ..color = part.$2
        ..style = PaintingStyle.stroke
        ..strokeCap = visible > 1 ? StrokeCap.butt : StrokeCap.round
        ..strokeWidth = stroke;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0.001, sweep - gap),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutRingPainter old) => true;
}

// ── Generic Cast Helpers ──────────────────────────────────────────────────
int _num(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

Map<String, dynamic> _asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return const {};
}

List<Map<String, dynamic>> _asList(Object? v) {
  if (v is! List) return const [];
  return v
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}
