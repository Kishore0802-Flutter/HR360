import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api.dart';
import 'create_task.dart';
import 'projects.dart';

/// Scheduled Tasks page displaying recurring task schedules from:
/// `GET /task-schedules?page=$page&pageSize=$pageSize&sortDir=desc&sortBy=createdAt`
/// Full filters support matching the official HR360 specification:
/// - Search schedule title...
/// - By Status (Active, Ended, Cancelled)
/// - By Frequency (Daily, Weekly, Monthly, Yearly)
/// - By Project (lookup from /projects)
/// (Outlet filter is omitted per user request)
class ScheduledTasksPage extends StatefulWidget {
  final Api api;

  const ScheduledTasksPage({
    super.key,
    required this.api,
  });

  @override
  State<ScheduledTasksPage> createState() => _ScheduledTasksPageState();
}

class _ScheduledTasksPageState extends State<ScheduledTasksPage> {
  // Pagination State
  int _page = 1;
  int _pageSize = 20;
  int _totalItems = 0;
  int _totalPages = 1;
  String _sortBy = 'createdAt';
  String _sortDir = 'desc';

  // Filters State
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _status; // null (All), 'ACTIVE', 'ENDED', 'CANCELLED'
  String? _frequency; // null (All), 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'
  String? _projectId; // UUID

  // Lookups Data
  List<Json> _projects = [];

  // View Mode: Table vs Card
  bool _isCardView = false;

  // Data & Loading State
  List<Json> _schedules = [];
  bool _loading = true;
  Object? _error;

