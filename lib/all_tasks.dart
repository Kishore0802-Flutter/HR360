import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api.dart';
import 'create_task.dart';
import 'design.dart';
import 'projects.dart';
import 'scheduled_tasks.dart';

/// All Tasks page displaying paginated tasks from:
/// `GET /tasks?page=$page&pageSize=$pageSize&sortDir=desc&sortBy=createdAt`
/// Full filters support matching the official HR360 specification:
/// - By Task Name (search)
/// - By Status (TODO, IN_PROGRESS, COMPLETED, CANCELLED)
/// - By Priority (LOW, MEDIUM, HIGH, URGENT)
/// - By Type (GENERAL, OUTLET)
/// - By Project (lookup from /projects)
/// - By Team (lookup from /teams)
/// - By Category (lookup from /task-categories)
/// - By Assignee (lookup from /employees/lookup)
/// - By Creator (lookup from /employees/lookup)
/// - By Due Date (Today, This week, This month, Last 30 days, Custom range...)
/// - Toggle chips: Overdue, Due soon, Unassigned, Include subtasks
/// - List / Grid view switcher
/// - Full pagination controls (<<, <, page/totalPages, >, >>)
class AllTasksPage extends StatefulWidget {
  final Api api;
  final String? initialTaskType;
  final String? initialProjectId;

