import 'package:flutter/material.dart';
import 'api.dart';

/// Add or Edit employee page.
/// Submits `POST /employees` when adding or `PATCH /employees/:id` when editing.
class AddEmployeePage extends StatefulWidget {
  final Api api;
  final Map<String, dynamic>? employeeToEdit;
  final List<Map<String, dynamic>>? initialDepartments;
  final List<Map<String, dynamic>>? initialDesignations;
  final List<Map<String, dynamic>>? initialTeams;
  final List<Map<String, dynamic>>? initialManagers;

  const AddEmployeePage({
    super.key,
    required this.api,
    this.employeeToEdit,
    this.initialDepartments,
    this.initialDesignations,
    this.initialTeams,
    this.initialManagers,
  });

  bool get isEdit => employeeToEdit != null;

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

/// Edit employee page for updating employee details, department, designation, and roles.
/// Submits `PATCH /employees/:id`.
class EditEmployeePage extends StatelessWidget {
  final Api api;
  final Map<String, dynamic> employee;
  final List<Map<String, dynamic>>? initialDepartments;
  final List<Map<String, dynamic>>? initialDesignations;
  final List<Map<String, dynamic>>? initialTeams;
  final List<Map<String, dynamic>>? initialManagers;

  const EditEmployeePage({
    super.key,
    required this.api,
    required this.employee,
    this.initialDepartments,
    this.initialDesignations,
    this.initialTeams,
    this.initialManagers,
  });

  @override
  Widget build(BuildContext context) {
    return AddEmployeePage(
      api: api,
      employeeToEdit: employee,
      initialDepartments: initialDepartments,
      initialDesignations: initialDesignations,
      initialTeams: initialTeams,
      initialManagers: initialManagers,
    );
  }
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _cardBorder = Color(0xFFE8E2D9);
  static const Color _pageBg = Color(0xFFFAF8F5);
  static const Color _taskBrown = Color(0xFFBE5E38);
  static const Color _lightBg = Color(0xFFFFF9F5);

  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _workLocationCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _saving = false;

  // Employment Form State
  DateTime _joiningDate = DateTime.now();
  String _employmentType = 'FULL_TIME';
  String? _departmentId;
  String? _designationId;
  String? _managerId;
  final List<String> _selectedTeamIds = [];

  // Account Form State
  bool _createAccount = true;
  final Set<String> _selectedRoleIds = {};

  // Lookups data
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _designations = [];
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _managers = [];
  List<Map<String, dynamic>> _roles = [];

  // Fallback default roles matching system specification
  static const List<Map<String, dynamic>> _fallbackRoles = [
    {
      'id': '5b747832-c281-4559-99d0-81136edd9577',
      'code': 'ADMIN',
      'name': 'Admin',
      'scope': 'Organisation data',
      'description':
          'Organisation-wide administration of HRMS and Task Management. Cannot grant Super Admin.',
    },
    {
      'id': 'e49cc17f-10a6-4e14-82f5-7c927ef7f660',
      'code': 'EMPLOYEE',
      'name': 'Employee',
      'scope': 'Own data',
      'description':
          'Own profile, attendance, leave, regularisation, assigned tasks and issues.',
    },
    {
      'id': '032aca0e-8e12-4930-b1d3-3367f310c557',
      'code': 'MANAGER',
      'name': 'Manager',
      'scope': 'Team data',
      'description':
          'Manages mapped employees, their attendance, leave, regularisation, tasks and issues.',
    },
    {
      'id': '9d2ce184-29dd-410b-aa19-8abe47c7c966',
      'code': 'SUPER_ADMIN',
      'name': 'Super Admin',
      'scope': 'Organisation data',
      'description':
          'Full access to every module, setting and permission. Cannot be modified.',
    },
  ];

  bool get _isEdit => widget.employeeToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialDepartments != null) {
      _departments = List.from(widget.initialDepartments!);
    }
    if (widget.initialDesignations != null) {
      _designations = List.from(widget.initialDesignations!);
    }
    if (widget.initialTeams != null) {
      _teams = List.from(widget.initialTeams!);
    }
    if (widget.initialManagers != null) {
      _managers = List.from(widget.initialManagers!);
    }
    _roles = List.from(_fallbackRoles);

