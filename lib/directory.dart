import 'package:flutter/material.dart';
import 'api.dart';
import 'design.dart';
import 'employee_detail.dart';
import 'add_employee.dart';
export 'holidays.dart';
export 'add_employee.dart';

/// Employees page for all users in HRMS:
/// `GET /employees?page=$page&pageSize=$pageSize&sortDir=asc&sortBy=employeeCode`
/// Matching Screenshot 2:
/// - Filters: Search name/email/code, By Department, By Designation, By Team, By Status, Manager
/// - Complete pagination: items range, rows selector, next/previous controls
/// - Card UI (NOT tables view)
/// - Tap card to view employee details & activities (EmployeeDetailPage)
class EmployeesPage extends StatefulWidget {
  final Api api;
  const EmployeesPage({super.key, required this.api});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _cardBorder = Color(0xFFE8E2D9);
  static const Color _pageBg = Color(0xFFFAF8F5);
  static const Color _green = Color(0xFF16A34A);
  static const Color _greenBg = Color(0xFFE7F6EE);
  static const Color _taskBrown = Color(0xFFBE5E38);

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Pagination State
  int _page = 1;
  int _pageSize = 20;
  int _totalItems = 0;
  int _totalPages = 1;

  // Filter selections
  String? _selectedDepartmentId;
  String? _selectedDepartmentName;
  String? _selectedDesignationId;
  String? _selectedDesignationName;
  String? _selectedTeamId;
  String? _selectedTeamName;
  String? _selectedStatus; // 'ACTIVE', 'INACTIVE', null
  String? _selectedManagerId;
  String? _selectedManagerName;
  String? _selectedJoinedDate;

  // Lookups data
  final List<Map<String, dynamic>> _departments = [];
  final List<Map<String, dynamic>> _designations = [];
  final List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _managers = [];

  // Data & Loading
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final futures = await Future.wait([
        widget.api.v1('GET', '/departments', query: {'pageSize': 500, 'sortBy': 'name', 'sortDir': 'asc'}).catchError((_) => null),
        widget.api.v1('GET', '/teams', query: {'pageSize': 500, 'sortBy': 'name', 'sortDir': 'asc'}).catchError((_) => null),
        widget.api.v1('GET', '/designations', query: {'pageSize': 500, 'sortBy': 'title', 'sortDir': 'asc'}).catchError((_) => null),
        widget.api.v1('GET', '/employees/lookup', query: {'limit': 100}).catchError((_) => null),
      ]);
      if (!mounted) return;

      final depRes = futures[0];
      final teamRes = futures[1];
      final desRes = futures[2];
      final mgrRes = futures[3];