  const AllTasksPage({
    super.key,
    required this.api,
    this.initialTaskType,
    this.initialProjectId,
  });

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage> {
  // Pagination State
  int _page = 1;
  int _pageSize = 20;
  int _totalItems = 0;
  int _totalPages = 1;
  final String _sortBy = 'createdAt';
  final String _sortDir = 'desc';

  // Filters State
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _status; // null (All), TODO, IN_PROGRESS, COMPLETED, CANCELLED
  String? _priority; // null (All), LOW, MEDIUM, HIGH, URGENT
  String? _taskType; // null (All), GENERAL, OUTLET
  String? _projectId; // UUID
  String? _teamId; // UUID
  String? _categoryId; // UUID
  String? _assigneeId; // UUID
  String? _creatorId; // UUID
  String? _dueDatePreset; // 'Today', 'This week', 'This month', 'Last 30 days', 'Custom'
  DateTime? _dueFrom;
  DateTime? _dueTo;

  // Toggle Chips State
  bool _isOverdue = false;
  bool _isDueSoon = false;
  bool _isUnassigned = false;
  bool _includeSubtasks = false;

  // View Mode
  bool _isGridView = false;

  // Lookups Data
  List<Json> _projects = [];
  List<Json> _teams = [];
  List<Json> _categories = [];
  List<Json> _employees = [];

  // Data & Loading State
  List<Json> _tasks = [];
  bool _loading = true;
  Object? _error;

  Api get api => widget.api;

  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _line = Color(0xFFE2E8F0);
  static const Color _cardBorder = Color(0xFFE8E2D9);
  static const Color _cardBg = Color(0xFFFCFBF9);
  static const Color _taskBrown = Color(0xFFBE5E38);
  static const Color _pageBg = Color(0xFFFAF8F5);
  static const Color _green = Color(0xFF16A34A);
  static const Color _red = Color(0xFFDC2626);
  static const Color _amber = Color(0xFFD97706);
  static const Color _blue = Color(0xFF2563EB);

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialTaskType != null) {
      _taskType = widget.initialTaskType;
    }
    if (widget.initialProjectId != null) {
      _projectId = widget.initialProjectId;
    }
    _loadLookups();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        api.v1(
          'GET',
          '/projects',
          query: {
            'pageSize': 50,
            'sortBy': 'name',
            'sortDir': 'asc',
            'status': 'ACTIVE',
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
          '/task-categories',
          query: {
            'pageSize': 200,
            'status': 'ACTIVE',
            'sortBy': 'name',
            'sortDir': 'asc',
          },
        ).catchError((_) => null),
        api.v1(
          'GET',
          '/employees/lookup',
          query: {'limit': 100},
        ).catchError((_) => null),
      ]);

      if (!mounted) return;
      setState(() {
        final pData = results[0];
        if (pData is Map && pData['items'] is List) {
          _projects = _asList(pData['items']);
        } else if (pData is List) {
          _projects = _asList(pData);
        }

        final tData = results[1];
        if (tData is Map && tData['items'] is List) {
          _teams = _asList(tData['items']);
        } else if (tData is List) {
          _teams = _asList(tData);
        }

        final cData = results[2];
        if (cData is Map && cData['items'] is List) {
          _categories = _asList(cData['items']);
        } else if (cData is List) {
          _categories = _asList(cData);
        }

        final eData = results[3];
        if (eData is List) {
          _employees = _asList(eData);
        } else if (eData is Map && eData['items'] is List) {
          _employees = _asList(eData['items']);
        }
      });
    } catch (_) {}
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final queryParams = <String, dynamic>{
        'page': _page,
        'pageSize': _pageSize,
        'sortBy': _sortBy,
        'sortDir': _sortDir,
      };

      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }
      if (_status != null) {
        queryParams['status'] = _status!;
      }
      if (_priority != null) {
        queryParams['priority'] = _priority!;
      }
      if (_taskType != null) {
        queryParams['taskType'] = _taskType!;
      }
      if (_projectId != null) {
        queryParams['projectId'] = _projectId!;
      }
      if (_teamId != null) {
        queryParams['teamId'] = _teamId!;
      }
      if (_categoryId != null) {
        queryParams['categoryId'] = _categoryId!;
      }
      if (_assigneeId != null) {
        queryParams['assigneeId'] = _assigneeId!;
      }
      if (_creatorId != null) {
        queryParams['creatorId'] = _creatorId!;
      }
      if (_dueFrom != null) {
        queryParams['dueFrom'] = _dueFrom!.toUtc().toIso8601String();
      }
      if (_dueTo != null) {
        queryParams['dueTo'] = _dueTo!.toUtc().toIso8601String();
      }
      if (_isOverdue) {
        queryParams['overdue'] = 'true';
      }
      if (_isDueSoon) {
        queryParams['dueSoon'] = 'true';
      }
      if (_isUnassigned) {
        queryParams['unassigned'] = 'true';
      }
      if (_includeSubtasks) {
        queryParams['includeSubtasks'] = 'true';
      }

      final res = await api.v1(
        'GET',
        '/tasks',
        query: queryParams,
      );

      if (!mounted) return;

      setState(() {
        final dataMap = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
        final items = dataMap['items'];

        if (items is List) {
          _tasks = items
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        } else if (res is List) {
          _tasks = res
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        } else {
          _tasks = [];
        }

        _page = (dataMap['page'] as num?)?.toInt() ?? _page;
        _pageSize = (dataMap['pageSize'] as num?)?.toInt() ?? _pageSize;
        _totalItems = (dataMap['totalItems'] as num?)?.toInt() ?? _tasks.length;
        _totalPages = (dataMap['totalPages'] as num?)?.toInt() ??
            math.max(1, (_totalItems / _pageSize).ceil());

        _loading = false;
      });

      // Scroll to top upon page change
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _goToPage(int targetPage) {
    if (targetPage < 1 || targetPage > _totalPages || targetPage == _page) return;
    setState(() => _page = targetPage);
    _loadTasks();
  }

  void _clearAllFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _status = null;
      _priority = null;
      _taskType = null;
      _projectId = null;
      _teamId = null;
      _categoryId = null;
      _assigneeId = null;
      _creatorId = null;
      _dueDatePreset = null;
      _dueFrom = null;
      _dueTo = null;
      _isOverdue = false;
      _isDueSoon = false;
      _isUnassigned = false;
      _includeSubtasks = false;
      _page = 1;
    });
    _loadTasks();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_searchQuery.isNotEmpty) count++;
    if (_status != null) count++;
    if (_priority != null) count++;
    if (_taskType != null) count++;
    if (_projectId != null) count++;
    if (_teamId != null) count++;
    if (_categoryId != null) count++;
    if (_assigneeId != null) count++;
    if (_creatorId != null) count++;
    if (_dueFrom != null || _dueTo != null) count++;
    if (_isOverdue) count++;
    if (_isDueSoon) count++;
    if (_isUnassigned) count++;
    if (_includeSubtasks) count++;
    return count;
  }

  List<Json> get _filteredTasks {
    return _tasks.where((t) {
      if (_isOverdue && t['isOverdue'] != true) return false;
      if (_status != null && t['status']?.toString().toUpperCase() != _status!.toUpperCase()) return false;
      if (_priority != null && t['priority']?.toString().toUpperCase() != _priority!.toUpperCase()) return false;
      if (_taskType != null && t['taskType']?.toString().toUpperCase() != _taskType!.toUpperCase()) return false;

      if (_isUnassigned) {
        final assignees = t['assignees'];
        if (assignees is List && assignees.isNotEmpty) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final code = t['code']?.toString().toLowerCase() ?? '';
        final title = t['title']?.toString().toLowerCase() ?? '';
        final desc = t['description']?.toString().toLowerCase() ?? '';
        final project = t['project'] is Map ? (t['project']['name']?.toString().toLowerCase() ?? '') : '';
        final category = t['category'] is Map ? (t['category']['name']?.toString().toLowerCase() ?? '') : '';

        final matchesAssignee = (t['assignees'] is List) &&
            (t['assignees'] as List).any((a) {
              final name = a is Map ? (a['fullName']?.toString().toLowerCase() ?? '') : '';
              return name.contains(q);
            });

        final matches = code.contains(q) ||
            title.contains(q) ||
            desc.contains(q) ||
            project.contains(q) ||
            category.contains(q) ||
            matchesAssignee;

        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: _ink),
              )
            : null,
        title: const Text(
          'All tasks',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Scheduled tasks',
            icon: const Icon(Icons.repeat_rounded, color: _ink),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScheduledTasksPage(api: api),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Projects',
            icon: const Icon(Icons.folder_outlined, color: _ink),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectsPage(api: api),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: _ink),
            onPressed: _loadTasks,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateTaskPage(
                      api: api,
                      onCreated: _loadTasks,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Create task', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: _taskBrown,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Title & Subtitle Section (from Screenshot 1) ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All tasks',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Every task you can see — filter by project, team, assignee, status, priority or due date.',
                          style: TextStyle(color: _soft, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick create button on top
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateTaskPage(
                            api: api,
                            onCreated: _loadTasks,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Create task', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _taskBrown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Comprehensive Filter Panel Card (Matching Screenshots 1 & 2) ──
            _buildFullFilterPanel(),

            // ── Quick Status Filter Pills (For test & fast 1-tap filter) ──
            _buildQuickStatusPills(),

            // ── Task List / Grid Content ──────────────────────────────
            Expanded(
              child: _buildBody(),
            ),

            // ── Pagination Footer ─────────────────────────────────────
            _buildPaginationBar(),
          ],
        ),
      ),
    );
  }

  // ── Full Filter Panel (Screenshots 1 & 2) ────────────────────────────────
  Widget _buildFullFilterPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x041B2A4A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: By Task Name, By Status, By Priority, By Type
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 650;
              final searchWidget = SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) {
                    setState(() => _searchQuery = v.trim());
                    // Debounce or filter
                  },
                  onSubmitted: (_) {
                    setState(() => _page = 1);
                    _loadTasks();
                  },
                  style: const TextStyle(fontSize: 13, color: _ink),
                  decoration: InputDecoration(
                    hintText: 'By Task Name',
                    hintStyle: const TextStyle(color: Color(0xFF8B93A7), fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8B93A7)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 15, color: _soft),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _searchQuery = '';
                                _page = 1;
                              });
                              _loadTasks();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFDCD6CD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFDCD6CD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _taskBrown, width: 1.5),
                    ),
                  ),
                ),
              );

              final statusBtn = _buildFilterDropdownButton(
                label: 'By Status',
                valueText: _status != null ? _pretty(_status!) : null,
                isActive: _status != null,
                onTap: _pickStatus,
                onClear: () {
                  setState(() {
                    _status = null;
                    _page = 1;
                  });
                  _loadTasks();
                },
              );

              final priorityBtn = _buildFilterDropdownButton(
                label: 'By Priority',
                valueText: _priority != null ? _pretty(_priority!) : null,
                isActive: _priority != null,
                onTap: _pickPriority,
                onClear: () {
                  setState(() {
                    _priority = null;
                    _page = 1;
                  });
                  _loadTasks();
                },
              );

              final typeBtn = _buildFilterDropdownButton(
                label: 'By Type',
                valueText: _taskType != null ? (_taskType == 'GENERAL' ? 'General' : 'Outlet') : null,
                isActive: _taskType != null,
                onTap: _pickTaskType,
                onClear: () {
                  setState(() {
                    _taskType = null;
                    _page = 1;
                  });
                  _loadTasks();
                },
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: searchWidget),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: statusBtn),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: priorityBtn),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: typeBtn),
                  ],
                );
              }

              return Column(
                children: [
                  searchWidget,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: statusBtn),
                      const SizedBox(width: 6),
                      Expanded(child: priorityBtn),
                      const SizedBox(width: 6),
                      Expanded(child: typeBtn),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Row 2: By Project, By Team, By Category, By Assignee Name...
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 650;
              final projectBtn = _buildFilterDropdownButton(
                label: 'By Project',
                valueText: _selectedProjectName,
                isActive: _projectId != null,
                onTap: _pickProject,
                onClear: () {
                  setState(() {
                    _projectId = null;
                    _page = 1;
                  });
                  _loadTasks();
                },
              );

              final teamBtn = _buildFilterDropdownButton(
                label: 'By Team',
                valueText: _selectedTeamName,
                isActive: _teamId != null,
                onTap: _pickTeam,
                onClear: () {
                  setState(() {
                    _teamId = null;
                    _page = 1;
                  });
                  _loadTasks();
                },
              );

              final categoryBtn = _buildFilterDropdownButton(
                label: 'By Category',
                valueText: _selectedCategoryName,
                isActive: _categoryId != null,
                onTap: _pickCategory,
                onClear: () {
                  setState(() {
                    _categoryId = null;
                    _page = 1;
                  });
                  _loadTasks();
                },
              );

              final assigneeBtn = _buildFilterDropdownButton(
                prefixIcon: Icons.person_outline_rounded,
                label: 'By Assignee N...',
                valueText: _selectedAssigneeName,
                isActive: _assigneeId != null,
                onTap: () => _pickEmployee(isAssignee: true),
                onClear: () {
                  setState(() {
                    _assigneeId = null;
                    _page = 1;
                  });
                  _loadTasks();
                },
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: projectBtn),
                    const SizedBox(width: 8),
                    Expanded(child: teamBtn),
                    const SizedBox(width: 8),
                    Expanded(child: categoryBtn),
                    const SizedBox(width: 8),
                    Expanded(child: assigneeBtn),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: projectBtn),
                      const SizedBox(width: 6),
                      Expanded(child: teamBtn),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: categoryBtn),
                      const SizedBox(width: 6),
                      Expanded(child: assigneeBtn),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Row 3: By Creator, By Due Date, Overdue, Due soon, Unassigned, Include subtasks, View toggle
          LayoutBuilder(
            builder: (context, constraints) {
              final creatorBtn = _buildFilterDropdownButton(
                prefixIcon: Icons.person_outline_rounded,
                label: 'By Creator',
                valueText: _selectedCreatorName,
                isActive: _creatorId != null,
                onTap: () => _pickEmployee(isAssignee: false),
                onClear: () {
                  setState(() {
                    _creatorId = null;
                    _page = 1;
                  });
                  _loadTasks();
                },
              );

              final dueDateBtn = _buildFilterDropdownButton(
                prefixIcon: Icons.calendar_today_outlined,
                label: 'By Due Date',
                valueText: _dueDatePreset,
                isActive: _dueDatePreset != null || _dueFrom != null,
                onTap: _pickDueDatePreset,
                onClear: () {
                  setState(() {
                    _dueDatePreset = null;
                    _dueFrom = null;
                    _dueTo = null;
                    _page = 1;
                  });
                  _loadTasks();
                },
              );

              final overdueChip = _buildToggleChip('Overdue', _isOverdue, () {
                setState(() {
                  _isOverdue = !_isOverdue;
                  _page = 1;
                });
                _loadTasks();
              });

              final dueSoonChip = _buildToggleChip('Due soon', _isDueSoon, () {
                setState(() {
                  _isDueSoon = !_isDueSoon;
                  _page = 1;
                });
                _loadTasks();
              });

              final unassignedChip = _buildToggleChip('Unassigned', _isUnassigned, () {
                setState(() {
                  _isUnassigned = !_isUnassigned;
                  _page = 1;
                });
                _loadTasks();
              });

              final subtasksChip = _buildToggleChip('Include subtasks', _includeSubtasks, () {
                setState(() {
                  _includeSubtasks = !_includeSubtasks;
                  _page = 1;
                });
                _loadTasks();
              });

              final viewModeToggle = _buildViewModeToggle();

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: 140, child: creatorBtn),
                  SizedBox(width: 145, child: dueDateBtn),
                  overdueChip,
                  dueSoonChip,
                  unassignedChip,
                  subtasksChip,
                  viewModeToggle,
                  if (_activeFiltersCount > 0)
                    TextButton.icon(
                      onPressed: _clearAllFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 14, color: _taskBrown),
                      label: Text(
                        'Clear ($_activeFiltersCount)',
                        style: const TextStyle(color: _taskBrown, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  // ── Quick Status Filter Pills (For test & fast 1-tap filter) ────────────
  Widget _buildQuickStatusPills() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _statusPill(null, 'All'),
            _statusPill('TODO', 'To Do'),
            _statusPill('IN_PROGRESS', 'In Progress'),
            _statusPill('COMPLETED', 'Completed'),
            _statusPill('OVERDUE_ONLY', 'Overdue'),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String? statusKey, String label) {
    final active = (statusKey == null && _status == null && !_isOverdue) ||
        (statusKey == 'OVERDUE_ONLY' && _isOverdue) ||
        (statusKey != null && statusKey != 'OVERDUE_ONLY' && _status == statusKey);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _page = 1;
            if (statusKey == 'OVERDUE_ONLY') {
              _isOverdue = true;
              _status = null;
            } else {
              _isOverdue = false;
              _status = statusKey;
            }
          });
          _loadTasks();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _taskBrown : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? _taskBrown : _line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _ink,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter Dropdown Button Component ────────────────────────────────────
  Widget _buildFilterDropdownButton({
    IconData? prefixIcon,
    required String label,
    required String? valueText,
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFCE9DA) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? _taskBrown : const Color(0xFFDCD6CD),
            width: isActive ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefixIcon != null) ...[
              Icon(prefixIcon, size: 14.5, color: isActive ? _taskBrown : _soft),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                valueText ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? _taskBrown : _ink,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (isActive)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 14, color: _taskBrown),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _soft),
          ],
        ),
      ),
    );
  }

  // ── Toggle Chip Component (Overdue, Due soon, Unassigned, etc.) ─────────
  Widget _buildToggleChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFCE9DA) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _taskBrown : const Color(0xFFDCD6CD),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 14, color: _taskBrown),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _taskBrown : _ink,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── View Mode Switcher [List | Grid] (Screenshot 1 bottom right) ───────
  Widget _buildViewModeToggle() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCD6CD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // List icon
          InkWell(
            onTap: () {
              if (_isGridView) setState(() => _isGridView = false);
            },
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: !_isGridView ? const Color(0xFFF1EBE4) : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
              ),
              child: Icon(
                Icons.format_list_bulleted_rounded,
                size: 17,
                color: !_isGridView ? _taskBrown : _soft,
              ),
            ),
          ),
          Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
          // Grid icon
          InkWell(
            onTap: () {
              if (!_isGridView) setState(() => _isGridView = true);
            },
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: _isGridView ? const Color(0xFFF1EBE4) : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: 17,
                color: _isGridView ? _taskBrown : _soft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pickers Implementation ──────────────────────────────────────────────
  void _pickStatus() {
    _showOptionsSheet(
      title: 'Filter by Status',
      options: [
        (null, 'All statuses'),
        ('TODO', 'To Do'),
        ('IN_PROGRESS', 'In Progress'),
        ('COMPLETED', 'Completed'),
        ('CANCELLED', 'Cancelled'),
      ],
      selected: _status,
      onSelect: (val) {
        setState(() {
          _status = val;
          _page = 1;
        });
        _loadTasks();
      },
    );
  }

  void _pickPriority() {
    _showOptionsSheet(
      title: 'Filter by Priority',
      options: [
        (null, 'All priorities'),
        ('LOW', 'Low'),
        ('MEDIUM', 'Medium'),
        ('HIGH', 'High'),
        ('URGENT', 'Urgent'),
      ],
      selected: _priority,
      onSelect: (val) {
        setState(() {
          _priority = val;
          _page = 1;
        });
        _loadTasks();
      },
    );
  }

  void _pickTaskType() {
    _showOptionsSheet(
      title: 'Filter by Type',
      options: [
        (null, 'All types'),
        ('GENERAL', 'General task'),
        ('OUTLET', 'Outlet / site task'),
      ],
      selected: _taskType,
      onSelect: (val) {
        setState(() {
          _taskType = val;
          _page = 1;
        });
        _loadTasks();
      },
    );
  }

  void _pickProject() {
    final opts = [
      (null, 'All projects'),
      for (final p in _projects)
        (p['id']?.toString(), p['name']?.toString() ?? 'Project'),
    ];
    _showOptionsSheet(
      title: 'Filter by Project',
      options: opts,
      selected: _projectId,
      onSelect: (val) {
        setState(() {
          _projectId = val;
          _page = 1;
        });
        _loadTasks();
      },
    );
  }

  void _pickTeam() {
    final opts = [
      (null, 'All teams'),
      for (final t in _teams)
        (t['id']?.toString(), t['name']?.toString() ?? 'Team'),
    ];
    _showOptionsSheet(
      title: 'Filter by Team',
      options: opts,
      selected: _teamId,
      onSelect: (val) {
        setState(() {
          _teamId = val;
          _page = 1;
        });
        _loadTasks();
      },
    );
  }

  void _pickCategory() {
    final opts = [
      (null, 'All categories'),
      for (final c in _categories)
        (c['id']?.toString(), c['name']?.toString() ?? 'Category'),
    ];
    _showOptionsSheet(
      title: 'Filter by Category',
      options: opts,
      selected: _categoryId,
      onSelect: (val) {
        setState(() {
          _categoryId = val;
          _page = 1;
        });
        _loadTasks();
      },
    );
  }

  void _pickEmployee({required bool isAssignee}) {
    final opts = [
      (null, isAssignee ? 'All assignees' : 'All creators'),
      for (final e in _employees)
        (
          e['id']?.toString(),
          '${e['fullName'] ?? 'Employee'}${e['employeeCode'] != null ? ' (${e['employeeCode']})' : ''}'
        ),
    ];
    _showOptionsSheet(
      title: isAssignee ? 'Filter by Assignee' : 'Filter by Creator',
      options: opts,
      selected: isAssignee ? _assigneeId : _creatorId,
      onSelect: (val) {
        setState(() {
          if (isAssignee) {
            _assigneeId = val;
          } else {
            _creatorId = val;
          }
          _page = 1;
        });
        _loadTasks();
      },
    );
  }

  // ── Due Date Presets Picker (Screenshot 2) ──────────────────────────────
  void _pickDueDatePreset() {
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
                    const Icon(Icons.calendar_today_outlined, size: 18, color: _taskBrown),
                    const SizedBox(width: 8),
                    const Text(
                      'Filter by Due Date',
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
              ),
              const Divider(height: 16),
              ListTile(
                title: const Text('Today', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _dueDatePreset == 'Today' ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  setState(() {
                    _dueDatePreset = 'Today';
                    _dueFrom = DateTime(now.year, now.month, now.day);
                    _dueTo = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
                    _page = 1;
                  });
                  _loadTasks();
                },
              ),
              ListTile(
                title: const Text('This week', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _dueDatePreset == 'This week' ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final monday = now.subtract(Duration(days: now.weekday - 1));
                  final sunday = monday.add(const Duration(days: 6));
                  setState(() {
                    _dueDatePreset = 'This week';
                    _dueFrom = DateTime(monday.year, monday.month, monday.day);
                    _dueTo = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
                    _page = 1;
                  });
                  _loadTasks();
                },
              ),
              ListTile(
                title: const Text('This month', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _dueDatePreset == 'This month' ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, 1);
                  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
                  setState(() {
                    _dueDatePreset = 'This month';
                    _dueFrom = start;
                    _dueTo = end;
                    _page = 1;
                  });
                  _loadTasks();
                },
              ),
              ListTile(
                title: const Text('Last 30 days', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _dueDatePreset == 'Last 30 days' ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final thirtyAgo = now.subtract(const Duration(days: 30));
                  setState(() {
                    _dueDatePreset = 'Last 30 days';
                    _dueFrom = DateTime(thirtyAgo.year, thirtyAgo.month, thirtyAgo.day);
                    _dueTo = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
                    _page = 1;
                  });
                  _loadTasks();
                },
              ),
              ListTile(
                title: const Text('Custom range...', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: (_dueDatePreset != null &&
                        !['Today', 'This week', 'This month', 'Last 30 days'].contains(_dueDatePreset))
                    ? const Icon(Icons.check, color: _taskBrown)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDateRange: _dueFrom != null && _dueTo != null
                        ? DateTimeRange(start: _dueFrom!, end: _dueTo!)
                        : DateTimeRange(start: now, end: now.add(const Duration(days: 7))),
                  );
                  if (picked != null) {
                    setState(() {
                      _dueFrom = DateTime(picked.start.year, picked.start.month, picked.start.day);
                      _dueTo = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
                      _dueDatePreset = '${_formatShortDmy(_dueFrom!)} - ${_formatShortDmy(_dueTo!)}';
                      _page = 1;
                    });
                    _loadTasks();
                  }
                },
              ),
              if (_dueFrom != null || _dueTo != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.clear, color: _red),
                  title: const Text('Clear due date filter', style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _dueDatePreset = null;
                      _dueFrom = null;
                      _dueTo = null;
                      _page = 1;
                    });
                    _loadTasks();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet<T>({
    required String title,
    required List<(T?, String)> options,
    required T? selected,
    required ValueChanged<T?> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: options.length > 8,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16.5,
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
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final opt = options[i];
                    final isSelected = opt.$1 == selected;
                    return ListTile(
                      title: Text(
                        opt.$2,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? _taskBrown : _ink,
                          fontSize: 13.5,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: _taskBrown) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelect(opt.$1);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body Builder (List or Grid View) ────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const DashboardShimmer();
    }

    if (_error != null) {
      return FailureView(_error!, _loadTasks);
    }

    final filtered = _filteredTasks;
    if (filtered.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: _line),
                ),
                child: const Icon(Icons.task_alt_rounded, size: 32, color: _soft),
              ),
              const SizedBox(height: 16),
              const Text(
                'No tasks found',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _activeFiltersCount > 0
                    ? 'No tasks match the selected filters. Try clearing some filters.'
                    : 'No tasks found for this view.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _soft, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (_activeFiltersCount > 0)
                OutlinedButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Reset all filters', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _taskBrown,
                    side: const BorderSide(color: _taskBrown),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateTaskPage(
                          api: api,
                          onCreated: _loadTasks,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create a task', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _taskBrown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _taskBrown,
      onRefresh: _loadTasks,
      child: _isGridView
          ? GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) => _buildGridTaskCard(filtered[i]),
            )
          : ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _buildTaskCard(filtered[i]),
            ),
    );
  }

  // ── Task Card (List View) ───────────────────────────────────────────────
  Widget _buildTaskCard(Json task) {
    final project = task['project'] is Map ? Map<String, dynamic>.from(task['project']) : <String, dynamic>{};
    final category = task['category'] is Map ? Map<String, dynamic>.from(task['category']) : <String, dynamic>{};
    final color = _parseHexColor(project['color']) ?? _taskBrown;

    final overdue = task['isOverdue'] == true;
    final due = task['dueAt']?.toString();
    final start = task['startAt']?.toString();
    final subtasks = _toInt(task['subtaskCount']);
    final completedSubtasks = _toInt(task['subtaskCompleted']);
    final isRecurring = task['scheduleId'] != null;

    final assignees = (task['assignees'] is List)
        ? (task['assignees'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];

    final watchers = (task['watchers'] is List)
        ? (task['watchers'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];

    final priority = task['priority']?.toString() ?? 'MEDIUM';
    final status = task['status']?.toString() ?? 'TODO';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTaskDetails(task),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Project color indicator bar
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Metadata Row: Code, Recurring icon, Priority Tag, Status Tag
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      task['code']?.toString() ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _soft,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  if (isRecurring) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3E8FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.autorenew_rounded, size: 10.5, color: Color(0xFF7C3AED)),
                                          SizedBox(width: 2.5),
                                          Text(
                                            'Series',
                                            style: TextStyle(
                                              color: Color(0xFF7C3AED),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildPriorityTag(priority),
                            const SizedBox(width: 5),
                            _buildStatusTag(status),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Title
                        Text(
                          task['title']?.toString() ?? 'Untitled Task',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),

                        // Project & Category subtitle
                        if (project['name'] != null || category['name'] != null) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (project['name'] != null) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    project['name'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _soft,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (project['name'] != null && category['name'] != null)
                                const Text(' · ', style: TextStyle(color: _soft)),
                              if (category['name'] != null)
                                Flexible(
                                  child: Text(
                                    category['name'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _soft, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Due Date & Subtasks Info
                        Row(
                          children: [
                            Icon(
                              overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
                              size: 14.5,
                              color: overdue ? _red : _soft,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                due == null
                                    ? (start == null ? 'No due date' : 'Starts ${_formatDate(start)}')
                                    : '${overdue ? 'Overdue · ' : 'Due '}${_formatDate(due)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: overdue ? _red : _ink,
                                  fontSize: 12,
                                  fontWeight: overdue ? FontWeight.w700 : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (subtasks > 0) ...[
                              const Icon(Icons.checklist_rounded, size: 14, color: _soft),
                              const SizedBox(width: 3),
                              Text(
                                '$completedSubtasks/$subtasks',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (watchers.isNotEmpty) ...[
                              const Icon(Icons.visibility_outlined, size: 13, color: _soft),
                              const SizedBox(width: 2),
                              Text(
                                '${watchers.length}',
                                style: const TextStyle(
                                  color: _soft,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Assignees footer
                        if (assignees.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildAssigneeAvatars(assignees),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  assignees.map((a) => a['fullName']?.toString() ?? '').join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _soft,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }

  // ── Task Card (Grid View) ───────────────────────────────────────────────
  Widget _buildGridTaskCard(Json task) {
    final project = task['project'] is Map ? Map<String, dynamic>.from(task['project']) : <String, dynamic>{};
    final color = _parseHexColor(project['color']) ?? _taskBrown;
    final overdue = task['isOverdue'] == true;
    final due = task['dueAt']?.toString();
    final priority = task['priority']?.toString() ?? 'MEDIUM';
    final status = task['status']?.toString() ?? 'TODO';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showTaskDetails(task),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 12,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    task['code']?.toString() ?? '',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.w700, color: _soft),
                  ),
                  const Spacer(),
                  _buildPriorityTag(priority),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  task['title']?.toString() ?? 'Task',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(height: 4),
              _buildStatusTag(status),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(overdue ? Icons.warning_amber_rounded : Icons.event_outlined, size: 12, color: overdue ? _red : _soft),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      due == null ? 'No due date' : _formatDate(due),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: overdue ? _red : _soft, fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatars(List<Json> assignees) {
    if (assignees.isEmpty) return const SizedBox.shrink();
    final first = assignees.first;
    final name = first['fullName']?.toString() ?? 'A';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return CircleAvatar(
      radius: 9,
      backgroundColor: const Color(0xFFFCE9DA),
      child: Text(
        initial,
        style: const TextStyle(
          color: _taskBrown,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
    );
  }

  // ── Pagination Bar ──────────────────────────────────────────────────────
  Widget _buildPaginationBar() {
    final startIdx = _totalItems == 0 ? 0 : (_page - 1) * _pageSize + 1;
    final endIdx = math.min(_page * _pageSize, _totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          // Items count summary
          Expanded(
            child: Text(
              _totalItems == 0
                  ? '0 tasks'
                  : '$startIdx–$endIdx of $_totalItems',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _soft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Pagination buttons: [<<] [<] [ 1 ] [ 2 ] [>] [>>]
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First page button
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 19),
                onPressed: _page > 1 ? () => _goToPage(1) : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              // Prev page button
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: _page > 1 ? () => _goToPage(_page - 1) : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),

              // Active Page Indicator Pill
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _taskBrown,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$_page / $_totalPages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),

              // Next page button
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: _page < _totalPages ? () => _goToPage(_page + 1) : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              // Last page button
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 19),
                onPressed: _page < _totalPages ? () => _goToPage(_totalPages) : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Task Details Bottom Sheet ───────────────────────────────────────────
  void _showTaskDetails(Json task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _TaskDetailSheet(
        task: task,
        api: api,
        onRefreshNeeded: _loadTasks,
      ),
    );
  }

  // ── Visual Tags & Helpers ───────────────────────────────────────────────
  Widget _buildPriorityTag(String priority) {
    final (bg, fg) = switch (priority.toUpperCase()) {
      'URGENT' => (const Color(0xFFFEE2E2), _red),
      'HIGH' => (const Color(0xFFFCE9DA), _taskBrown),
      'MEDIUM' => (const Color(0xFFFEF3C7), _amber),
      _ => (const Color(0xFFF1F5F9), _soft),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _pretty(priority),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    final (bg, fg) = switch (status.toUpperCase()) {
      'COMPLETED' || 'RESOLVED' => (const Color(0xFFDCFCE7), _green),
      'IN_PROGRESS' => (const Color(0xFFDBEAFE), _blue),
      'CANCELLED' => (const Color(0xFFF1F5F9), _soft),
      _ => (const Color(0xFFFEF3C7), const Color(0xFF92400E)), // TODO
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _pretty(status),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String? get _selectedProjectName {
    if (_projectId == null) return null;
    final match = _projects.cast<Json?>().firstWhere(
      (p) => p?['id']?.toString() == _projectId,
      orElse: () => null,
    );
    return match?['name']?.toString() ?? 'Project';
  }

  String? get _selectedTeamName {
    if (_teamId == null) return null;
    final match = _teams.cast<Json?>().firstWhere(
      (t) => t?['id']?.toString() == _teamId,
      orElse: () => null,
    );
    return match?['name']?.toString() ?? 'Team';
  }

  String? get _selectedCategoryName {
    if (_categoryId == null) return null;
    final match = _categories.cast<Json?>().firstWhere(
      (c) => c?['id']?.toString() == _categoryId,
      orElse: () => null,
    );
    return match?['name']?.toString() ?? 'Category';
  }

  String? get _selectedAssigneeName {
    if (_assigneeId == null) return null;
    final match = _employees.cast<Json?>().firstWhere(
      (e) => e?['id']?.toString() == _assigneeId,
      orElse: () => null,
    );
    return match?['fullName']?.toString() ?? 'Assignee';
  }

  String? get _selectedCreatorName {
    if (_creatorId == null) return null;
    final match = _employees.cast<Json?>().firstWhere(
      (e) => e?['id']?.toString() == _creatorId,
      orElse: () => null,
    );
    return match?['fullName']?.toString() ?? 'Creator';
  }

  String _formatDate(String isoString) {
    final d = DateTime.tryParse(isoString);
    if (d == null) return isoString;
    final local = d.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final timeStr = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '${local.day} ${months[local.month - 1]} ${local.year}, $timeStr';
  }

  String _formatShortDmy(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  Color? _parseHexColor(Object? val) {
    if (val == null) return null;
    final text = val.toString().replaceAll('#', '');
    if (text.length != 6) return null;
    final num = int.tryParse(text, radix: 16);
    return num == null ? null : Color(0xFF000000 | num);
  }

  int _toInt(Object? val) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  String _pretty(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// ── Task Detail Bottom Sheet ──────────────────────────────────────────────
class _TaskDetailSheet extends StatefulWidget {
  final Json task;
  final Api api;
  final VoidCallback onRefreshNeeded;

  const _TaskDetailSheet({
    required this.task,
    required this.api,
    required this.onRefreshNeeded,
  });

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  bool _updatingStatus = false;

  Json get task => widget.task;
  Api get api => widget.api;

  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _line = Color(0xFFE2E8F0);
  static const Color _taskBrown = Color(0xFFBE5E38);

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updatingStatus = true);
    try {
      final taskId = task['id']?.toString() ?? '';
      await api.v1(
        'PATCH',
        '/tasks/$taskId/status',
        body: {'status': newStatus},
      );
      if (!mounted) return;
      message(context, 'Status updated to ${_pretty(newStatus)}');
      widget.onRefreshNeeded();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = task['project'] is Map ? Map<String, dynamic>.from(task['project']) : <String, dynamic>{};
    final category = task['category'] is Map ? Map<String, dynamic>.from(task['category']) : <String, dynamic>{};
    final creator = task['creator'] is Map ? Map<String, dynamic>.from(task['creator']) : <String, dynamic>{};
    final schedule = task['schedule'] is Map ? Map<String, dynamic>.from(task['schedule']) : <String, dynamic>{};

    final assignees = (task['assignees'] is List)
        ? (task['assignees'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];

    final watchers = (task['watchers'] is List)
        ? (task['watchers'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];

    final status = task['status']?.toString() ?? 'TODO';
    final priority = task['priority']?.toString() ?? 'MEDIUM';
    final isOverdue = task['isOverdue'] == true;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D7DE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  // Top Code + Priority + Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task['code']?.toString() ?? 'TASK',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _badge(priority, const Color(0xFFFCE9DA), _taskBrown),
                      const SizedBox(width: 6),
                      _badge(status, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    task['title']?.toString() ?? 'Task',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),

                  // Description
                  if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _line),
                      ),
                      child: Text(
                        task['description'].toString(),
                        style: const TextStyle(color: _ink, fontSize: 13.5, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Project & Category Card
                  _sectionHeader('Context'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      children: [
                        _detailRow('Project', project['name']?.toString() ?? 'None'),
                        const Divider(height: 18, color: _line),
                        _detailRow('Category', category['name']?.toString() ?? 'None'),
                        const Divider(height: 18, color: _line),
                        _detailRow('Task Type', _pretty(task['taskType']?.toString() ?? 'GENERAL')),
                        if (creator['fullName'] != null) ...[
                          const Divider(height: 18, color: _line),
                          _detailRow('Created by', creator['fullName'].toString()),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Schedule Card
                  _sectionHeader('Schedule'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      children: [
                        if (task['startAt'] != null)
                          _detailRow('Starts At', _formatIso(task['startAt'].toString())),
                        if (task['startAt'] != null)
                          const Divider(height: 18, color: _line),
                        _detailRow(
                          'Due Date',
                          task['dueAt'] != null
                              ? '${_formatIso(task['dueAt'].toString())}${isOverdue ? ' (Overdue)' : ''}'
                              : 'None',
                        ),
                        if (task['durationMinutes'] != null) ...[
                          const Divider(height: 18, color: _line),
                          _detailRow('Duration', '${task['durationMinutes']} mins'),
                        ],
                        if (task['timezone'] != null) ...[
                          const Divider(height: 18, color: _line),
                          _detailRow('Timezone', task['timezone'].toString()),
                        ],
                        if (schedule['summary'] != null) ...[
                          const Divider(height: 18, color: _line),
                          _detailRow('Recurrence', schedule['summary'].toString()),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // People
                  _sectionHeader('People'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assignees',
                          style: TextStyle(color: _soft, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        if (assignees.isEmpty)
                          const Text('None', style: TextStyle(color: _ink, fontSize: 13))
                        else
                          for (final a in assignees)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFFFCE9DA),
                                    child: Text(
                                      (a['fullName']?.toString() ?? 'A')[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 10, color: _taskBrown, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    a['fullName']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                                  ),
                                  if (a['employeeCode'] != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${a['employeeCode']})',
                                      style: const TextStyle(fontSize: 11.5, color: _soft),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        if (watchers.isNotEmpty) ...[
                          const Divider(height: 20, color: _line),
                          const Text(
                            'Watchers',
                            style: TextStyle(color: _soft, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          for (final w in watchers)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.visibility_outlined, size: 14, color: _soft),
                                  const SizedBox(width: 8),
                                  Text(
                                    w['fullName']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Action Buttons
                  if (status != 'COMPLETED') ...[
                    Row(
                      children: [
                        if (status != 'IN_PROGRESS')
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _updatingStatus ? null : () => _updateStatus('IN_PROGRESS'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Start task', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        if (status != 'IN_PROGRESS') const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _updatingStatus ? null : () => _updateStatus('COMPLETED'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Complete task', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: _soft, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        _pretty(text),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatIso(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final l = d.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${l.day} ${months[l.month - 1]} ${l.year}, ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String _pretty(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

List<Json> _asList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}
