import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'all_tasks.dart';
import 'api.dart';
import 'create_task.dart';

/// Projects page displaying projects from:
/// `GET /projects?page=$page&pageSize=$pageSize&sortBy=$sortBy&sortDir=$sortDir`
/// Full filters support matching the official HR360 specification:
/// - Search name or code...
/// - By Status (Active, Archived, All)
/// - By Owner (lookup from /employees/lookup)
/// - Include archived (toggle)
/// - Sort: Name, Code, Created Date, Completion
/// - Direction: Ascending, Descending
/// - View toggle: Grid view / List view
/// - Visual project cards with completion progress, overdue badges, dates, and owner info.
class ProjectsPage extends StatefulWidget {
  final Api api;

  const ProjectsPage({
    super.key,
    required this.api,
  });

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  // Pagination State
  int _page = 1;
  int _pageSize = 20;
  int _totalItems = 0;
  int _totalPages = 1;
  String _sortBy = 'name';
  String _sortDir = 'asc';

  // Filters State
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _status; // null (All / By Status), 'ACTIVE', 'ARCHIVED'
  String? _ownerId; // UUID
  bool _includeArchived = false;

  // View Mode: Grid view is default as shown in the screenshot
  bool _isGridView = true;

  // Lookups Data
  List<Json> _employees = [];

  // Data & Loading State
  List<Json> _projects = [];
  bool _loading = true;
  Object? _error;

  Api get api => widget.api;

  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _cardBorder = Color(0xFFE8E2D9);
  static const Color _taskBrown = Color(0xFFBE5E38);
  static const Color _pageBg = Color(0xFFFAF8F5);
  static const Color _green = Color(0xFF16A34A);
  static const Color _red = Color(0xFFDC2626);

  final ScrollController _scrollController = ScrollController();

  static const List<Color> _palette = [
    Color(0xFF5B67F6), // Indigo/Purple
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Violet
    Color(0xFF14B8A6), // Teal
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await api.v1('GET', '/employees/lookup', query: {'limit': 50});
      if (!mounted) return;
      setState(() {
        if (res is List) {
          _employees = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (res is Map && res['items'] is List) {
          _employees = (res['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      });
    } catch (_) {}
  }

  Future<void> _loadProjects() async {
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
      if (_status != null && !_includeArchived) {
        queryParams['status'] = _status!;
      }
      if (_ownerId != null) {
        queryParams['ownerId'] = _ownerId!;
      }
      if (_includeArchived) {
        queryParams['includeArchived'] = 'true';
      }

      final res = await api.v1(
        'GET',
        '/projects',
        query: queryParams,
      );

      if (!mounted) return;

      setState(() {
        final dataMap = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
        final items = dataMap['items'];

        if (items is List) {
          _projects = items
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        } else if (res is List) {
          _projects = res
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        } else {
          _projects = [];
        }

        _page = (dataMap['page'] as num?)?.toInt() ?? _page;
        _pageSize = (dataMap['pageSize'] as num?)?.toInt() ?? _pageSize;
        _totalItems = (dataMap['totalItems'] as num?)?.toInt() ?? _projects.length;
        _totalPages = (dataMap['totalPages'] as num?)?.toInt() ??
            math.max(1, (_totalItems / _pageSize).ceil());

        _loading = false;
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
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

  void _clearAllFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _status = null;
      _ownerId = null;
      _includeArchived = false;
      _page = 1;
    });
    _loadProjects();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_searchQuery.isNotEmpty) count++;
    if (_status != null) count++;
    if (_ownerId != null) count++;
    if (_includeArchived) count++;
    return count;
  }

  void _goToPage(int targetPage) {
    if (targetPage < 1 || targetPage > _totalPages || targetPage == _page) return;
    setState(() => _page = targetPage);
    _loadProjects();
  }

  String? get _selectedOwnerName {
    if (_ownerId == null) return null;
    for (final emp in _employees) {
      if (emp['id'] == _ownerId) {
        return emp['fullName']?.toString() ?? emp['name']?.toString() ?? 'Owner';
      }
    }
    return 'Owner';
  }

  List<Json> get _filteredProjects {
    return _projects.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
        final code = (p['code'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
        final owner = (p['owner'] is Map ? (p['owner']['fullName'] ?? '') : (p['ownerName'] ?? '')).toString().toLowerCase();

        if (!name.contains(q) && !code.contains(q) && !desc.contains(q) && !owner.contains(q)) {
          return false;
        }
      }

      if (!_includeArchived && _status != null) {
        final pStatus = (p['status'] ?? 'ACTIVE').toString().toUpperCase();
        if (pStatus != _status!.toUpperCase()) return false;
      }

      if (_ownerId != null) {
        final pOwnerId = p['ownerId']?.toString() ??
            (p['owner'] is Map ? p['owner']['id']?.toString() : null);
        if (pOwnerId != _ownerId) return false;
      }

      return true;
    }).toList();
  }

  Color _getProjectColor(Json project, int index) {
    final colorHex = project['color']?.toString();
    if (colorHex != null && colorHex.isNotEmpty) {
      final clean = colorHex.replaceFirst('#', '');
      if (clean.length == 6) {
        final parsed = int.tryParse(clean, radix: 16);
        if (parsed != null) return Color(0xFF000000 | parsed);
      }
    }
    return _palette[index % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProjects;

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
          'Projects',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: _ink),
            onPressed: _loadProjects,
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
                      onCreated: _loadProjects,
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
            // ── Top Title & Subtitle Section (from Screenshot) ───
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Projects',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Group related tasks, track completion and overdue work per project.',
                      style: TextStyle(color: _soft, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),

            // ── Filter & Sort Panel (Matching Screenshot) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildFilterAndSortPanel(),
            ),
            const SizedBox(height: 12),

            // ── Projects Content (Grid or List) ───
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _taskBrown),
                    )
                  : _error != null
                      ? _buildErrorView()
                      : filtered.isEmpty
                          ? _buildEmptyView()
                          : _buildProjectsView(filtered),
            ),