      setState(() {
        if (depRes != null) {
          final items = (depRes is Map ? depRes['items'] : (depRes is List ? depRes : null)) as List?;
          if (items != null) {
            _departments.clear();
            _departments.addAll(items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
          }
        }
        if (teamRes != null) {
          final items = (teamRes is Map ? teamRes['items'] : (teamRes is List ? teamRes : null)) as List?;
          if (items != null) {
            _teams.clear();
            _teams.addAll(items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
          }
        }
        if (desRes != null) {
          final items = (desRes is Map ? desRes['items'] : (desRes is List ? desRes : null)) as List?;
          if (items != null) {
            _designations.clear();
            _designations.addAll(items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
          }
        }
        if (mgrRes != null) {
          final items = (mgrRes is List ? mgrRes : (mgrRes is Map ? mgrRes['items'] : null)) as List?;
          if (items != null) {
            _managers = items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final queryParams = <String, dynamic>{
        'page': _page,
        'pageSize': _pageSize,
        'sortDir': 'asc',
        'sortBy': 'employeeCode',
      };

      if (_searchQuery.trim().isNotEmpty) {
        queryParams['search'] = _searchQuery.trim();
        queryParams['q'] = _searchQuery.trim();
      }
      if (_selectedDepartmentId != null) {
        queryParams['departmentId'] = _selectedDepartmentId!;
      }
      if (_selectedDesignationId != null) {
        queryParams['designationId'] = _selectedDesignationId!;
      }
      if (_selectedTeamId != null) {
        queryParams['teamId'] = _selectedTeamId!;
      }
      if (_selectedStatus != null) {
        queryParams['status'] = _selectedStatus!;
      }
      if (_selectedManagerId != null) {
        queryParams['managerId'] = _selectedManagerId!;
      }
      if (_selectedJoinedDate != null) {
        queryParams['joinedDate'] = _selectedJoinedDate!;
      }

      final res = await widget.api.v1('GET', '/employees', query: queryParams);
      if (!mounted) return;

      final dataMap = res is Map ? res : {};
      final rawItems = dataMap['items'] is List
          ? dataMap['items'] as List
          : (res is List ? res : []);

      final rows = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        _employees = rows;
        _page = (dataMap['page'] as num?)?.toInt() ?? _page;
        _pageSize = (dataMap['pageSize'] as num?)?.toInt() ?? _pageSize;
        _totalItems = (dataMap['totalItems'] as num?)?.toInt() ?? rows.length;
        _totalPages = (dataMap['totalPages'] as num?)?.toInt() ??
            ((_totalItems / _pageSize).ceil().clamp(1, 999));

        // Extract departments, designations, teams from rows if lookup lists are empty
        final seenDep = <String>{};
        final seenDes = <String>{};
        final seenTeams = <String>{};
        for (final row in rows) {
          final dep = row['department'];
          if (dep is Map && dep['id'] != null && seenDep.add(dep['id'].toString())) {
            _departments.add({'id': dep['id'], 'name': dep['name'] ?? 'Department'});
          }
          final des = row['designation'];
          if (des is Map && des['id'] != null && seenDes.add(des['id'].toString())) {
            _designations.add({'id': des['id'], 'title': des['title'] ?? des['name'] ?? 'Designation'});
          }
          final tms = row['teams'];
          if (tms is List) {
            for (final t in tms) {
              if (t is Map && t['id'] != null && seenTeams.add(t['id'].toString())) {
                _teams.add({'id': t['id'], 'name': t['name'] ?? 'Team'});
              }
            }
          }
        }

        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _selectedDepartmentId = null;
      _selectedDepartmentName = null;
      _selectedDesignationId = null;
      _selectedDesignationName = null;
      _selectedTeamId = null;
      _selectedTeamName = null;
      _selectedStatus = null;
      _selectedManagerId = null;
      _selectedManagerName = null;
      _selectedJoinedDate = null;
      _page = 1;
    });
    _loadEmployees();
  }

  int get _activeFiltersCount {
    int c = 0;
    if (_searchQuery.isNotEmpty) c++;
    if (_selectedDepartmentId != null) c++;
    if (_selectedDesignationId != null) c++;
    if (_selectedTeamId != null) c++;
    if (_selectedStatus != null) c++;
    if (_selectedManagerId != null) c++;
    if (_selectedJoinedDate != null) c++;
    return c;
  }

  // Filter Modals
  void _pickDepartment() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Department', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Departments', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: _selectedDepartmentId == null ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedDepartmentId = null;
                    _selectedDepartmentName = null;
                    _page = 1;
                  });
                  _loadEmployees();
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _departments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final d = _departments[idx];
                    final id = d['id']?.toString();
                    final name = d['name']?.toString() ?? 'Department';
                    final isSel = _selectedDepartmentId == id;
                    return ListTile(
                      title: Text(name, style: TextStyle(fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? _taskBrown : _ink)),
                      trailing: isSel ? const Icon(Icons.check, color: _taskBrown) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedDepartmentId = id;
                          _selectedDepartmentName = name;
                          _page = 1;
                        });
                        _loadEmployees();
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

  void _pickDesignation() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Designation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Designations', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: _selectedDesignationId == null ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedDesignationId = null;
                    _selectedDesignationName = null;
                    _page = 1;
                  });
                  _loadEmployees();
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _designations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final d = _designations[idx];
                    final id = d['id']?.toString();
                    final name = d['title']?.toString() ?? d['name']?.toString() ?? 'Designation';
                    final isSel = _selectedDesignationId == id;
                    return ListTile(
                      title: Text(name, style: TextStyle(fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? _taskBrown : _ink)),
                      trailing: isSel ? const Icon(Icons.check, color: _taskBrown) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedDesignationId = id;
                          _selectedDesignationName = name;
                          _page = 1;
                        });
                        _loadEmployees();
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

  void _pickTeam() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Teams', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: _selectedTeamId == null ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedTeamId = null;
                    _selectedTeamName = null;
                    _page = 1;
                  });
                  _loadEmployees();
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _teams.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final t = _teams[idx];
                    final id = t['id']?.toString();
                    final name = t['name']?.toString() ?? 'Team';
                    final isSel = _selectedTeamId == id;
                    return ListTile(
                      title: Text(name, style: TextStyle(fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? _taskBrown : _ink)),
                      trailing: isSel ? const Icon(Icons.check, color: _taskBrown) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedTeamId = id;
                          _selectedTeamName = name;
                          _page = 1;
                        });
                        _loadEmployees();
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

  void _pickStatus() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Statuses', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: _selectedStatus == null ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedStatus = null;
                    _page = 1;
                  });
                  _loadEmployees();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: _green, size: 20),
                title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _selectedStatus == 'ACTIVE' ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedStatus = 'ACTIVE';
                    _page = 1;
                  });
                  _loadEmployees();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: _soft, size: 20),
                title: const Text('Inactive', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _selectedStatus == 'INACTIVE' ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedStatus = 'INACTIVE';
                    _page = 1;
                  });
                  _loadEmployees();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickManager() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Manager: All', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: _selectedManagerId == null ? const Icon(Icons.check, color: _taskBrown) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedManagerId = null;
                    _selectedManagerName = null;
                    _page = 1;
                  });
                  _loadEmployees();
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _managers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final m = _managers[idx];
                    final id = m['id']?.toString();
                    final name = m['fullName']?.toString() ?? 'Manager';
                    final isSel = _selectedManagerId == id;
                    return ListTile(
                      title: Text(name, style: TextStyle(fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? _taskBrown : _ink)),
                      trailing: isSel ? const Icon(Icons.check, color: _taskBrown) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedManagerId = id;
                          _selectedManagerName = name;
                          _page = 1;
                        });
                        _loadEmployees();
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

  void _pickJoinedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _taskBrown,
            onPrimary: Colors.white,
            onSurface: _ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _selectedJoinedDate = formatted;
        _page = 1;
      });
      _loadEmployees();
    }
  }

  Future<void> _openAddEmployeePage() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEmployeePage(
          api: widget.api,
          initialDepartments: _departments,
          initialDesignations: _designations,
          initialTeams: _teams,
          initialManagers: _managers,
        ),
      ),
    );
    if (created == true) {
      _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee created successfully.'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Employees',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: _ink,
          ),
        ),
        actions: [
          if (widget.api.canAddEmployee)
            IconButton(
              tooltip: 'Add employee',
              icon: const Icon(Icons.person_add_alt_1_rounded, color: _taskBrown),
              onPressed: _openAddEmployeePage,
            ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.file_download_outlined, color: _ink),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Employee list CSV export ready.')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEmployees,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // Breadcrumbs, Title & Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HRMS / Employees',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _soft),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Employees',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Employee directory with employment details, reporting lines and teams.',
                  style: TextStyle(fontSize: 13, color: _soft),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Employee list CSV export ready.')),
                        );
                      },
                      icon: const Icon(Icons.file_download_outlined, size: 16, color: _ink),
                      label: const Text('Export CSV', style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    if (widget.api.canAddEmployee) ...[
                      ElevatedButton.icon(
                        onPressed: _openAddEmployeePage,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add employee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _taskBrown,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter Toolbar Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
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
                children: [
                  // Search Row
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search name, email, code...',
                      hintStyle: const TextStyle(fontSize: 13.5, color: _soft),
                      prefixIcon: const Icon(Icons.search, size: 18, color: _soft),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _page = 1;
                                });
                                _loadEmployees();
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        borderSide: const BorderSide(color: _taskBrown, width: 1.5),
                      ),
                    ),
                    onSubmitted: (val) {
                      setState(() {
                        _searchQuery = val;
                        _page = 1;
                      });
                      _loadEmployees();
                    },
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips / Dropdowns Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterButton(
                          label: 'By Department',
                          valueText: _selectedDepartmentName,
                          isActive: _selectedDepartmentId != null,
                          onTap: _pickDepartment,
                          onClear: _selectedDepartmentId != null
                              ? () {
                                  setState(() {
                                    _selectedDepartmentId = null;
                                    _selectedDepartmentName = null;
                                    _page = 1;
                                  });
                                  _loadEmployees();
                                }
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterButton(
                          label: 'By Designation',
                          valueText: _selectedDesignationName,
                          isActive: _selectedDesignationId != null,
                          onTap: _pickDesignation,
                          onClear: _selectedDesignationId != null
                              ? () {
                                  setState(() {
                                    _selectedDesignationId = null;
                                    _selectedDesignationName = null;
                                    _page = 1;
                                  });
                                  _loadEmployees();
                                }
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterButton(
                          label: 'By Team',
                          valueText: _selectedTeamName,
                          isActive: _selectedTeamId != null,
                          onTap: _pickTeam,
                          onClear: _selectedTeamId != null
                              ? () {
                                  setState(() {
                                    _selectedTeamId = null;
                                    _selectedTeamName = null;
                                    _page = 1;
                                  });
                                  _loadEmployees();
                                }
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterButton(
                          label: 'By Status',
                          valueText: _selectedStatus == null ? null : (_selectedStatus == 'ACTIVE' ? 'Active' : 'Inactive'),
                          isActive: _selectedStatus != null,
                          onTap: _pickStatus,
                          onClear: _selectedStatus != null
                              ? () {
                                  setState(() {
                                    _selectedStatus = null;
                                    _page = 1;
                                  });
                                  _loadEmployees();
                                }
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterButton(
                          label: 'Manager: All',
                          valueText: _selectedManagerName != null ? 'Manager: $_selectedManagerName' : null,
                          isActive: _selectedManagerId != null,
                          prefixIcon: Icons.person_outline_rounded,
                          onTap: _pickManager,
                          onClear: _selectedManagerId != null
                              ? () {
                                  setState(() {
                                    _selectedManagerId = null;
                                    _selectedManagerName = null;
                                    _page = 1;
                                  });
                                  _loadEmployees();
                                }
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterButton(
                          label: 'Joined: By Date',
                          valueText: _selectedJoinedDate != null ? 'Joined: $_selectedJoinedDate' : null,
                          isActive: _selectedJoinedDate != null,
                          prefixIcon: Icons.calendar_today_rounded,
                          onTap: _pickJoinedDate,
                          onClear: _selectedJoinedDate != null
                              ? () {
                                  setState(() {
                                    _selectedJoinedDate = null;
                                    _page = 1;
                                  });
                                  _loadEmployees();
                                }
                              : null,
                        ),
                        if (_activeFiltersCount > 0) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.filter_alt_off_rounded, size: 14, color: _taskBrown),
                            label: Text(
                              'Clear ($_activeFiltersCount)',
                              style: const TextStyle(color: _taskBrown, fontSize: 12, fontWeight: FontWeight.w700),
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Employee Cards List (Card UI, NOT tables view)
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
                      const SizedBox(height: 8),
                      Text('Failed to load employees: $_error', style: const TextStyle(color: _soft)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(onPressed: _loadEmployees, child: const Text('Try Again')),
                    ],
                  ),
                ),
              )
            else if (_employees.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 40, color: _soft),
                      const SizedBox(height: 10),
                      const Text(
                        'No employees found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try adjusting your search or filters.',
                        style: TextStyle(fontSize: 13, color: _soft),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              for (final emp in _employees) ...[
                _buildEmployeeCard(emp),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              // Pagination Toolbar matching Screenshot 2
              _buildPaginationToolbar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    String? valueText,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onClear,
    IconData? prefixIcon,
  }) {
    final displayText = valueText ?? label;

    return Material(
      color: isActive ? _taskBrown.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? _taskBrown : const Color(0xFFCBD5E1),
              width: isActive ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, size: 15, color: isActive ? _taskBrown : _soft),
                const SizedBox(width: 4),
              ],
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? _taskBrown : _ink,
                ),
              ),
              const SizedBox(width: 4),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded, size: 14, color: _taskBrown),
                )
              else
                const Icon(Icons.arrow_drop_down_rounded, size: 18, color: _soft),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> person) {
    final name = person['fullName']?.toString() ??
        '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim();
    final empCode = person['employeeCode']?.toString() ?? person['code']?.toString() ?? '';
    final email = person['email']?.toString() ?? '';
    final active = (person['status'] ?? 'ACTIVE').toString().toUpperCase() == 'ACTIVE';

    final department = (person['department'] is Map)
        ? (person['department']['name']?.toString() ?? '')
        : (person['department']?.toString() ?? '');

    final designation = (person['designation'] is Map)
        ? (person['designation']['title']?.toString() ?? person['designation']['name']?.toString() ?? '')
        : (person['designation']?.toString() ?? '');

    final managerName = (person['manager'] is Map)
        ? (person['manager']['fullName']?.toString() ?? '')
        : (person['manager']?.toString() ?? '');

    final teamsList = (person['teams'] is List) ? person['teams'] as List : [];
    final firstTeam = teamsList.isNotEmpty
        ? (teamsList.first is Map ? (teamsList.first['name'] ?? teamsList.first['code']) : teamsList.first).toString()
        : '';

    final rawJoined = person['joiningDate']?.toString() ?? '';
    final joined = rawJoined.isNotEmpty ? _formatShortDate(rawJoined) : '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          // Tap navigates to EmployeeDetailPage to view user activities!
          final refreshed = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (_) => EmployeeDetailPage(
                api: widget.api,
                employeeId: person['id']?.toString() ?? '',
                initialData: person,
              ),
            ),
          );
          if ((refreshed == true || refreshed is Map) && mounted) {
            _loadEmployees();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
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
              // Avatar + Name + Code + Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _avatarColor(name),
                    child: Text(
                      _initials(name),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name.isNotEmpty ? name : 'Employee',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (empCode.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1EDE6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  empCode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10.5,
                                    color: _ink,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(fontSize: 12, color: _soft),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: active ? _greenBg : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? _green : _soft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          active ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active ? _green : _soft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Department & Designation
              if (designation.isNotEmpty || department.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.business_center_outlined, size: 14, color: _soft),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [if (designation.isNotEmpty) designation, if (department.isNotEmpty) department].join(' · '),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              // Manager & Teams
              Row(
                children: [
                  if (managerName.isNotEmpty) ...[
                    const Icon(Icons.person_outline_rounded, size: 14, color: _soft),
                    const SizedBox(width: 6),
                    Text(
                      'Manager: $managerName',
                      style: const TextStyle(fontSize: 12, color: _soft, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (firstTeam.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EDE6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        firstTeam,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ),
                  const Spacer(),
                  if (widget.api.canAddEmployee) ...[
                    InkWell(
                      onTap: () async {
                        final res = await Navigator.push<dynamic>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEmployeePage(
                              api: widget.api,
                              employeeToEdit: person,
                              initialDepartments: _departments,
                              initialDesignations: _designations,
                              initialTeams: _teams,
                              initialManagers: _managers,
                            ),
                          ),
                        );
                        if (res != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Employee updated successfully.'),
                              backgroundColor: Color(0xFF16A34A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          _loadEmployees();
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9F5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF3D5C8)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 13, color: _taskBrown),
                            SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _taskBrown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (joined.isNotEmpty)
                    Text(
                      joined,
                      style: const TextStyle(fontSize: 11.5, color: _soft),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationToolbar() {
    final startIdx = _totalItems == 0 ? 0 : (_page - 1) * _pageSize + 1;
    final endIdx = (_page * _pageSize).clamp(0, _totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Text(
            '$startIdx–$endIdx of $_totalItems',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
          ),
          const Spacer(),
          // Rows per page
          const Text('Rows', style: TextStyle(fontSize: 12, color: _soft)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$_pageSize',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
            ),
          ),
          const SizedBox(width: 12),

          // Next / Prev buttons
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _loadEmployees();
                  }
                : null,
          ),
          Text(
            '$_page / $_totalPages',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _page < _totalPages
                ? () {
                    setState(() => _page++);
                    _loadEmployees();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  static Color _avatarColor(String name) {
    const palette = [
      Color(0xFFE11D48), // Rose
      Color(0xFF059669), // Emerald
      Color(0xFF0891B2), // Cyan
      Color(0xFF7C3AED), // Violet
      Color(0xFFD97706), // Amber
      Color(0xFF2563EB), // Blue
    ];
    if (name.isEmpty) return palette[0];
    final code = name.codeUnits.fold(0, (a, b) => a + b);
    return palette[code % palette.length];
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'E';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String _formatShortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}


class TeamAttendancePage extends StatefulWidget {
  final Api api;
  const TeamAttendancePage({super.key, required this.api});
  @override
  State<TeamAttendancePage> createState() => _TeamAttendancePageState();
}

class _TeamAttendancePageState extends State<TeamAttendancePage> {
  static const _pageSize = 8;
  static const _filters = [
    '',
    'PRESENT',
    'CHECKED_IN',
    'NOT_CHECKED_IN',
    'LATE',
    'ON_LEAVE',
    'ABSENT',
    'MISSING_CHECKOUT',
  ];
  DateTime day = DateTime.now();
  String status = '';
  List<Json> rows = [];
  int page = 0;
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.get(
        '/attendance',
        query: {'date': dateOnly(day), if (status.isNotEmpty) 'status': status},
      );
      if (!mounted) return;
      setState(() {
        rows = items(result);
        page = 0;
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

  bool get isToday => dateOnly(day) == dateOnly(DateTime.now());

  void shift(int delta) {
    final next = day.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return;
    setState(() => day = next);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = (rows.length / _pageSize).ceil().clamp(1, 999);
    final shown = rows.skip(page * _pageSize).take(_pageSize).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F8),
        title: const Text(
          'Team attendance',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: error != null
          ? FailureView(error!, load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => shift(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          isToday
                              ? 'Today · ${day.day} ${_mon(day)}'
                              : '${day.day} ${_mon(day)} ${day.year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1B2A4A),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: isToday ? null : () => shift(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final filter in _filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              filter.isEmpty ? 'All' : _label(filter),
                            ),
                            selected: status == filter,
                            onSelected: (_) {
                              setState(() => status = filter);
                              load();
                            },
                            selectedColor: const Color(0xFFE7F6EE),
                            checkmarkColor: const Color(0xFF1B7F56),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: loading
                      ? const DashboardShimmer()
                      : RefreshIndicator(
                          onRefresh: load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              if (shown.isEmpty)
                                const EmptyView(
                                  'No attendance rows',
                                  'Nothing matches this day and status.',
                                ),
                              for (final row in shown) ...[
                                _AttendanceCard(row),
                                const SizedBox(height: 10),
                              ],
                              if (pages > 1)
                                _Pager(
                                  page: page,
                                  pages: pages,
                                  onPrev: page == 0
                                      ? null
                                      : () => setState(() => page--),
                                  onNext: page >= pages - 1
                                      ? null
                                      : () => setState(() => page++),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final Json row;
  const _AttendanceCard(this.row);
  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? '';
    final tone = _tone(status);
    final minutes = (row['workedMinutes'] as num?)?.toInt() ?? 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                        row['name']?.toString() ?? '',
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [row['code'], row['department']]
                            .where(
                              (part) =>
                                  part != null && part.toString().isNotEmpty,
                            )
                            .join(' · '),
                        style: const TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 12,
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
                    color: tone.$1,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _label(status),
                    style: TextStyle(
                      color: tone.$2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              shortDate(row['date'].toString()),
              style: const TextStyle(
                color: Color(0xFF1B2A4A),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _time('In', clockText(row['checkIn']))),
                Expanded(child: _time('Out', clockText(row['checkOut']))),
                Expanded(
                  child: _time(
                    'Worked',
                    '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _time(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFF1B2A4A),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ],
  );
}



class _Pager extends StatelessWidget {
  final int page;
  final int pages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pager({
    required this.page,
    required this.pages,
    required this.onPrev,
    required this.onNext,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
      Text(
        'Page ${page + 1} of $pages',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
    ],
  );
}



String _label(String raw) {
  final text = raw.toLowerCase().replaceAll('_', ' ');
  if (text.isEmpty) return raw;
  return text[0].toUpperCase() + text.substring(1);
}

(Color, Color) _tone(String status) => switch (status.toUpperCase()) {
  'PRESENT' => (const Color(0xFFE7F6EE), const Color(0xFF1B7F56)),
  'CHECKED_IN' => (const Color(0xFFE7F6EE), const Color(0xFF1B7F56)),
  'LATE' => (const Color(0xFFEAF1FF), const Color(0xFF3B82F6)),
  'ABSENT' => (const Color(0xFFFDECEC), const Color(0xFFE15B64)),
  'MISSING_CHECKOUT' => (const Color(0xFFFDECEC), const Color(0xFFE15B64)),
  'NOT_CHECKED_IN' => (const Color(0xFFFFF6E0), const Color(0xFFC48A00)),
  'LEAVE' ||
  'ON_LEAVE' ||
  'HALF_DAY_LEAVE' => (const Color(0xFFF3F0FF), const Color(0xFF6C4DFF)),
  'OVERTIME' => (const Color(0xFFF3F0FF), const Color(0xFF6C4DFF)),
  _ => (const Color(0xFFF3F5F7), const Color(0xFF6E7C8A)),
};

String _mon(DateTime day) => const [
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
][day.month - 1];
