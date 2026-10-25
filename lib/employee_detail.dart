import 'package:flutter/material.dart';
import 'api.dart';
import 'add_employee.dart';

/// Employee details and activity screen matching Screenshot 3:
/// - Overview Tab: Details, Account, Task Summary (4 stat cards), Leave Balances cards
/// - Attendance Tab: Employee attendance summary & days card list
/// - Leave Tab: Employee leave requests with status pills & pagination
/// - Tasks Tab: Employee assigned tasks with project badges, priority & pagination
class EmployeeDetailPage extends StatefulWidget {
  final Api api;
  final String employeeId;
  final Map<String, dynamic>? initialData;

  const EmployeeDetailPage({
    super.key,
    required this.api,
    required this.employeeId,
    this.initialData,
  });

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _cardBorder = Color(0xFFE8E2D9);
  static const Color _pageBg = Color(0xFFFAF8F5);
  static const Color _green = Color(0xFF16A34A);
  static const Color _greenBg = Color(0xFFE7F6EE);
  static const Color _red = Color(0xFFDC2626);
  static const Color _redBg = Color(0xFFFEE2E2);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _amber = Color(0xFFD97706);
  static const Color _amberBg = Color(0xFFFEF3C7);

  // Tabs: 0: Overview, 1: Attendance, 2: Leave, 3: Tasks
  int _tabIndex = 0;

  // Overview Data
  Map<String, dynamic>? _profile;
  bool _profileLoading = true;
  Object? _profileError;

  // Attendance Tab Data
  Map<String, dynamic>? _attendanceData;
  bool _attendanceLoading = false;
  Object? _attendanceError;

  // Leave Tab Data
  List<Map<String, dynamic>> _leaveRequests = [];
  int _leavePage = 1;
  int _leavePageSize = 10;
  int _leaveTotalItems = 0;
  int _leaveTotalPages = 1;
  bool _leaveLoading = false;
  Object? _leaveError;