    if (_isEdit) {
      final emp = widget.employeeToEdit!;
      _codeCtrl.text = emp['employeeCode']?.toString() ?? '';
      _firstNameCtrl.text = emp['firstName']?.toString() ?? '';
      _lastNameCtrl.text = emp['lastName']?.toString() ?? '';
      _emailCtrl.text = emp['email']?.toString() ?? '';
      _phoneCtrl.text = emp['phone']?.toString() ?? '';
      _workLocationCtrl.text = emp['workLocation']?.toString() ?? '';

      final rawType = emp['employmentType']?.toString().toUpperCase();
      if (rawType == 'FULL_TIME' ||
          rawType == 'PART_TIME' ||
          rawType == 'CONTRACT' ||
          rawType == 'INTERN') {
        _employmentType = rawType!;
      }

      if (emp['joiningDate'] != null) {
        try {
          _joiningDate = DateTime.parse(emp['joiningDate'].toString());
        } catch (_) {}
      }

      if (emp['department'] is Map && emp['department']['id'] != null) {
        _departmentId = emp['department']['id']?.toString();
        if (!_departments.any((d) => d['id']?.toString() == _departmentId)) {
          _departments.add(Map<String, dynamic>.from(emp['department'] as Map));
        }
      } else if (emp['departmentId'] != null) {
        _departmentId = emp['departmentId']?.toString();
      }

      if (emp['designation'] is Map && emp['designation']['id'] != null) {
        _designationId = emp['designation']['id']?.toString();
        if (!_designations.any((d) => d['id']?.toString() == _designationId)) {
          _designations.add(Map<String, dynamic>.from(emp['designation'] as Map));
        }
      } else if (emp['designationId'] != null) {
        _designationId = emp['designationId']?.toString();
      }

      if (emp['manager'] is Map && emp['manager']['id'] != null) {
        _managerId = emp['manager']['id']?.toString();
        if (!_managers.any((m) => m['id']?.toString() == _managerId)) {
          _managers.add(Map<String, dynamic>.from(emp['manager'] as Map));
        }
      } else if (emp['managerId'] != null) {
        _managerId = emp['managerId']?.toString();
      }

      if (emp['teams'] is List) {
        for (final t in emp['teams']) {
          if (t is Map && t['id'] != null) {
            final tid = t['id'].toString();
            if (!_selectedTeamIds.contains(tid)) _selectedTeamIds.add(tid);
            if (!_teams.any((item) => item['id']?.toString() == tid)) {
              _teams.add(Map<String, dynamic>.from(t));
            }
          } else if (t is String && t.isNotEmpty) {
            if (!_selectedTeamIds.contains(t)) _selectedTeamIds.add(t);
          }
        }
      } else if (emp['teamIds'] is List) {
        for (final tid in emp['teamIds']) {
          if (tid != null && !_selectedTeamIds.contains(tid.toString())) {
            _selectedTeamIds.add(tid.toString());
          }
        }
      }

      // Populate roles for edit mode
      final accountRoles = (emp['account'] is Map && emp['account']['roles'] is List)
          ? emp['account']['roles'] as List
          : (emp['roles'] is List ? emp['roles'] as List : null);
      if (accountRoles != null && accountRoles.isNotEmpty) {
        _selectedRoleIds.clear();
        for (final r in accountRoles) {
          if (r is Map && r['id'] != null) {
            _selectedRoleIds.add(r['id'].toString());
          } else if (r != null) {
            _selectedRoleIds.add(r.toString());
          }
        }
      } else if (emp['roleIds'] is List && (emp['roleIds'] as List).isNotEmpty) {
        _selectedRoleIds.clear();
        for (final rid in emp['roleIds']) {
          if (rid != null) _selectedRoleIds.add(rid.toString());
        }
      }
    } else {
      // Default to Employee role
      final empRole = _roles.firstWhere(
        (r) => r['code']?.toString().toUpperCase() == 'EMPLOYEE',
        orElse: () => _roles.first,
      );
      if (empRole['id'] != null) {
        _selectedRoleIds.add(empRole['id'].toString());
      }
    }

