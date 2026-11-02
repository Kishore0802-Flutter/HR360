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
    _notifyFiltersChanged();
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
    _notifyFiltersChanged();
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

  int get _activeFilterCount {
    int count = 0;
    if (customFrom != null && customTo != null) count++;
    if (selectedProjectId != null) count++;
    if (selectedTeamId != null) count++;
    if (selectedAssigneeId != null) count++;
    if (selectedStatus != null) count++;
    if (selectedPriority != null) count++;
    if (selectedTaskType != null) count++;
    return count;
  }

  void Function(void Function())? _sheetSetState;

  void _notifyFiltersChanged() {
    _sheetSetState?.call(() {});
  }

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
            _buildFilterTriggerBar(context, from, to),
            const SizedBox(height: 16),

            // ── 10 Stat Cards Grid ──────────────────────────────────────
            _buildStatCards(counts, issues),
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
                      fontWeight: FontWeight.w700,
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
            IconButton(
              tooltip: 'Filters',
              onPressed: () => _openFiltersBottomSheet(context, from, to),
              icon: Badge(
                isLabelVisible: _hasActiveFilters,
                smallSize: 8,
                backgroundColor: _taskBrown,
                child: const Icon(Icons.tune_rounded, color: _ink, size: 21),
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD0D7DE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(9),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => widget.onTab(widget.profileTab),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFFFCE9DA),
                child: Text(
                  _userInitials(api.profile?['name']?.toString() ?? ''),
                  style: const TextStyle(
                    color: _taskBrown,
                    fontWeight: FontWeight.w700,
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
              icon: const Icon(Icons.list_alt_rounded, color: _taskBrown, size: 20),
              style: IconButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD0D7DE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(11),
              ),
            ),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                        fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // OPERATIONS SECTION
          const Text(
            'OPERATIONS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _adminGridActionCard(
                  title: 'Outlet Tasks',
                  icon: Icons.playlist_add_check_rounded,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllTasksPage(api: api, initialTaskType: 'OUTLET'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _adminGridActionCard(
                  title: 'Outlets',
                  icon: Icons.storefront_outlined,
                  iconColor: const Color(0xFF0F766E),
                  bgColor: const Color(0xFFCCFBF1),
                  onTap: () => _showOutletsSheet(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _adminGridActionCard(
                  title: 'Issues',
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEE2E2),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IssuesPage(api: api),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _adminGridActionCard(
                  title: 'Calendar',
                  icon: Icons.calendar_month_outlined,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFDBEAFE),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskCalendarPage(api: api),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // ADMINISTRATION SECTION
          const Text(
            'ADMINISTRATION',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _adminGridActionCard(
                  title: 'Categories & Templates',
                  icon: Icons.local_offer_outlined,
                  iconColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFEDE9FE),
                  onTap: () => _showCategoriesAndTemplatesSheet(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _adminGridActionCard(
                  title: 'Scheduled Tasks',
                  icon: Icons.repeat_rounded,
                  iconColor: _taskBrown,
                  bgColor: const Color(0xFFFCE9DA),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduledTasksPage(api: api),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _adminGridActionCard(
                  title: 'Projects',
                  icon: Icons.folder_outlined,
                  iconColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectsPage(api: api),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adminGridActionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          constraints: const BoxConstraints(minHeight: 82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  height: 1.15,
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



  // ── Filters Trigger Bar & Bottom Sheet ─────────────────────────────────
  Widget _buildFilterTriggerBar(BuildContext context, DateTime from, DateTime to) {
    final activeCount = _activeFilterCount;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _openFiltersBottomSheet(context, from, to),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activeCount > 0 ? _taskBrown : const Color(0xFFFCE9DA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: activeCount > 0 ? Colors.white : _taskBrown,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _openFiltersBottomSheet(context, from, to),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Filters',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (activeCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCE9DA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$activeCount',
                                  style: const TextStyle(
                                    color: _taskBrown,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          activeCount > 0 ? 'Tap to edit filters' : 'Tap to filter tasks',
                          style: const TextStyle(
                            color: _soft,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildGrainPill(),
            ],
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._buildActiveChipsList(),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearAllFilters,
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        color: _taskBrown,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActiveChipsList() {
    final chips = <Widget>[];

    Widget chip(String label, VoidCallback onRemove) {
      return Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 5, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFCE9DA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8D5C4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _taskBrown,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: _taskBrown,
              ),
            ),
          ],
        ),
      );
    }

    if (customFrom != null && customTo != null) {
      chips.add(chip('${_formatShortDate(customFrom!)}–${_formatShortDate(customTo!)}', () {
        setState(() {
          customFrom = null;
          customTo = null;
        });
        load();
      }));
    }
    if (selectedProjectId != null) {
      chips.add(chip(_selectedProjectName ?? 'Project', () {
        setState(() {
          selectedProjectId = null;
        });
        load();
      }));
    }
    if (selectedTeamId != null) {
      chips.add(chip(_selectedTeamName ?? 'Team', () {
        setState(() {
          selectedTeamId = null;
        });
        load();
      }));
    }
    if (selectedAssigneeId != null) {
      chips.add(chip(_selectedAssigneeName ?? 'Assignee', () {
        setState(() {
          selectedAssigneeId = null;
        });
        load();
      }));
    }
    if (selectedStatus != null) {
      chips.add(chip(_pretty(selectedStatus!), () {
        setState(() {
          selectedStatus = null;
        });
        load();
      }));
    }
    if (selectedPriority != null) {
      chips.add(chip(_pretty(selectedPriority!), () {
        setState(() {
          selectedPriority = null;
        });
        load();
      }));
    }
    if (selectedTaskType != null) {
      chips.add(chip(_pretty(selectedTaskType!), () {
        setState(() {
          selectedTaskType = null;
        });
        load();
      }));
    }

    return chips;
  }

  void _openFiltersBottomSheet(BuildContext context, DateTime from, DateTime to) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            _sheetSetState = setSheetState;
            final dateLabel = customFrom != null && customTo != null
                ? '${_formatShortDate(customFrom!)} – ${_formatShortDate(customTo!)}'
                : 'By Date';

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
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
                    const SizedBox(height: 14),

                    // Top header: Icon + Title/Subtitle + Close button
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: _soft),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Timeframe row with grain selector
                    Row(
                      children: [
                        const Text(
                          'Timeframe',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        _buildGrainPill(),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Filter Dropdowns Wrap
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
                      const SizedBox(height: 14),
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
                        Icon(Icons.info_outline_rounded, size: 14, color: _soft),
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
                    const SizedBox(height: 18),

                    // Apply Filters Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: _taskBrown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _sheetSetState = null;
    });
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