  // Tasks Tab Data
  List<Map<String, dynamic>> _tasks = [];
  int _taskPage = 1;
  int _taskPageSize = 10;
  int _taskTotalItems = 0;
  int _taskTotalPages = 1;
  bool _taskLoading = false;
  Object? _taskError;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _profile = Map<String, dynamic>.from(widget.initialData!);
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _profileLoading = _profile == null;
      _profileError = null;
    });

    try {
      final res = await widget.api.v1('GET', '/employees/${widget.employeeId}');
      if (!mounted) return;
      setState(() {
        if (res is Map) {
          _profile = Map<String, dynamic>.from(res);
        }
        _profileLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _profileError = e;
          _profileLoading = false;
        });
      }
    }
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _attendanceLoading = true;
      _attendanceError = null;
    });

    try {
      final res = await widget.api.v1('GET', '/attendance/employees/${widget.employeeId}');
      if (!mounted) return;
      setState(() {
        if (res is Map) {
          _attendanceData = Map<String, dynamic>.from(res);
        }
        _attendanceLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _attendanceError = e;
          _attendanceLoading = false;
        });
      }
    }
  }

  Future<void> _loadLeave({int page = 1}) async {
    setState(() {
      _leaveLoading = true;
      _leaveError = null;
    });

    try {
      final res = await widget.api.v1(
        'GET',
        '/leave-requests',
        query: {
          'employeeId': widget.employeeId,
          'page': page,
          'pageSize': _leavePageSize,
          'sortBy': 'startDate',
        },
      );
      if (!mounted) return;

      final items = (res is Map && res['items'] is List)
          ? res['items'] as List
          : (res is List ? res : []);

      setState(() {
        _leaveRequests = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final map = res is Map ? res : {};
        _leavePage = (map['page'] as num?)?.toInt() ?? page;
        _leavePageSize = (map['pageSize'] as num?)?.toInt() ?? _leavePageSize;
        _leaveTotalItems = (map['totalItems'] as num?)?.toInt() ?? _leaveRequests.length;
        _leaveTotalPages = (map['totalPages'] as num?)?.toInt() ??
            ((_leaveTotalItems / _leavePageSize).ceil().clamp(1, 999));
        _leaveLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _leaveError = e;
          _leaveLoading = false;
        });
      }
    }
  }

  Future<void> _loadTasks({int page = 1}) async {
    setState(() {
      _taskLoading = true;
      _taskError = null;
    });

    try {
      final res = await widget.api.v1(
        'GET',
        '/tasks',
        query: {
          'assigneeId': widget.employeeId,
          'page': page,
          'pageSize': _taskPageSize,
        },
      );
      if (!mounted) return;

      final items = (res is Map && res['items'] is List)
          ? res['items'] as List
          : (res is List ? res : []);

      setState(() {
        _tasks = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final map = res is Map ? res : {};
        _taskPage = (map['page'] as num?)?.toInt() ?? page;
        _taskPageSize = (map['pageSize'] as num?)?.toInt() ?? _taskPageSize;
        _taskTotalItems = (map['totalItems'] as num?)?.toInt() ?? _tasks.length;
        _taskTotalPages = (map['totalPages'] as num?)?.toInt() ??
            ((_taskTotalItems / _taskPageSize).ceil().clamp(1, 999));
        _taskLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _taskError = e;
          _taskLoading = false;
        });
      }
    }
  }

  bool _hasBeenEdited = false;

  Future<void> _openEditEmployee() async {
    final emp = _profile ?? widget.initialData ?? {'id': widget.employeeId};
    final res = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEmployeePage(
          api: widget.api,
          employeeToEdit: emp,
        ),
      ),
    );

    if (res != null && mounted) {
      _hasBeenEdited = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee updated successfully.'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadProfile();
    }
  }

  void _switchTab(int index) {
    if (_tabIndex == index) return;
    setState(() => _tabIndex = index);
    if (index == 1 && _attendanceData == null) {
      _loadAttendance();
    } else if (index == 2 && _leaveRequests.isEmpty && !_leaveLoading) {
      _loadLeave();
    } else if (index == 3 && _tasks.isEmpty && !_taskLoading) {
      _loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? {};
    final fullName = profile['fullName']?.toString() ??
        '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
    final name = fullName.isNotEmpty ? fullName : 'Employee Details';
    final code = profile['employeeCode']?.toString() ?? '';
    final designation = (profile['designation'] is Map)
        ? (profile['designation']['title'] ?? profile['designation']['name'] ?? '')
        : (profile['designation']?.toString() ?? '');
    final department = (profile['department'] is Map)
        ? (profile['department']['name'] ?? '')
        : (profile['department']?.toString() ?? '');

    final subtitleParts = [
      if (code.isNotEmpty) code,
      if (designation.isNotEmpty) designation,
      if (department.isNotEmpty) department,
    ];
    final subtitle = subtitleParts.join(' · ');

    final active = (profile['status'] ?? 'ACTIVE').toString().toUpperCase() == 'ACTIVE';

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => Navigator.pop(context, _hasBeenEdited),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: _ink,
          ),
        ),
        actions: [
          if (widget.api.canAddEmployee)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: _ink),
              tooltip: 'Edit employee',
              onPressed: _openEditEmployee,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _profileLoading && _profile == null
          ? const Center(child: CircularProgressIndicator())
          : _profileError != null && _profile == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'Failed to load employee: $_profileError',
                          style: const TextStyle(color: _soft),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _loadProfile,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: () async {
                await _loadProfile();
                if (_tabIndex == 1) await _loadAttendance();
                if (_tabIndex == 2) await _loadLeave(page: _leavePage);
                if (_tabIndex == 3) await _loadTasks(page: _taskPage);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // Breadcrumb
                  Text(
                    'Employees / $name',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _soft,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header Card with Avatar, Name, Status, Subtitle
                  _buildHeaderCard(name, active, subtitle),
                  const SizedBox(height: 16),

                  // Segmented Tabs: [ Overview | Attendance | Leave | Tasks ]
                  _buildSegmentedTabs(),
                  const SizedBox(height: 16),

                  // Tab View Content
                  if (_tabIndex == 0) _buildOverviewTab(profile),
                  if (_tabIndex == 1) _buildAttendanceTab(),
                  if (_tabIndex == 2) _buildLeaveTab(),
                  if (_tabIndex == 3) _buildTasksTab(),
                ],
              ),
            ),
    );
  }

  // ── Header Card ────────────────────────────────────────────────────────────
  Widget _buildHeaderCard(String name, bool active, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFBE5E38),
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: active ? _greenBg : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
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
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _soft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Segmented Tabs ─────────────────────────────────────────────────────────
  Widget _buildSegmentedTabs() {
    final tabs = ['Overview', 'Attendance', 'Leave', 'Tasks'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDE6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchTab(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x101B2A4A),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? _ink : _soft,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Tab 1: Overview ────────────────────────────────────────────────────────
  Widget _buildOverviewTab(Map<String, dynamic> profile) {
    final email = profile['email']?.toString() ?? '—';
    final phone = profile['phone']?.toString() ?? '—';
    final rawJoining = profile['joiningDate']?.toString() ?? '';
    final joining = _formatDate(rawJoining);
    final employmentType = _prettyEmployment(profile['employmentType']?.toString() ?? 'Full time');
    final workLocation = profile['workLocation']?.toString() ?? '—';

    final department = (profile['department'] is Map)
        ? (profile['department']['name']?.toString() ?? '—')
        : (profile['department']?.toString() ?? '—');

    final designation = (profile['designation'] is Map)
        ? (profile['designation']['title']?.toString() ?? '—')
        : (profile['designation']?.toString() ?? '—');

    final managerMap = (profile['manager'] is Map) ? profile['manager'] as Map : null;
    final managerName = managerMap?['fullName']?.toString() ?? '—';
    final managerCode = managerMap?['employeeCode']?.toString() ?? '';
    final managerDesig = managerMap?['designation']?.toString() ?? 'Manager';
    final directReportCount = (profile['directReportCount'] as num?)?.toInt() ?? 0;

    final teamsList = (profile['teams'] is List) ? profile['teams'] as List : [];

    // Account info
    final accountMap = (profile['account'] is Map) ? profile['account'] as Map : null;
    final accountStatus = accountMap?['status']?.toString() ?? 'ACTIVE';
    final rawLastLogin = accountMap?['lastLoginAt']?.toString() ?? '';
    final lastLogin = _formatDateTime(rawLastLogin);

    // Task summary
    final taskSum = (profile['taskSummary'] is Map) ? profile['taskSummary'] as Map : null;
    final todoCount = (taskSum?['todo'] as num?)?.toInt() ?? 0;
    final inProgressCount = (taskSum?['inProgress'] as num?)?.toInt() ?? 0;
    final completedCount = (taskSum?['completed'] as num?)?.toInt() ?? 0;
    final overdueCount = (taskSum?['overdue'] as num?)?.toInt() ?? 0;

    // Leave balances
    final balances = (profile['leaveBalances'] is List)
        ? (profile['leaveBalances'] as List).whereType<Map>().toList()
        : <Map>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                  ),
                  if (widget.api.canAddEmployee)
                    InkWell(
                      onTap: _openEditEmployee,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 14, color: Color(0xFFBE5E38)),
                            SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFBE5E38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildDetailRow('Email', email, isAccent: email != '—'),
              const Divider(height: 20),
              _buildDetailRow('Phone', phone),
              const Divider(height: 20),
              _buildDetailRow('Joined', joining),
              const Divider(height: 20),
              _buildDetailRow('Employment', employmentType),
              const Divider(height: 20),
              _buildDetailRow('Work location', workLocation),
              const Divider(height: 20),
              _buildDetailRow('Department', department),
              const Divider(height: 20),
              _buildDetailRow('Designation', designation),
              const Divider(height: 20),
              _buildManagerRow(managerName, managerCode, managerDesig),
              const Divider(height: 20),
              _buildDetailRow('Direct reports', '$directReportCount'),
              const Divider(height: 20),
              _buildTeamsRow(teamsList),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Account Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status', style: TextStyle(color: _soft, fontSize: 13.5)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accountStatus.toUpperCase() == 'ACTIVE' ? _greenBg : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accountStatus.toUpperCase() == 'ACTIVE' ? _green : _soft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          accountStatus.toUpperCase() == 'ACTIVE' ? 'Active' : accountStatus,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: accountStatus.toUpperCase() == 'ACTIVE' ? _green : _soft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Last sign-in', style: TextStyle(color: _soft, fontSize: 13.5)),
                  Text(
                    lastLogin,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: _ink),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Task Summary: 4 stat cards matching screenshot
        Row(
          children: [
            Expanded(child: _buildTaskStatCard('To do', '$todoCount', Icons.checklist_rounded, const Color(0xFFF1EDE6), _ink)),
            const SizedBox(width: 10),
            Expanded(child: _buildTaskStatCard('In progress', '$inProgressCount', Icons.access_time_rounded, const Color(0xFFEFF6FF), _blue)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTaskStatCard('Completed', '$completedCount', Icons.check_circle_outline_rounded, const Color(0xFFE7F6EE), _green)),
            const SizedBox(width: 10),
            Expanded(child: _buildTaskStatCard('Overdue', '$overdueCount', Icons.access_time_filled_rounded, _redBg, _red)),
          ],
        ),
        const SizedBox(height: 16),

        // Leave Balances Cards matching Screenshot 3
        if (balances.isNotEmpty) ...[
          const Text(
            'Leave Balances',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 10),
          for (final b in balances) ...[
            _buildLeaveBalanceCard(b),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAccent = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _soft, fontSize: 13.5)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isAccent ? const Color(0xFFBE5E38) : _ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManagerRow(String name, String code, String designation) {
    if (name == '—') return _buildDetailRow('Manager', '—');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Manager', style: TextStyle(color: _soft, fontSize: 13.5)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF16A34A),
              child: Text(
                _initials(name),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ink),
                ),
                Text(
                  [if (code.isNotEmpty) code, designation].join(' · '),
                  style: const TextStyle(fontSize: 11, color: _soft),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamsRow(List teams) {
    if (teams.isEmpty) return _buildDetailRow('Teams', '—');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Teams', style: TextStyle(color: _soft, fontSize: 13.5)),
        const SizedBox(width: 16),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final t in teams)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EDE6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (t is Map ? (t['name'] ?? t['code']) : t).toString(),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _ink),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskStatCard(String label, String count, IconData icon, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: _soft, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _ink,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceCard(Map b) {
    final lt = (b['leaveType'] is Map) ? b['leaveType'] as Map : {};
    final name = lt['name']?.toString() ?? 'Leave';
    final colorHex = lt['color']?.toString() ?? '#3b82f6';
    final dotColor = _parseColor(colorHex);
    final isPaid = lt['isPaid'] != false;

    final available = (b['available'] as num?)?.toInt() ?? 0;
    final balance = (b['balance'] as num?)?.toInt() ?? 0;
    final pending = (b['pending'] as num?)?.toInt() ?? 0;
    final used = (b['used'] as num?)?.toInt() ?? 0;
    final carriedForward = (b['carriedForward'] as num?)?.toInt() ?? 0;
    final allowNeg = b['allowNegativeBalance'] == true;
    final negLimit = (b['negativeBalanceLimit'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
              if (!isPaid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EDE6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Unpaid',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _soft),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$available',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _ink),
              ),
              const SizedBox(width: 6),
              const Text('available', style: TextStyle(fontSize: 13, color: _soft, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _balanceRow('Balance', '$balance'),
          const SizedBox(height: 4),
          _balanceRow('Pending', '$pending'),
          const SizedBox(height: 4),
          _balanceRow('Used', '$used'),
          const SizedBox(height: 4),
          _balanceRow('Carried forward', '$carriedForward'),
          if (allowNeg && negLimit > 0) ...[
            const SizedBox(height: 8),
            Text(
              'May go negative up to $negLimit days',
              style: const TextStyle(fontSize: 11.5, color: _soft, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _soft, fontSize: 12.5)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: _ink)),
      ],
    );
  }

  // ── Tab 2: Attendance ──────────────────────────────────────────────────────
  Widget _buildAttendanceTab() {
    if (_attendanceLoading && _attendanceData == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }
    if (_attendanceError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              Text('Failed to load attendance: $_attendanceError', style: const TextStyle(color: _soft)),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: _loadAttendance, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    final totals = (_attendanceData?['totals'] is Map) ? _attendanceData!['totals'] as Map : {};
    final present = (totals['present'] as num?)?.toInt() ?? 0;
    final absent = (totals['absent'] as num?)?.toInt() ?? 0;
    final late = (totals['late'] as num?)?.toInt() ?? 0;
    final netMinutes = (totals['totalNetMinutes'] as num?)?.toInt() ?? 0;
    final netHours = (netMinutes / 60).toStringAsFixed(1);

    final days = (_attendanceData?['days'] is List) ? _attendanceData!['days'] as List : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attendance Summary Cards
        Row(
          children: [
            Expanded(child: _buildAttendanceStat('Present', '$present d', _greenBg, _green)),
            const SizedBox(width: 8),
            Expanded(child: _buildAttendanceStat('Absent', '$absent d', _redBg, _red)),
            const SizedBox(width: 8),
            Expanded(child: _buildAttendanceStat('Late', '$late', _amberBg, _amber)),
            const SizedBox(width: 8),
            Expanded(child: _buildAttendanceStat('Total Net', '${netHours}h', const Color(0xFFEFF6FF), _blue)),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Daily Attendance Logs (${days.length} days)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
        ),
        const SizedBox(height: 10),

        if (days.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No attendance records found', style: TextStyle(color: _soft))))
        else
          for (final d in days) ...[
            _buildAttendanceDayCard(d is Map ? d : {}),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildAttendanceStat(String label, String value, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _soft, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildAttendanceDayCard(Map d) {
    final dateStr = d['date']?.toString() ?? '';
    final status = (d['status'] ?? 'ABSENT').toString().toUpperCase();
    final firstIn = _formatTime(d['firstInAt']?.toString() ?? '');
    final lastOut = _formatTime(d['lastOutAt']?.toString() ?? '');
    final netMins = (d['netMinutes'] as num?)?.toInt() ?? 0;
    final isLate = d['isLate'] == true;
    final lateMins = (d['lateMinutes'] as num?)?.toInt() ?? 0;
    final holidayName = d['holiday']?.toString();

    Color statusColor = _soft;
    Color statusBg = const Color(0xFFF1F5F9);
    if (status == 'PRESENT') {
      statusColor = _green;
      statusBg = _greenBg;
    } else if (status == 'ABSENT') {
      statusColor = _red;
      statusBg = _redBg;
    } else if (status == 'HOLIDAY') {
      statusColor = const Color(0xFF8B5CF6);
      statusBg = const Color(0xFFEDE9FE);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          // Date
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EDE6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  _shortDayNumber(dateStr),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                ),
                Text(
                  _shortMonthName(dateStr),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _soft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // In/Out and Duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        holidayName != null ? 'HOLIDAY: $holidayName' : status,
                        style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isLate) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _redBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          'Late (${lateMins}m)',
                          style: const TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (status == 'PRESENT') ...[
                  Text(
                    '$firstIn – $lastOut (${(netMins / 60).toStringAsFixed(1)}h worked)',
                    style: const TextStyle(fontSize: 12.5, color: _ink, fontWeight: FontWeight.w600),
                  ),
                ] else ...[
                  Text(
                    status == 'WEEKEND' ? 'Weekend' : (holidayName ?? status),
                    style: const TextStyle(fontSize: 12, color: _soft),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Leave Requests ──────────────────────────────────────────────────
  Widget _buildLeaveTab() {
    if (_leaveLoading && _leaveRequests.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }
    if (_leaveError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              Text('Failed to load leave requests: $_leaveError', style: const TextStyle(color: _soft)),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: () => _loadLeave(page: _leavePage), child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    if (_leaveRequests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('No leave requests found for this employee.', style: TextStyle(color: _soft)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Leave Requests ($_leaveTotalItems)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
            ),
            Text(
              'Page $_leavePage of $_leaveTotalPages',
              style: const TextStyle(fontSize: 12, color: _soft, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),

        for (final req in _leaveRequests) ...[
          _buildLeaveCard(req),
          const SizedBox(height: 10),
        ],

        // Pagination row
        if (_leaveTotalPages > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _leavePage > 1 ? () => _loadLeave(page: _leavePage - 1) : null,
              ),
              Text('$_leavePage / $_leaveTotalPages', style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _leavePage < _leaveTotalPages ? () => _loadLeave(page: _leavePage + 1) : null,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLeaveCard(Map req) {
    final lt = (req['leaveType'] is Map) ? req['leaveType'] as Map : {};
    final typeName = lt['name']?.toString() ?? 'Leave';
    final dotColor = _parseColor(lt['color']?.toString() ?? '#3b82f6');

    final startDate = _formatDate(req['startDate']?.toString() ?? '');
    final endDate = _formatDate(req['endDate']?.toString() ?? '');
    final days = req['days']?.toString() ?? '1';
    final status = (req['status'] ?? 'PENDING').toString().toUpperCase();
    final reason = req['reason']?.toString() ?? '';

    Color statusColor = _amber;
    Color statusBg = _amberBg;
    if (status == 'APPROVED') {
      statusColor = _green;
      statusBg = _greenBg;
    } else if (status == 'REJECTED') {
      statusColor = _red;
      statusBg = _redBg;
    } else if (status == 'WITHDRAWN') {
      statusColor = _soft;
      statusBg = const Color(0xFFF1F5F9);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  typeName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            startDate == endDate ? '$startDate ($days day)' : '$startDate – $endDate ($days days)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: $reason',
              style: const TextStyle(fontSize: 12.5, color: _soft),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 4: Tasks ───────────────────────────────────────────────────────────
  Widget _buildTasksTab() {
    if (_taskLoading && _tasks.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }
    if (_taskError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              Text('Failed to load tasks: $_taskError', style: const TextStyle(color: _soft)),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: () => _loadTasks(page: _taskPage), child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    if (_tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('No tasks assigned to this employee.', style: TextStyle(color: _soft)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assigned Tasks ($_taskTotalItems)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
            ),
            Text(
              'Page $_taskPage of $_taskTotalPages',
              style: const TextStyle(fontSize: 12, color: _soft, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),

        for (final task in _tasks) ...[
          _buildTaskCard(task),
          const SizedBox(height: 10),
        ],

        // Pagination row
        if (_taskTotalPages > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _taskPage > 1 ? () => _loadTasks(page: _taskPage - 1) : null,
              ),
              Text('$_taskPage / $_taskTotalPages', style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _taskPage < _taskTotalPages ? () => _loadTasks(page: _taskPage + 1) : null,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTaskCard(Map task) {
    final code = task['code']?.toString() ?? 'TSK';
    final title = task['title']?.toString() ?? 'Task';
    final status = (task['status'] ?? 'TODO').toString().toUpperCase();
    final priority = (task['priority'] ?? 'MEDIUM').toString().toUpperCase();
    final isOverdue = task['isOverdue'] == true;

    final project = (task['project'] is Map) ? task['project'] as Map : null;
    final projectName = project?['name']?.toString() ?? '';
    final projectColor = _parseColor(project?['color']?.toString() ?? '#6366f1');

    final dueAt = _formatDate(task['dueAt']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isOverdue ? _red.withValues(alpha: 0.5) : _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EDE6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  code,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
              if (projectName.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: projectColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    projectName,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: projectColor),
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'DONE' ? _greenBg : const Color(0xFFF1EDE6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: status == 'DONE' ? _green : _soft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPriorityBadge(priority),
              if (dueAt.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('Due: $dueAt', style: const TextStyle(fontSize: 12, color: _soft)),
              ],
              if (isOverdue) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _redBg, borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: _red),
                      SizedBox(width: 3),
                      Text('Overdue', style: TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color c = _soft;
    if (priority == 'URGENT') c = _red;
    if (priority == 'HIGH') c = const Color(0xFFF97316);
    if (priority == 'MEDIUM') c = _amber;
    if (priority == 'LOW') c = _green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'E';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String _prettyEmployment(String val) {
    final lower = val.toLowerCase().replaceAll('_', ' ');
    if (lower.isEmpty) return 'Full time';
    return lower[0].toUpperCase() + lower.substring(1);
  }

  static Color _parseColor(String hex) {
    var str = hex.replaceAll('#', '');
    if (str.length == 6) str = 'FF$str';
    final val = int.tryParse(str, radix: 16);
    return val != null ? Color(val) : const Color(0xFF3B82F6);
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final d = dt.day.toString().padLeft(2, '0');
      return '$d ${m[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  static String _formatDateTime(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final d = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$d ${m[dt.month - 1]} ${dt.year}, $hour:$minute';
    } catch (_) {
      return iso;
    }
  }

  static String _formatTime(String iso) {
    if (iso.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return iso;
    }
  }

  static String _shortDayNumber(String iso) {
    try {
      return '${DateTime.parse(iso).day}';
    } catch (_) {
      return '--';
    }
  }

  static String _shortMonthName(String iso) {
    try {
      const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return m[DateTime.parse(iso).month - 1].toUpperCase();
    } catch (_) {
      return '';
    }
  }
}