    _loadLookups();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _workLocationCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final futures = await Future.wait([
        if (_departments.isEmpty)
          widget.api.v1('GET', '/departments', query: {
            'pageSize': 500,
            'sortBy': 'name',
            'sortDir': 'asc'
          }).catchError((_) => null)
        else
          Future.value(null),
        if (_designations.isEmpty)
          widget.api.v1('GET', '/designations', query: {
            'pageSize': 500,
            'sortBy': 'title',
            'sortDir': 'asc'
          }).catchError((_) => null)
        else
          Future.value(null),
        if (_teams.isEmpty)
          widget.api.v1('GET', '/teams', query: {
            'pageSize': 500,
            'sortBy': 'name',
            'sortDir': 'asc'
          }).catchError((_) => null)
        else
          Future.value(null),
        if (_managers.isEmpty)
          widget.api.v1('GET', '/employees/lookup', query: {
            'limit': 100
          }).catchError((_) => null)
        else
          Future.value(null),
        widget.api.v1('GET', '/roles').catchError((_) => null),
      ]);

      if (!mounted) return;

      final depRes = futures[0];
      final desRes = futures[1];
      final teamRes = futures[2];
      final mgrRes = futures[3];
      final rolesRes = futures[4];

      setState(() {
        if (depRes != null) {
          final items = (depRes is Map
              ? depRes['items']
              : (depRes is List ? depRes : null)) as List?;
          if (items != null) {
            _departments = items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
        if (desRes != null) {
          final items = (desRes is Map
              ? desRes['items']
              : (desRes is List ? desRes : null)) as List?;
          if (items != null) {
            _designations = items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
        if (teamRes != null) {
          final items = (teamRes is Map
              ? teamRes['items']
              : (teamRes is List ? teamRes : null)) as List?;
          if (items != null) {
            _teams = items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
        if (mgrRes != null) {
          final items = (mgrRes is List
              ? mgrRes
              : (mgrRes is Map ? (mgrRes['items'] ?? mgrRes['data']) : null))
              as List?;
          if (items != null) {
            _managers = items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
        if (rolesRes != null) {
          final items = (rolesRes is List
              ? rolesRes
              : (rolesRes is Map
                  ? (rolesRes['items'] ?? rolesRes['data'])
                  : null)) as List?;
          if (items != null && items.isNotEmpty) {
            _roles = items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            // Ensure employee role is selected by default if nothing selected yet
            if (!_isEdit && _selectedRoleIds.isEmpty) {
              final empRole = _roles.firstWhere(
                (r) => r['code']?.toString().toUpperCase() == 'EMPLOYEE',
                orElse: () => _roles.first,
              );
              if (empRole['id'] != null) {
                _selectedRoleIds.add(empRole['id'].toString());
              }
            }
          }
        }
      });
    } catch (_) {}
  }

  void _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
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
      setState(() => _joiningDate = picked);
    }
  }

  void _openTeamsPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Teams',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: _taskBrown,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                if (_teams.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No teams available',
                        style: TextStyle(color: _soft),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _teams.length,
                      itemBuilder: (_, idx) {
                        final t = _teams[idx];
                        final id = t['id']?.toString() ?? '';
                        final name = t['name']?.toString() ?? 'Team';
                        final isSelected = _selectedTeamIds.contains(id);
                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: _taskBrown,
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _ink,
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                _selectedTeamIds.add(id);
                              } else {
                                _selectedTeamIds.remove(id);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final code = _codeCtrl.text.trim().toUpperCase();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final workLocation = _workLocationCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    // Default to employee role if none selected
    final roleIds = _selectedRoleIds.isNotEmpty
        ? _selectedRoleIds.toList()
        : _roles
            .where((r) => r['code']?.toString().toUpperCase() == 'EMPLOYEE')
            .map((r) => r['id'].toString())
            .toList();

    final joiningDateFormatted =
        '${_joiningDate.year}-${_joiningDate.month.toString().padLeft(2, '0')}-${_joiningDate.day.toString().padLeft(2, '0')}';

    final payload = <String, dynamic>{
      'employeeCode': code,
      'firstName': firstName,
      'lastName': lastName.isNotEmpty ? lastName : '',
      'email': email,
      'phone': phone.isNotEmpty ? phone : null,
      'departmentId': _departmentId,
      'designationId': _designationId,
      'managerId': _managerId,
      'teamIds': _selectedTeamIds,
      'joiningDate': joiningDateFormatted,
      'employmentType': _employmentType,
      'workLocation': workLocation.isNotEmpty ? workLocation : null,
      'roleIds': _isEdit ? _selectedRoleIds.toList() : (_createAccount ? roleIds : <String>[]),
      if (!_isEdit) 'createAccount': _createAccount,
      if (!_isEdit && _createAccount && password.isNotEmpty) 'password': password,
    };

    setState(() => _saving = true);

    try {
      final dynamic res;
      if (_isEdit) {
        final id = widget.employeeToEdit!['id']?.toString() ?? '';
        res = await widget.api.v1('PATCH', '/employees/$id', body: payload);
      } else {
        res = await widget.api.v1('POST', '/employees', body: payload);
      }
      if (!mounted) return;

      // Check success
      if (res != null) {
        Navigator.pop(context, _isEdit ? (res ?? true) : true);
        return;
      }
      throw Exception(_isEdit ? 'Failed to update employee' : 'Failed to create employee');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_isEdit ? "Error updating" : "Error adding"} employee: ${e.toString().replaceAll("Exception:", "").trim()}',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDateDisplay =
        '${_joiningDate.day.toString().padLeft(2, '0')}/${_joiningDate.month.toString().padLeft(2, '0')}/${_joiningDate.year}';

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Edit Employee' : 'Add New Employee',
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Breadcrumbs & Title matching screenshot 1
              Text(
                _isEdit ? 'Employees / Edit' : 'Employees / New',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _soft,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isEdit ? 'Edit employee' : 'Add employee',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isEdit
                    ? 'Update employee profile, job details, and role assignments.'
                    : 'Create the employee record and, optionally, a login account.',
                style: const TextStyle(fontSize: 13.5, color: _soft),
              ),
              const SizedBox(height: 20),

              // CARD 1: Basic details
              _buildSectionCard(
                title: 'Basic details',
                children: [
                  _buildInputLabel('Employee code *'),
                  TextFormField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
                    decoration: _inputDecoration(hint: 'e.g. EM01'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Employee code is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Unique; stored in upper case.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF8B93A7)),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('First name *'),
                  TextFormField(
                    controller: _firstNameCtrl,
                    decoration: _inputDecoration(hint: 'e.g. John'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Last name'),
                  TextFormField(
                    controller: _lastNameCtrl,
                    decoration: _inputDecoration(hint: 'e.g. Doe'),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Work email *'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(hint: 'e.g. john.doe@company.com'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Work email is required';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Also used as the sign-in id.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF8B93A7)),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Phone'),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(hint: 'e.g. 252 262 2622'),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // CARD 2: Employment
              _buildSectionCard(
                title: 'Employment',
                children: [
                  _buildInputLabel('Joining date *'),
                  InkWell(
                    onTap: _pickJoiningDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              formattedDateDisplay,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Employment type *'),
                  DropdownButtonFormField<String>(
                    initialValue: _employmentType,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                    decoration: _inputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'FULL_TIME', child: Text('Full time')),
                      DropdownMenuItem(value: 'PART_TIME', child: Text('Part time')),
                      DropdownMenuItem(value: 'CONTRACT', child: Text('Contract')),
                      DropdownMenuItem(value: 'INTERN', child: Text('Intern')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _employmentType = v);
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Work location'),
                  TextFormField(
                    controller: _workLocationCtrl,
                    decoration: _inputDecoration(hint: 'e.g. Chennai HQ'),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Department'),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('dep_${_departmentId}_${_departments.length}'),
                    initialValue: _departmentId,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                    decoration: _inputDecoration(),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No department', style: TextStyle(color: Color(0xFF6B7280))),
                      ),
                      for (final dep in _departments)
                        DropdownMenuItem<String?>(
                          value: dep['id']?.toString(),
                          child: Text(dep['name']?.toString() ?? 'Department'),
                        ),
                      if (_departmentId != null &&
                          !_departments.any((d) => d['id']?.toString() == _departmentId))
                        DropdownMenuItem<String?>(
                          value: _departmentId,
                          child: Text(
                            (widget.employeeToEdit?['department'] is Map
                                    ? widget.employeeToEdit!['department']['name']
                                    : null)
                                ?.toString() ??
                                'Department',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _departmentId = v),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Designation'),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('des_${_designationId}_${_designations.length}'),
                    initialValue: _designationId,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                    decoration: _inputDecoration(),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No designation', style: TextStyle(color: Color(0xFF6B7280))),
                      ),
                      for (final des in _designations)
                        DropdownMenuItem<String?>(
                          value: des['id']?.toString(),
                          child: Text(
                            des['title']?.toString() ?? des['name']?.toString() ?? 'Designation',
                          ),
                        ),
                      if (_designationId != null &&
                          !_designations.any((d) => d['id']?.toString() == _designationId))
                        DropdownMenuItem<String?>(
                          value: _designationId,
                          child: Text(
                            (widget.employeeToEdit?['designation'] is Map
                                    ? (widget.employeeToEdit!['designation']['title'] ??
                                        widget.employeeToEdit!['designation']['name'])
                                    : null)
                                ?.toString() ??
                                'Designation',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _designationId = v),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Reporting manager'),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('mgr_${_managerId}_${_managers.length}'),
                    initialValue: _managerId,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                    decoration: _inputDecoration(),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No manager', style: TextStyle(color: Color(0xFF6B7280))),
                      ),
                      for (final mgr in _managers)
                        DropdownMenuItem<String?>(
                          value: mgr['id']?.toString(),
                          child: Text(
                            mgr['fullName']?.toString() ??
                                mgr['name']?.toString() ??
                                'Manager',
                          ),
                        ),
                      if (_managerId != null &&
                          !_managers.any((m) => m['id']?.toString() == _managerId))
                        DropdownMenuItem<String?>(
                          value: _managerId,
                          child: Text(
                            (widget.employeeToEdit?['manager'] is Map
                                    ? (widget.employeeToEdit!['manager']['fullName'] ??
                                        widget.employeeToEdit!['manager']['name'])
                                    : null)
                                ?.toString() ??
                                'Manager',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _managerId = v),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Must be an active employee.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF8B93A7)),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Teams'),
                  InkWell(
                    onTap: _openTeamsPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _selectedTeamIds.isEmpty
                                ? const Text(
                                    'Select teams...',
                                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                  )
                                : Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      for (final teamId in _selectedTeamIds)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Text(
                                            _teams.firstWhere(
                                              (t) => t['id']?.toString() == teamId,
                                              orElse: () => {'name': 'Team'},
                                            )['name']?.toString() ?? 'Team',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: _ink,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // CARD 3: Login account / Roles
              _buildSectionCard(
                title: _isEdit ? 'Assigned roles' : 'Login account',
                subtitle: _isEdit
                    ? 'Manage role assignments and access scope for this employee.'
                    : 'Employees without an account cannot sign in or mark attendance.',
                children: [
                  if (!_isEdit) ...[
                    Row(
                      children: [
                        Switch(
                          value: _createAccount,
                          activeThumbColor: Colors.white,
                          activeTrackColor: _taskBrown,
                          onChanged: (val) => setState(() => _createAccount = val),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Create a login account',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_createAccount) ...[
                      const SizedBox(height: 16),
                      _buildInputLabel('Initial password (optional)'),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          hint: 'Set initial password or leave blank',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: const Color(0xFF6B7280),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Leave blank to email the employee a secure set-password link instead (recommended).',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF8B93A7)),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                  if (_isEdit || _createAccount) ...[
                    _buildInputLabel(
                      _isEdit
                          ? 'Roles (select all that apply)'
                          : 'Roles (defaults to Employee when none selected)',
                    ),
                    const SizedBox(height: 6),

                    // Grid/List of role cards matching screenshot 2
                    for (final r in _roles) ...[
                      _buildRoleCard(
                        id: r['id']?.toString() ?? '',
                        code: r['code']?.toString() ?? '',
                        name: r['name']?.toString() ?? 'Role',
                        scope: r['scope']?.toString() ??
                            (r['code'] == 'EMPLOYEE'
                                ? 'Own data'
                                : (r['code'] == 'MANAGER' ? 'Team data' : 'Organisation data')),
                        description: r['description']?.toString() ?? '',
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // Bottom Actions Row matching screenshot 2
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _taskBrown,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _saving
                            ? (_isEdit ? 'Saving...' : 'Creating...')
                            : (_isEdit ? 'Save changes' : 'Create employee'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
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

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12.5, color: _soft),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _taskBrown, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.6),
      ),
    );
  }

  Widget _buildRoleCard({
    required String id,
    required String code,
    required String name,
    required String scope,
    required String description,
  }) {
    final isSelected = _selectedRoleIds.contains(id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedRoleIds.remove(id);
          } else {
            _selectedRoleIds.add(id);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _lightBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _taskBrown : _cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: isSelected,
                  activeColor: _taskBrown,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedRoleIds.add(id);
                      } else {
                        _selectedRoleIds.remove(id);
                      }
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: _ink,
                      ),
                      children: [
                        if (scope.isNotEmpty)
                          TextSpan(
                            text: ' · $scope',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5,
                              color: _soft,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