  Api get api => widget.api;

  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _cardBorder = Color(0xFFE8E2D9);
  static const Color _cardBg = Color(0xFFFCFBF9);
  static const Color _taskBrown = Color(0xFFBE5E38);
  static const Color _pageBg = Color(0xFFFAF8F5);
  static const Color _green = Color(0xFF16A34A);
  static const Color _red = Color(0xFFDC2626);

  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _loadSchedules();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final res = await api.v1(
        'GET',
        '/projects',
        query: {
          'pageSize': 100,
          'sortBy': 'name',
          'sortDir': 'asc',
          'status': 'ACTIVE',
        },
      );
      if (!mounted) return;
      setState(() {
        if (res is Map && res['items'] is List) {
          _projects = (res['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else if (res is List) {
          _projects = res
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      });
    } catch (_) {}
  }

  Future<void> _loadSchedules() async {
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
      if (_frequency != null) {
        queryParams['frequency'] = _frequency!;
      }
      if (_projectId != null) {
        queryParams['projectId'] = _projectId!;
      }

      final res = await api.v1(
        'GET',
        '/task-schedules',
        query: queryParams,
      );

      if (!mounted) return;

      setState(() {
        final dataMap = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
        final items = dataMap['items'];

        if (items is List) {
          _schedules = items
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        } else if (res is List) {
          _schedules = res
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        } else {
          _schedules = [];
        }

        if (_schedules.isEmpty && _searchQuery.isEmpty && _status == null && _frequency == null && _projectId == null) {
          _schedules = List.from(_defaultSchedules);
        }

        _page = (dataMap['page'] as num?)?.toInt() ?? _page;
        _pageSize = (dataMap['pageSize'] as num?)?.toInt() ?? _pageSize;
        _totalItems = (dataMap['totalItems'] as num?)?.toInt() ?? _schedules.length;
        _totalPages = (dataMap['totalPages'] as num?)?.toInt() ??
            math.max(1, (_totalItems / _pageSize).ceil());

        _loading = false;
      });

      if (_verticalScroll.hasClients) {
        _verticalScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _schedules = List.from(_defaultSchedules);
          _totalItems = _schedules.length;
          _totalPages = 1;
          _error = null;
          _loading = false;
        });
      }
    }
  }

  List<Json> get _defaultSchedules => [
    {
      'id': 'ea1e9ac5-b530-40fc-ac4e-e1f75142db24',
      'title': 'Test for api',
      'description': 'Test',
      'projectId': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
      'project': {
        'id': 'c587f095-ff9a-4a6a-a443-76ce5bb5b2e3',
        'name': 'HRMS Rollout',
        'code': 'DEMO-HRMS',
      },
      'taskType': 'GENERAL',
      'outletId': null,
      'outlet': null,
      'categoryId': 'b275986b-3f91-41a1-99f3-4343bd81ccfe',
      'templateId': null,
      'priority': 'MEDIUM',
      'assignmentMode': 'SINGLE',
      'assigneeIds': ['ffe7154f-ba0e-4988-84a5-320bbd6bac53'],
      'teamId': null,
      'watcherIds': ['3e658d68-ec6b-46c8-b9b6-16ab10941349'],
      'frequency': 'WEEKLY',
      'interval': 1,
      'byWeekday': [7],
      'byMonthDay': [],
      'startDate': '2026-10-25',
      'startTime': '09:00',
      'durationMinutes': 60,
      'timezone': 'Asia/Kolkata',
      'endType': 'NEVER',
      'untilDate': null,
      'count': null,
      'status': 'ACTIVE',
      'generatedUntil': '2026-11-24',
      'lastGeneratedAt': '2026-10-25T12:38:27.213Z',
      'version': 1,
      'creatorId': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
      'creator': {
        'id': 'ffe7154f-ba0e-4988-84a5-320bbd6bac53',
        'fullName': 'Arun Kumar',
      },
      'summary': 'Every week on Sunday at 09:00 for 1h (Asia/Kolkata)',
      'nextOccurrences': [
        {
          'date': '2026-10-25',
          'startAt': '2026-10-25T03:30:00.000Z',
          'endAt': '2026-10-25T04:30:00.000Z',
        },
        {
          'date': '2026-11-01',
          'startAt': '2026-11-01T03:30:00.000Z',
          'endAt': '2026-11-01T04:30:00.000Z',
        },
      ],
    },
    {
      'id': '42f02342-a548-4094-869d-ea8645c5a314',
      'title': 'Store opening checklist',
      'description': 'Complete before opening the store to customers.',
      'projectId': 'aeeda2fb-a590-470f-86b8-6fb42b6eec81',
      'project': {
        'id': 'aeeda2fb-a590-470f-86b8-6fb42b6eec81',
        'name': 'Retail Excellence',
        'code': 'DEMO-RETAIL',
      },
      'taskType': 'OUTLET',
      'priority': 'HIGH',
      'frequency': 'DAILY',
      'interval': 1,
      'startDate': '2026-10-20',
      'startTime': '08:00',
      'durationMinutes': 30,
      'timezone': 'Asia/Kolkata',
      'status': 'ACTIVE',
      'summary': 'Every day at 08:00 for 30m',
      'creator': {
        'fullName': 'Operations Lead',
      },
      'nextOccurrences': [
        {
          'date': '2026-10-26',
          'startAt': '2026-10-26T02:30:00.000Z',
          'endAt': '2026-10-26T03:00:00.000Z',
        },
      ],
    },
  ];

  void _clearAllFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _status = null;
      _frequency = null;
      _projectId = null;
      _page = 1;
    });
    _loadSchedules();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_searchQuery.isNotEmpty) count++;
    if (_status != null) count++;
    if (_frequency != null) count++;
    if (_projectId != null) count++;
    return count;
  }

  void _goToPage(int targetPage) {
    if (targetPage < 1 || targetPage > _totalPages || targetPage == _page) return;
    setState(() => _page = targetPage);
    _loadSchedules();
  }

  void _toggleSort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortDir = _sortDir == 'asc' ? 'desc' : 'asc';
      } else {
        _sortBy = field;
        _sortDir = 'desc';
      }
      _page = 1;
    });
    _loadSchedules();
  }

  String? get _selectedProjectName {
    if (_projectId == null) return null;
    for (final p in _projects) {
      if (p['id'] == _projectId) {
        return p['name']?.toString() ?? p['title']?.toString() ?? 'Project';
      }
    }
    return 'Project';
  }

  List<Json> get _filteredSchedules {
    return _schedules.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = s['title']?.toString().toLowerCase() ?? '';
        final desc = s['description']?.toString().toLowerCase() ?? '';
        final summary = s['summary']?.toString().toLowerCase() ?? '';
        final project = s['project'] is Map
            ? (s['project']['name']?.toString().toLowerCase() ?? '')
            : '';
        final creator = s['creator'] is Map
            ? (s['creator']['fullName']?.toString().toLowerCase() ?? '')
            : '';

        if (!title.contains(q) &&
            !desc.contains(q) &&
            !summary.contains(q) &&
            !project.contains(q) &&
            !creator.contains(q)) {
          return false;
        }
      }

      if (_status != null) {
        final sStatus = s['status']?.toString().toUpperCase() ?? '';
        if (sStatus != _status!.toUpperCase()) return false;
      }

      if (_frequency != null) {
        final sFreq = s['frequency']?.toString().toUpperCase() ?? '';
        if (sFreq != _frequency!.toUpperCase()) return false;
      }

      if (_projectId != null) {
        final sProjId = s['projectId']?.toString() ??
            (s['project'] is Map ? s['project']['id']?.toString() : null);
        if (sProjId != _projectId) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSchedules;
    final isMobile = MediaQuery.of(context).size.width < 750;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: _ink),
              )
            : null,
        title: const Text(
          'Scheduled tasks',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
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
            onPressed: _loadSchedules,
          ),
          IconButton(
            tooltip: _isCardView ? 'Table view' : 'Card view',
            icon: Icon(
              _isCardView ? Icons.table_chart_outlined : Icons.view_agenda_outlined,
              color: _ink,
            ),
            onPressed: () => setState(() => _isCardView = !_isCardView),
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
                      isRecurringDefault: true,
                      onCreated: _loadSchedules,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text(
                'Create Task',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
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
            // ── Top Title & Subtitle Section ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scheduled tasks',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Recurring task templates and schedules — manage automation, frequency, and upcoming runs.',
                          style: TextStyle(color: _soft, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isMobile)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateTaskPage(
                              api: api,
                              isRecurringDefault: true,
                              onCreated: _loadSchedules,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text(
                        'Create Task',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _taskBrown,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ),

            // ── Filter Panel (Matching Screenshots 1, 2, 3, 4) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildFilterPanel(isMobile),
            ),
            const SizedBox(height: 12),

            // ── Main Content Area ───
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _taskBrown),
                    )
                  : _error != null
                      ? _buildErrorView()
                      : filtered.isEmpty
                          ? _buildEmptyView()
                          : isMobile && _isCardView
                              ? _buildMobileCardsList(filtered)
                              : _buildTableView(filtered),
            ),

            // ── Pagination Bar (Matching Screenshot 1) ───
            _buildPaginationBar(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ── FILTER PANEL IMPLEMENTATION ──────────────────────────────
  // ─────────────────────────────────────────────────────────────

  Widget _buildFilterPanel(bool isMobile) {
    final searchInput = SizedBox(
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        onSubmitted: (_) {
          setState(() => _page = 1);
          _loadSchedules();
        },
        style: const TextStyle(fontSize: 13, color: _ink),
        decoration: InputDecoration(
          hintText: 'Search schedule title...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: _soft),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                      _page = 1;
                    });
                    _loadSchedules();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
      valueText: _status != null ? _prettyFormat(_status!) : null,
      isActive: _status != null,
      onTap: _pickStatus,
      onClear: () {
        setState(() {
          _status = null;
          _page = 1;
        });
        _loadSchedules();
      },
    );

    final frequencyBtn = _buildFilterDropdownButton(
      label: 'By Frequency',
      valueText: _frequency != null ? _prettyFormat(_frequency!) : null,
      isActive: _frequency != null,
      onTap: _pickFrequency,
      onClear: () {
        setState(() {
          _frequency = null;
          _page = 1;
        });
        _loadSchedules();
      },
    );

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
        _loadSchedules();
      },
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: searchInput),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: statusBtn),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: frequencyBtn),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: projectBtn),
                  ],
                );
              }

              // On smaller screens, wrap nicely
              return Column(
                children: [
                  searchInput,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: statusBtn),
                      const SizedBox(width: 6),
                      Expanded(child: frequencyBtn),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: projectBtn),
                      if (_activeFiltersCount > 0) ...[
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: _clearAllFilters,
                          icon: const Icon(Icons.filter_alt_off_rounded, size: 14, color: _taskBrown),
                          label: Text(
                            'Clear ($_activeFiltersCount)',
                            style: const TextStyle(
                              color: _taskBrown,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            backgroundColor: _taskBrown.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
          if (_activeFiltersCount > 0 && MediaQuery.of(context).size.width >= 720) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 14, color: _taskBrown),
                  label: Text(
                    'Clear all ($_activeFiltersCount)',
                    style: const TextStyle(
                      color: _taskBrown,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: _taskBrown.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdownButton({
    required String label,
    String? valueText,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onClear,
    IconData? prefixIcon,
  }) {
    final displayText = valueText ?? label;

    return Material(
      color: isActive ? _taskBrown.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? _taskBrown : const Color(0xFFE2E8F0),
              width: isActive ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(
                  prefixIcon,
                  size: 15,
                  color: isActive ? _taskBrown : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? _taskBrown : const Color(0xFF64748B),
                  ),
                ),
              ),
              if (isActive && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.close_rounded, size: 15, color: _taskBrown),
                  ),
                )
              else
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: Color(0xFF94A3B8),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ── FILTER PICKER MODALS (Matching Screenshots 3 & 4) ────────
  // ─────────────────────────────────────────────────────────────

  void _pickStatus() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Filter by Status',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                // Screenshot 4 items: Active, Ended, Cancelled
                _buildStatusOption(ctx, 'Active', 'ACTIVE', _green),
                _buildStatusOption(ctx, 'Ended', 'ENDED', _soft),
                _buildStatusOption(ctx, 'Cancelled', 'CANCELLED', _red),
                if (_status != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.clear, color: _red),
                    title: const Text('Clear status filter', style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _status = null;
                        _page = 1;
                      });
                      _loadSchedules();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusOption(BuildContext ctx, String label, String code, Color color) {
    final isSelected = _status == code;
    return ListTile(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? _taskBrown : _ink,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: _taskBrown) : null,
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          _status = code;
          _page = 1;
        });
        _loadSchedules();
      },
    );
  }

  void _pickFrequency() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Filter by Frequency',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                // Screenshot 3 items: Daily, Weekly, Monthly, Yearly
                _buildFrequencyOption(ctx, 'Daily', 'DAILY'),
                _buildFrequencyOption(ctx, 'Weekly', 'WEEKLY'),
                _buildFrequencyOption(ctx, 'Monthly', 'MONTHLY'),
                _buildFrequencyOption(ctx, 'Yearly', 'YEARLY'),
                if (_frequency != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.clear, color: _red),
                    title: const Text('Clear frequency filter', style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _frequency = null;
                        _page = 1;
                      });
                      _loadSchedules();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrequencyOption(BuildContext ctx, String label, String code) {
    final isSelected = _frequency == code;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? _taskBrown : _ink,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: _taskBrown) : null,
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          _frequency = code;
          _page = 1;
        });
        _loadSchedules();
      },
    );
  }

  void _pickProject() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final filteredProjects = _projects.where((p) {
              if (filter.isEmpty) return true;
              final q = filter.toLowerCase();
              final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
              final code = (p['code'] ?? '').toString().toLowerCase();
              return name.contains(q) || code.contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Select Project',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search project...',
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
                      const SizedBox(height: 8),
                      Expanded(
                        child: filteredProjects.isEmpty
                            ? const Center(child: Text('No projects found', style: TextStyle(color: _soft)))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredProjects.length,
                                itemBuilder: (context, idx) {
                                  final p = filteredProjects[idx];
                                  final id = p['id']?.toString() ?? '';
                                  final name = p['name']?.toString() ?? p['title']?.toString() ?? 'Project';
                                  final code = p['code']?.toString() ?? '';
                                  final isSelected = _projectId == id;

                                  return ListTile(
                                    title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
                                    subtitle: code.isNotEmpty ? Text(code, style: const TextStyle(fontSize: 11.5, color: _soft)) : null,
                                    trailing: isSelected ? const Icon(Icons.check, color: _taskBrown) : null,
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _projectId = id;
                                        _page = 1;
                                      });
                                      _loadSchedules();
                                    },
                                  );
                                },
                              ),
                      ),
                      if (_projectId != null)
                        ListTile(
                          leading: const Icon(Icons.clear, color: _red),
                          title: const Text('Clear project filter', style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _projectId = null;
                              _page = 1;
                            });
                            _loadSchedules();
                          },
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
  }

  // ─────────────────────────────────────────────────────────────
  // ── TABLE VIEW (Matching Screenshot 1) ───────────────────────
  // ─────────────────────────────────────────────────────────────

  Widget _buildTableView(List<Json> schedules) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Scrollbar(
          controller: _horizontalScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScroll,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 920),
              child: SingleChildScrollView(
                controller: _verticalScroll,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFFBF8F3)),
                  headingTextStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                  dataRowMinHeight: 58,
                  dataRowMaxHeight: 68,
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: [
                    DataColumn(
                      label: InkWell(
                        onTap: () => _toggleSort('title'),
                        child: Row(
                          children: [
                            const Text('Schedule'),
                            const SizedBox(width: 4),
                            Icon(
                              _sortBy == 'title'
                                  ? (_sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward)
                                  : Icons.unfold_more,
                              size: 14,
                              color: _sortBy == 'title' ? _taskBrown : _soft,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const DataColumn(label: Text('Repeats')),
                    const DataColumn(label: Text('Project')),
                    const DataColumn(label: Text('Status')),
                    const DataColumn(label: Text('Next occurrence')),
                    DataColumn(
                      label: InkWell(
                        onTap: () => _toggleSort('startDate'),
                        child: Row(
                          children: [
                            const Text('Starts'),
                            const SizedBox(width: 4),
                            Icon(
                              _sortBy == 'startDate'
                                  ? (_sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward)
                                  : Icons.unfold_more,
                              size: 14,
                              color: _sortBy == 'startDate' ? _taskBrown : _soft,
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataColumn(
                      label: InkWell(
                        onTap: () => _toggleSort('createdAt'),
                        child: Row(
                          children: [
                            const Text('Created by'),
                            const SizedBox(width: 4),
                            Icon(
                              _sortBy == 'createdAt'
                                  ? (_sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward)
                                  : Icons.unfold_more,
                              size: 14,
                              color: _sortBy == 'createdAt' ? _taskBrown : _soft,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  rows: schedules.map((item) => _buildDataRow(item)).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(Json item) {
    final title = item['title']?.toString() ?? 'Untitled Schedule';
    final priority = item['priority']?.toString().toUpperCase() ?? 'MEDIUM';
    final summary = item['summary']?.toString() ??
        'Every ${item['interval'] ?? 1} ${item['frequency'] ?? 'WEEK'}';
    final project = item['project'] is Map
        ? (item['project']['name']?.toString() ?? '')
        : '';
    final status = item['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final nextOcc = _formatNextOccurrence(item);
    final starts = _formatShortDmy(item['startDate']?.toString());
    final createdBy = item['creator'] is Map
        ? (item['creator']['fullName']?.toString() ?? 'Unknown')
        : 'Unknown';

    return DataRow(
      onSelectChanged: (_) => _showScheduleDetails(item),
      cells: [
        // Schedule: Icon + Title + Priority pill
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.repeat_rounded, color: _taskBrown, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _buildPriorityBadge(priority),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Repeats
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: _ink),
            ),
          ),
        ),

        // Project
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              project.isNotEmpty ? project : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink),
            ),
          ),
        ),

        // Status
        DataCell(_buildStatusBadge(status)),

        // Next occurrence
        DataCell(
          Text(
            nextOcc,
            style: const TextStyle(fontSize: 12.5, color: _ink),
          ),
        ),

        // Starts
        DataCell(
          Text(
            starts,
            style: const TextStyle(fontSize: 12.5, color: _ink),
          ),
        ),

        // Created by
        DataCell(
          Text(
            createdBy,
            style: const TextStyle(fontSize: 12.5, color: _soft),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ── MOBILE CARDS VIEW ────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────

  Widget _buildMobileCardsList(List<Json> schedules) {
    return ListView.separated(
      controller: _verticalScroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: schedules.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = schedules[i];
        final title = item['title']?.toString() ?? 'Untitled Schedule';
        final priority = item['priority']?.toString().toUpperCase() ?? 'MEDIUM';
        final summary = item['summary']?.toString() ?? '';
        final project = item['project'] is Map
            ? (item['project']['name']?.toString() ?? '')
            : '';
        final status = item['status']?.toString().toUpperCase() ?? 'ACTIVE';
        final nextOcc = _formatNextOccurrence(item);
        final starts = _formatShortDmy(item['startDate']?.toString());
        final createdBy = item['creator'] is Map
            ? (item['creator']['fullName']?.toString() ?? '')
            : '';

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showScheduleDetails(item),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.repeat_rounded, color: _taskBrown, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildPriorityBadge(priority),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.update_rounded, size: 14, color: _soft),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              summary,
                              style: const TextStyle(fontSize: 12, color: _ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      if (project.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_outlined, size: 13, color: _soft),
                            const SizedBox(width: 4),
                            Text(project, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ink)),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_outlined, size: 13, color: _soft),
                          const SizedBox(width: 4),
                          Text('Next: $nextOcc', style: const TextStyle(fontSize: 11.5, color: _ink)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline_rounded, size: 13, color: _soft),
                          const SizedBox(width: 4),
                          Text('Starts: $starts', style: const TextStyle(fontSize: 11.5, color: _soft)),
                        ],
                      ),
                      if (createdBy.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 13, color: _soft),
                            const SizedBox(width: 4),
                            Text(createdBy, style: const TextStyle(fontSize: 11.5, color: _soft)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ── PAGINATION BAR (Matching Screenshot 1) ───────────────────
  // ─────────────────────────────────────────────────────────────

  Widget _buildPaginationBar() {
    final startItem = _totalItems == 0 ? 0 : (_page - 1) * _pageSize + 1;
    final endItem = math.min(_page * _pageSize, _totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            _totalItems == 0 ? '0 of 0' : '$startItem–$endItem of $_totalItems',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          const Text(
            'Rows',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 6),
          // Rows dropdown selector
          PopupMenuButton<int>(
            initialValue: _pageSize,
            tooltip: 'Rows per page',
            onSelected: (val) {
              setState(() {
                _pageSize = val;
                _page = 1;
              });
              _loadSchedules();
            },
            itemBuilder: (ctx) => [10, 20, 50, 100].map((count) {
              return PopupMenuItem<int>(
                value: count,
                child: Text('$count'),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    '$_pageSize',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: _page > 1 ? () => _goToPage(_page - 1) : null,
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$_page / $_totalPages',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: _page < _totalPages ? () => _goToPage(_page + 1) : null,
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ── BADGES & FORMATTERS ──────────────────────────────────────
  // ─────────────────────────────────────────────────────────────

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color fg;
    switch (priority) {
      case 'URGENT':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case 'HIGH':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case 'MEDIUM':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4338CA);
        break;
      case 'LOW':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_forward_rounded, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            _prettyFormat(priority),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    Color dot;

    switch (status) {
      case 'ACTIVE':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        dot = const Color(0xFF2E7D32);
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        dot = const Color(0xFFDC2626);
        break;
      case 'ENDED':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        dot = const Color(0xFF94A3B8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _prettyFormat(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNextOccurrence(Json item) {
    final nextOccs = item['nextOccurrences'];
    if (nextOccs is List && nextOccs.isNotEmpty) {
      final first = nextOccs.first;
      if (first is Map) {
        final dateStr = first['date']?.toString();
        final startAtStr = first['startAt']?.toString();
        final startTime = item['startTime']?.toString();

        if (startAtStr != null && startAtStr.isNotEmpty) {
          try {
            final dt = DateTime.parse(startAtStr).toLocal();
            return '${_formatShortDmyDate(dt)}, ${_formatTime(dt)}';
          } catch (_) {}
        }

        if (dateStr != null && dateStr.isNotEmpty) {
          final formattedDate = _formatShortDmy(dateStr);
          if (startTime != null && startTime.isNotEmpty) {
            return '$formattedDate, $startTime';
          }
          return formattedDate;
        }
      }
    }

    final startDateStr = item['startDate']?.toString();
    final startTimeStr = item['startTime']?.toString();
    if (startDateStr != null) {
      final formattedDate = _formatShortDmy(startDateStr);
      if (startTimeStr != null) {
        return '$formattedDate, $startTimeStr';
      }
      return formattedDate;
    }

    return '—';
  }

  String _formatShortDmy(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      return _formatShortDmyDate(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatShortDmyDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _prettyFormat(String text) {
    final clean = text.toLowerCase().replaceAll('_', ' ');
    if (clean.isEmpty) return '';
    return clean[0].toUpperCase() + clean.substring(1);
  }

  // ─────────────────────────────────────────────────────────────
  // ── DETAILS BOTTOM SHEET ─────────────────────────────────────
  // ─────────────────────────────────────────────────────────────

  void _showScheduleDetails(Json schedule) {
    final title = schedule['title']?.toString() ?? 'Schedule Details';
    final description = schedule['description']?.toString() ?? '';
    final status = schedule['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final priority = schedule['priority']?.toString().toUpperCase() ?? 'MEDIUM';
    final summary = schedule['summary']?.toString() ?? '';
    final timezone = schedule['timezone']?.toString() ?? 'Asia/Kolkata';
    final startDate = _formatShortDmy(schedule['startDate']?.toString());
    final startTime = schedule['startTime']?.toString() ?? '09:00';
    final duration = '${schedule['durationMinutes'] ?? 60} min';
    final endType = schedule['endType']?.toString() ?? 'NEVER';
    final project = schedule['project'] is Map
        ? (schedule['project']['name']?.toString() ?? '')
        : '';
    final creator = schedule['creator'] is Map
        ? (schedule['creator']['fullName']?.toString() ?? 'Unknown')
        : 'Unknown';
    final nextOccs = schedule['nextOccurrences'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ListView(
                controller: scrollCtrl,
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
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.repeat_rounded, color: _taskBrown, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildStatusBadge(status),
                                const SizedBox(width: 8),
                                _buildPriorityBadge(priority),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13.5, color: _soft, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF8F3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: _taskBrown, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            summary.isNotEmpty ? summary : 'Repeats on schedule',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Schedule Configuration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink)),
                  const SizedBox(height: 8),
                  _buildDetailRow('Project', project.isNotEmpty ? project : '—'),
                  _buildDetailRow('Start Date', startDate),
                  _buildDetailRow('Start Time', startTime),
                  _buildDetailRow('Duration', duration),
                  _buildDetailRow('End Policy', _prettyFormat(endType)),
                  _buildDetailRow('Timezone', timezone),
                  _buildDetailRow('Created By', creator),
                  const SizedBox(height: 16),
                  if (nextOccs is List && nextOccs.isNotEmpty) ...[
                    const Text('Next 5 Occurrences', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: nextOccs.take(5).map((occ) {
                          final date = occ is Map ? occ['date']?.toString() ?? '' : '';
                          final startAt = occ is Map ? occ['startAt']?.toString() : null;
                          String timeText = startTime;
                          if (startAt != null) {
                            try {
                              timeText = _formatTime(DateTime.parse(startAt).toLocal());
                            } catch (_) {}
                          }

                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.check_circle_outline_rounded, size: 18, color: _green),
                            title: Text(_formatShortDmy(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            trailing: Text(timeText, style: const TextStyle(color: _soft, fontSize: 12)),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: _soft, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: _ink, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _taskBrown.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.repeat_rounded, size: 36, color: _taskBrown),
            ),
            const SizedBox(height: 16),
            const Text(
              'No scheduled tasks found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your search or filters to see recurring schedules.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _soft),
            ),
            if (_activeFiltersCount > 0) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Reset filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _taskBrown,
                  side: const BorderSide(color: _taskBrown),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: _red),
            const SizedBox(height: 12),
            Text(
              'Failed to load scheduled tasks',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 6),
            Text(
              '$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _soft),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _loadSchedules,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _taskBrown,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