            // ── Pagination Bar (Matching Screenshot) ───
            _buildPaginationBar(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ── FILTERS & SORT PANEL IMPLEMENTATION ──────────────────────
  // ─────────────────────────────────────────────────────────────

  Widget _buildFilterAndSortPanel() {
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
          _loadProjects();
        },
        style: const TextStyle(fontSize: 13, color: _ink),
        decoration: InputDecoration(
          hintText: 'Search name or code...',
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
                    _loadProjects();
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
      onClear: _status != null
          ? () {
              setState(() {
                _status = null;
                _page = 1;
              });
              _loadProjects();
            }
          : null,
    );

    final ownerBtn = _buildFilterDropdownButton(
      label: 'By Owner',
      prefixIcon: Icons.person_outline_rounded,
      valueText: _selectedOwnerName,
      isActive: _ownerId != null,
      onTap: _pickOwner,
      onClear: () {
        setState(() {
          _ownerId = null;
          _page = 1;
        });
        _loadProjects();
      },
    );

    final includeArchivedBtn = Material(
      color: _includeArchived ? _taskBrown.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _includeArchived = !_includeArchived;
            _page = 1;
          });
          _loadProjects();
        },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _includeArchived ? _taskBrown : const Color(0xFFE2E8F0),
              width: _includeArchived ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _includeArchived ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 16,
                color: _includeArchived ? _taskBrown : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'Include archived',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: _includeArchived ? FontWeight.w700 : FontWeight.w500,
                  color: _includeArchived ? _taskBrown : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final sortFieldBtn = _buildSortFieldDropdown();
    final sortDirBtn = _buildSortDirDropdown();
    final viewModeToggle = _buildViewModeToggle();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          // Row 1: Search, By Status, By Owner, Include archived
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: searchInput),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: statusBtn),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: ownerBtn),
                    const SizedBox(width: 8),
                    includeArchivedBtn,
                  ],
                );
              }

              return Column(
                children: [
                  searchInput,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: statusBtn),
                      const SizedBox(width: 6),
                      Expanded(child: ownerBtn),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: includeArchivedBtn),
                      if (_activeFiltersCount > 0) ...[
                        const SizedBox(width: 8),
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
          const SizedBox(height: 10),

          // Row 2: Sort: Name, Ascending/Descending, View Toggle
          Row(
            children: [
              if (_activeFiltersCount > 0 && MediaQuery.of(context).size.width >= 760)
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: _taskBrown.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              const Spacer(),
              sortFieldBtn,
              const SizedBox(width: 8),
              sortDirBtn,
              const SizedBox(width: 8),
              viewModeToggle,
            ],
          ),
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

  Widget _buildSortFieldDropdown() {
    final sortLabel = switch (_sortBy) {
      'code' => 'Sort: Code',
      'createdAt' => 'Sort: Created',
      'completion' => 'Sort: Completion',
      _ => 'Sort: Name',
    };

    return PopupMenuButton<String>(
      initialValue: _sortBy,
      tooltip: 'Sort by',
      onSelected: (val) {
        setState(() {
          _sortBy = val;
          _page = 1;
        });
        _loadProjects();
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'name', child: Text('Sort: Name')),
        const PopupMenuItem(value: 'code', child: Text('Sort: Code')),
        const PopupMenuItem(value: 'createdAt', child: Text('Sort: Created Date')),
        const PopupMenuItem(value: 'completion', child: Text('Sort: Completion')),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sortLabel,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDirDropdown() {
    final isAsc = _sortDir == 'asc';
    return PopupMenuButton<String>(
      initialValue: _sortDir,
      tooltip: 'Direction',
      onSelected: (val) {
        setState(() {
          _sortDir = val;
          _page = 1;
        });
        _loadProjects();
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'asc', child: Text('Ascending')),
        const PopupMenuItem(value: 'desc', child: Text('Descending')),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAsc ? 'Ascending' : 'Descending',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _isGridView = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: !_isGridView ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: !_isGridView
                    ? [const BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
                    : null,
              ),
              child: Icon(
                Icons.list_rounded,
                size: 18,
                color: !_isGridView ? _taskBrown : _soft,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _isGridView = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: _isGridView ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isGridView
                    ? [const BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
                    : null,
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: 18,
                color: _isGridView ? _taskBrown : _soft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ── MODAL PICKERS ────────────────────────────────────────────
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
                    const Text('Filter by Status', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                _buildStatusOption(ctx, 'Active', 'ACTIVE', _green),
                _buildStatusOption(ctx, 'Archived', 'ARCHIVED', _soft),
                ListTile(
                  leading: const Icon(Icons.clear_all_rounded, color: _ink),
                  title: const Text('All Statuses', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: _status == null ? const Icon(Icons.check, color: _taskBrown) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _status = null;
                      _page = 1;
                    });
                    _loadProjects();
                  },
                ),
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
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? _taskBrown : _ink)),
      trailing: isSelected ? const Icon(Icons.check, color: _taskBrown) : null,
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          _status = code;
          _page = 1;
        });
        _loadProjects();
      },
    );
  }

  void _pickOwner() {
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
            final filteredOwners = _employees.where((e) {
              if (filter.isEmpty) return true;
              final q = filter.toLowerCase();
              final name = (e['fullName'] ?? e['name'] ?? '').toString().toLowerCase();
              final code = (e['employeeCode'] ?? '').toString().toLowerCase();
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
                          const Text('Filter by Owner', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search owner name or code...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) => setLocalState(() => filter = val),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filteredOwners.isEmpty
                            ? const Center(child: Text('No employees found', style: TextStyle(color: _soft)))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredOwners.length,
                                itemBuilder: (context, idx) {
                                  final emp = filteredOwners[idx];
                                  final id = emp['id']?.toString() ?? '';
                                  final name = emp['fullName']?.toString() ?? emp['name']?.toString() ?? 'Employee';
                                  final code = emp['employeeCode']?.toString() ?? '';
                                  final isSelected = _ownerId == id;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: _taskBrown.withValues(alpha: 0.1),
                                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: const TextStyle(color: _taskBrown, fontWeight: FontWeight.w700, fontSize: 12)),
                                    ),
                                    title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
                                    subtitle: code.isNotEmpty ? Text(code, style: const TextStyle(fontSize: 11.5, color: _soft)) : null,
                                    trailing: isSelected ? const Icon(Icons.check, color: _taskBrown) : null,
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _ownerId = id;
                                        _page = 1;
                                      });
                                      _loadProjects();
                                    },
                                  );
                                },
                              ),
                      ),
                      if (_ownerId != null)
                        ListTile(
                          leading: const Icon(Icons.clear, color: _red),
                          title: const Text('Clear owner filter', style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _ownerId = null;
                              _page = 1;
                            });
                            _loadProjects();
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
  // ── PROJECTS VIEW (GRID OR LIST) ─────────────────────────────
  // ─────────────────────────────────────────────────────────────

  Widget _buildProjectsView(List<Json> projects) {
    if (_isGridView) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 780 ? 2 : 1;
          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: 200,
            ),
            itemCount: projects.length,
            itemBuilder: (context, i) => _buildProjectCard(projects[i], i),
          );
        },
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: projects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildProjectCard(projects[i], i),
    );
  }

  // ── Project Card (Matching Screenshot exactly) ────────────────
  Widget _buildProjectCard(Json project, int index) {
    final code = project['code']?.toString() ?? 'DEMO';
    final name = project['name']?.toString() ?? project['title']?.toString() ?? 'Project';
    final description = project['description']?.toString() ?? '';
    final status = project['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final accentColor = _getProjectColor(project, index);

    final owner = project['owner'] is Map
        ? (project['owner']['fullName'] ?? project['owner']['name'] ?? '')
        : (project['ownerName'] ?? 'Unassigned');

    final startDate = _formatShortDmy(project['startDate']?.toString());
    final endDate = _formatShortDmy(project['endDate']?.toString());
    final datesText = startDate != '—' && endDate != '—'
        ? '$startDate – $endDate'
        : (startDate != '—' ? 'Starts: $startDate' : 'No dates');

    final taskCounts = project['taskCounts'] is Map
        ? Map<String, dynamic>.from(project['taskCounts'])
        : <String, dynamic>{};

    final totalTasks = (taskCounts['total'] as num?)?.toInt() ??
        (project['totalTasks'] as num?)?.toInt() ??
        (project['tasksCount'] as num?)?.toInt() ??
        0;

    final completedTasks = (taskCounts['completed'] as num?)?.toInt() ??
        (project['completedTasks'] as num?)?.toInt() ??
        0;

    final overdueTasks = (taskCounts['overdue'] as num?)?.toInt() ??
        (project['overdueTasks'] as num?)?.toInt() ??
        0;

    final completionPercent = (taskCounts['completionPercent'] as num?)?.toInt() ??
        (totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0);

    final progressRatio = totalTasks > 0 ? (completedTasks / totalTasks).clamp(0.0, 1.0) : 0.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Tap navigates directly to All tasks filtered by this project
          final projId = project['id']?.toString();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AllTasksPage(
                api: api,
                initialProjectId: projId,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x061B2A4A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top colored accent bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code & Status Row
                    Row(
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Color(0xFF64748B),
                            fontFamily: 'monospace',
                          ),
                        ),
                        const Spacer(),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Project Title
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Description
                    Text(
                      description.isNotEmpty ? description : 'No description provided.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _soft,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Owner
                    Text(
                      'Owner: $owner',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _soft,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Dates
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: _soft),
                        const SizedBox(width: 4),
                        Text(
                          datesText,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _soft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Progress row: percent on left, overdue on right
                    Row(
                      children: [
                        Text(
                          '$completionPercent% complete',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        if (overdueTasks > 0)
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 13, color: _red),
                              const SizedBox(width: 3),
                              Text(
                                '$overdueTasks overdue',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _red,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Progress bar & counts
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressRatio,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progressRatio > 0 ? accentColor : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$completedTasks/$totalTasks',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
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
      case 'ARCHIVED':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        dot = const Color(0xFF94A3B8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.5,
            height: 5.5,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
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

  // ─────────────────────────────────────────────────────────────
  // ── PAGINATION BAR (Matching Screenshot) ─────────────────────
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
          PopupMenuButton<int>(
            initialValue: _pageSize,
            tooltip: 'Rows per page',
            onSelected: (val) {
              setState(() {
                _pageSize = val;
                _page = 1;
              });
              _loadProjects();
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
  // ── HELPERS & EMPTY STATES ───────────────────────────────────
  // ─────────────────────────────────────────────────────────────

  String _formatShortDmy(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _prettyFormat(String text) {
    final clean = text.toLowerCase().replaceAll('_', ' ');
    if (clean.isEmpty) return '';
    return clean[0].toUpperCase() + clean.substring(1);
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
              child: const Icon(Icons.folder_outlined, size: 36, color: _taskBrown),
            ),
            const SizedBox(height: 16),
            const Text(
              'No projects found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your search query, status or owner filter.',
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
            const Text(
              'Failed to load projects',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 6),
            Text(
              '$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _soft),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _loadProjects,
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
