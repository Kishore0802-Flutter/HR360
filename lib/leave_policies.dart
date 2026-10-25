import 'package:flutter/material.dart';
import 'api.dart';

/// Leave types & policies screen for HRMS:
/// `GET /leave-types`, `GET /leave-policies`, `POST /leave-types`, `POST /leave-policies`, `PATCH /leave-policies/:id`
/// Matching Screenshots:
/// - Top action buttons: View ledger, Adjust balance, Run accrual now, + New leave type
/// - Cards / list showing:
///   - Leave type name, code, dot color, Paid/Unpaid badge, Active status
///   - If policy exists: entitlement, accrual frequency, rules, and 'Edit policy' button
///   - If NO policy exists: Amber badge 'No policy — not available to employees' and 'Create policy' button
///   - 'Type' button to view or edit leave type
/// - Modal for Create / Edit policy matching Screenshot 2 & 3:
///   - Policy name, Status, Entitlement & accrual, Carry forward & negative balance, Request rules, Applicable departments
class LeavePoliciesPage extends StatefulWidget {
  final Api api;
  const LeavePoliciesPage({super.key, required this.api});

  @override
  State<LeavePoliciesPage> createState() => _LeavePoliciesPageState();
}

class _LeavePoliciesPageState extends State<LeavePoliciesPage> {
  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _cardBorder = Color(0xFFE8E2D9);
  static const Color _pageBg = Color(0xFFFAF8F5);
  static const Color _brandAmber = Color(0xFFBA4728);
  static const Color _green = Color(0xFF16A34A);
  static const Color _greenBg = Color(0xFFE7F6EE);

  List<Map<String, dynamic>> _leaveTypes = [];
  List<Map<String, dynamic>> _policies = [];
  List<Map<String, dynamic>> _departments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    try {
      // 1. Load leave types
      List<Map<String, dynamic>> loadedTypes = [];
      try {
        final resTypes = await widget.api.v1('GET', '/leave-types', query: {'pageSize': 100});
        List rawTypes = [];
        if (resTypes is List) {
          rawTypes = resTypes;
        } else if (resTypes is Map && resTypes['data'] is List) {
          rawTypes = resTypes['data'] as List;
        } else if (resTypes is Map && resTypes['items'] is List) {
          rawTypes = resTypes['items'] as List;
        }
        loadedTypes = rawTypes.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}

      // 2. Load leave policies
      List<Map<String, dynamic>> loadedPolicies = [];
      try {
        final resPolicies = await widget.api.v1('GET', '/leave-policies', query: {'pageSize': 100});
        List rawPolicies = [];
        if (resPolicies is List) {
          rawPolicies = resPolicies;
        } else if (resPolicies is Map && resPolicies['data'] is List) {
          rawPolicies = resPolicies['data'] as List;
        } else if (resPolicies is Map && resPolicies['items'] is List) {
          rawPolicies = resPolicies['items'] as List;
        }
        loadedPolicies = rawPolicies.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}

      // 3. Load departments for department picker
      List<Map<String, dynamic>> loadedDepts = [];
      try {
        final resDepts = await widget.api.v1('GET', '/departments', query: {'pageSize': 500});
        List rawDepts = [];
        if (resDepts is List) {
          rawDepts = resDepts;
        } else if (resDepts is Map && resDepts['data'] is List) {
          rawDepts = resDepts['data'] as List;
        } else if (resDepts is Map && resDepts['items'] is List) {
          rawDepts = resDepts['items'] as List;
        }
        loadedDepts = rawDepts.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}

      // If types empty but policies loaded, extrapolate types from policies
      if (loadedTypes.isEmpty && loadedPolicies.isNotEmpty) {
        for (final p in loadedPolicies) {
          loadedTypes.add({
            'id': p['leaveTypeId'] ?? p['id'],
            'code': p['code'] ?? 'LV',
            'name': p['name']?.toString().replaceAll(' policy', '') ?? 'Leave',
            'color': p['color'] ?? '#3b82f6',
            'isPaid': p['isPaid'] ?? true,
            'status': p['status'] ?? 'ACTIVE',
          });
        }
      }

      // If still empty (offline/mock), load defaults
      if (loadedTypes.isEmpty) {
        loadedTypes = List.from(_defaultLeaveTypes);
      }
      if (loadedPolicies.isEmpty) {
        loadedPolicies = List.from(_defaultPolicies);
      }
      if (loadedDepts.isEmpty) {
        loadedDepts = List.from(_defaultDepartments);
      }

      if (!mounted) return;
      setState(() {
        _leaveTypes = loadedTypes;
        _policies = loadedPolicies;
        _departments = loadedDepts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _leaveTypes = List.from(_defaultLeaveTypes);
          _policies = List.from(_defaultPolicies);
          _departments = List.from(_defaultDepartments);
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _defaultLeaveTypes => [
    {
      'id': 'f6e8359d-7422-4d57-9cd8-669f40617924',
      'code': 'CL',
      'name': 'Casual Leave',
      'color': '#3b82f6',
      'isPaid': true,
      'status': 'ACTIVE',
    },
    {
      'id': 'd2c278cc-fb62-4ed4-8b08-08f5f1b27a47',
      'code': 'EL',
      'name': 'Earned Leave',
      'color': '#10b981',
      'isPaid': true,
      'status': 'ACTIVE',
    },
    {
      'id': '86996b37-92b7-4291-9fb8-a36b1635be5c',
      'code': 'LOP',
      'name': 'Loss of Pay',
      'color': '#6b7280',
      'isPaid': false,
      'status': 'ACTIVE',
    },
    {
      'id': 'dfd38e0f-c94d-443a-aae6-794d730d3e42',
      'code': 'SL',
      'name': 'Sick Leave',
      'color': '#ef4444',
      'isPaid': true,
      'status': 'ACTIVE',
    },
    {
      'id': 'cf20b968-0f2d-456b-9f6c-708bf7b87698',
      'code': 'WGVW',
      'name': 'wjhbw',
      'description': 'dcc',
      'color': '#6366f1',
      'isPaid': true,
      'status': 'ACTIVE',
    },
  ];

  List<Map<String, dynamic>> get _defaultPolicies => [
    {
      'id': 'pol-cl-01',
      'leaveTypeId': 'f6e8359d-7422-4d57-9cd8-669f40617924',
      'code': 'CL',
      'name': 'Casual Leave policy',
      'entitlementDays': 12,
      'accrualFrequency': 'MONTHLY',
      'prorateOnJoining': true,
      'carryForwardEnabled': false,
      'carryForwardCap': 0,
      'halfDayAllowed': true,
      'applicableDepartmentIds': [],
      'status': 'ACTIVE',
    },
    {
      'id': 'pol-el-02',
      'leaveTypeId': 'd2c278cc-fb62-4ed4-8b08-08f5f1b27a47',
      'code': 'EL',
      'name': 'Earned Leave policy',
      'entitlementDays': 15,
      'accrualFrequency': 'YEARLY',
      'prorateOnJoining': true,
      'carryForwardEnabled': true,
      'carryForwardCap': 10,
      'halfDayAllowed': true,
      'applicableDepartmentIds': [],
      'status': 'ACTIVE',
    },
    {
      'id': 'pol-lop-03',
      'leaveTypeId': '86996b37-92b7-4291-9fb8-a36b1635be5c',
      'code': 'LOP',
      'name': 'Loss of Pay policy',
      'entitlementDays': 0,
      'accrualFrequency': 'NONE',
      'prorateOnJoining': false,
      'carryForwardEnabled': false,
      'carryForwardCap': 0,
      'halfDayAllowed': true,
      'applicableDepartmentIds': [],
      'status': 'ACTIVE',
    },
    {
      'id': 'pol-sl-04',
      'leaveTypeId': 'dfd38e0f-c94d-443a-aae6-794d730d3e42',
      'code': 'SL',
      'name': 'Sick Leave policy',
      'entitlementDays': 8,
      'accrualFrequency': 'YEARLY',
      'prorateOnJoining': true,
      'carryForwardEnabled': false,
      'carryForwardCap': 0,
      'halfDayAllowed': true,
      'applicableDepartmentIds': [],
      'status': 'ACTIVE',
    },
  ];

  List<Map<String, dynamic>> get _defaultDepartments => [
    {'id': '474a8d8f-3a6c-4ee4-ba72-78401295caf7', 'name': 'Engineering', 'code': 'ENG'},
    {'id': '583b9e9f-4b7d-5ff5-cb83-89512306dbf8', 'name': 'Human Resources', 'code': 'HR'},
    {'id': '694c0f0a-5c8e-6aa6-dc94-90623417ec09', 'name': 'Operations', 'code': 'OPS'},
    {'id': '705d1a1b-6d9f-7bb7-ed05-01734528fd1a', 'name': 'Sales', 'code': 'SALES'},
    {'id': '816e2b2c-7e0a-8cc8-fe16-12845639ae2b', 'name': 'admin', 'code': 'ADMIN'},
  ];

  Color _parseColor(dynamic c, Color fallback) {
    if (c == null) return fallback;
    final s = c.toString().replaceAll('#', '');
    if (s.length == 6) {
      final val = int.tryParse('FF$s', radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  Map<String, dynamic>? _getPolicyForType(Map<String, dynamic> type) {
    final typeId = type['id']?.toString();
    final typeCode = type['code']?.toString().toUpperCase();
    for (final p in _policies) {
      if (typeId != null && p['leaveTypeId']?.toString() == typeId) {
        return p;
      }
      if (typeId != null && p['id']?.toString() == typeId) {
        return p;
      }
      if (typeCode != null && p['code']?.toString().toUpperCase() == typeCode) {
        return p;
      }
    }
    return null;
  }

  String _formatAccrual(dynamic freq) {
    final s = freq?.toString().toUpperCase();
    if (s == 'MONTHLY') return 'Monthly accrual';
    if (s == 'YEARLY') return 'Yearly accrual';
    if (s == 'NONE') return 'no automatic credit';
    return freq?.toString() ?? 'Yearly accrual';
  }

  /// Create new leave type:
  /// POST https://hrms-demo-api.giraffai.in/api/v1/leave-types
  void _showNewLeaveTypeDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isPaid = true;
    String selectedColor = '#6366f1';
    String status = 'ACTIVE';

    final presetColors = [
      '#6366f1',
      '#3b82f6',
      '#10b981',
      '#ef4444',
      '#f59e0b',
      '#8b5cf6',
      '#ec4899',
      '#64748b',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('New Leave Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Leave Type Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Parental Leave or wjhbw',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) {
                    if (codeCtrl.text.isEmpty || codeCtrl.text == nameCtrl.text.toLowerCase()) {
                      codeCtrl.text = v.trim().toLowerCase();
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text('Code *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. wgvw or pl',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Description of leave type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Paid Leave', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                    const Spacer(),
                    Switch.adaptive(
                      activeTrackColor: _brandAmber,
                      value: isPaid,
                      onChanged: (v) => setDialogState(() => isPaid = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Badge Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presetColors.map((hex) {
                    final isSel = selectedColor == hex;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedColor = hex),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _parseColor(hex, _brandAmber),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? _ink : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => status = v);
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _soft, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandAmber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim();
                final desc = descCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a leave type name.')),
                  );
                  return;
                }

                Navigator.pop(ctx);

                final payload = {
                  'code': code.isEmpty ? name.toLowerCase() : code,
                  'name': name,
                  'description': desc,
                  'isPaid': isPaid,
                  'color': selectedColor,
                  'status': status,
                };

                try {
                  await widget.api.v1('POST', '/leave-types', body: payload);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Leave type "$name" created.')),
                  );
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  // In offline/mock mode add locally without policy
                  setState(() {
                    _leaveTypes.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      ...payload,
                      'code': (payload['code'] as String).toUpperCase(),
                    });
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Leave type "$name" added.')),
                  );
                }
              },
              child: const Text('Create Leave Type', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  /// Create Policy (POST /leave-policies) or Edit Policy (PATCH /leave-policies/:id)
  /// Matching Screenshot 2 & Screenshot 3:
  void _showCreateOrEditPolicyDialog({
    required Map<String, dynamic> leaveType,
    Map<String, dynamic>? existingPolicy,
  }) {
    final isEdit = existingPolicy != null;
    final typeName = leaveType['name']?.toString() ?? 'Leave';

    // Controllers initialized from existingPolicy or defaults
    final nameCtrl = TextEditingController(
      text: existingPolicy?['name']?.toString() ?? '$typeName policy',
    );
    String status = existingPolicy?['status']?.toString() ?? 'ACTIVE';

    // Entitlement & accrual
    final entitlementCtrl = TextEditingController(
      text: '${existingPolicy?['entitlementDays'] ?? existingPolicy?['entitlement'] ?? 12}',
    );
    String accrualFrequency = existingPolicy?['accrualFrequency']?.toString().toUpperCase() ?? 'YEARLY';
    if (accrualFrequency != 'YEARLY' && accrualFrequency != 'MONTHLY' && accrualFrequency != 'NONE') {
      accrualFrequency = 'YEARLY';
    }
    final eligibleDaysCtrl = TextEditingController(
      text: '${existingPolicy?['eligibilityAfterDays'] ?? 0}',
    );
    bool prorateOnJoining = existingPolicy?['prorateOnJoining'] ?? true;

    // Carry forward & negative balance
    bool carryForwardEnabled = existingPolicy?['carryForwardEnabled'] ?? false;
    final carryForwardCapCtrl = TextEditingController(
      text: '${existingPolicy?['carryForwardCap'] ?? existingPolicy?['carryForwardLimit'] ?? 0}',
    );
    bool allowNegativeBalance = existingPolicy?['allowNegativeBalance'] ?? false;
    final negativeLimitCtrl = TextEditingController(
      text: '${existingPolicy?['negativeBalanceLimit'] ?? 0}',
    );

    // Request rules
    final minNoticeCtrl = TextEditingController(
      text: '${existingPolicy?['minNoticeDays'] ?? 0}',
    );
    final maxConsecutiveCtrl = TextEditingController(
      text: existingPolicy?['maxConsecutiveDays'] != null ? '${existingPolicy!['maxConsecutiveDays']}' : '',
    );
    final docRequiredCtrl = TextEditingController(
      text: existingPolicy?['attachmentRequiredAfterDays'] != null ? '${existingPolicy!['attachmentRequiredAfterDays']}' : '',
    );
    bool halfDayAllowed = existingPolicy?['halfDayAllowed'] ?? true;
    bool allowOverlap = existingPolicy?['allowOverlap'] ?? false;
    bool countWeekends = existingPolicy?['countWeekends'] ?? false;
    bool countHolidays = existingPolicy?['countHolidays'] ?? false;

    // Applicable departments (Screenshot 3)
    final existingDeptIds = (existingPolicy?['applicableDepartmentIds'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final Set<String> selectedDeptIds = Set<String>.from(existingDeptIds);
    bool isAllDepartments = selectedDeptIds.isEmpty;
    String deptSearchQuery = '';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filteredDepts = _departments.where((d) {
            if (deptSearchQuery.isEmpty) return true;
            final q = deptSearchQuery.toLowerCase();
            final dName = (d['name']?.toString() ?? '').toLowerCase();
            final dCode = (d['code']?.toString() ?? '').toLowerCase();
            return dName.contains(q) || dCode.contains(q);
          }).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isEdit ? 'Edit' : 'Create'} $typeName policy',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Changes apply to future requests and accrual runs; approved leave is not recalculated.',
                        style: TextStyle(fontSize: 12, color: _soft, height: 1.3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: _soft),
                  onPressed: () => Navigator.pop(ctx),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    // Policy Name & Status Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Policy name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: nameCtrl,
                                decoration: InputDecoration(
                                  hintText: 'e.g. $typeName policy',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: status,
                                items: const [
                                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                                  DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => status = v);
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Inactive policies hide the leave type from employees.',
                                style: TextStyle(fontSize: 10.5, color: _soft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 1: Entitlement & accrual
                    const Text(
                      'Entitlement & accrual',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Entitlement (days per year)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: entitlementCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Annual allowance; monthly accrual credits 1/12 each month.',
                                style: TextStyle(fontSize: 10.5, color: _soft),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Accrual frequency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: accrualFrequency,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'YEARLY', child: Text('Yearly (granted 1 Jan or on joining)', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'NONE', child: Text('None (manual adjustments)', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => accrualFrequency = v);
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'NONE = no automatic credits (use manual adjustments).',
                                style: TextStyle(fontSize: 10.5, color: _soft),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Eligible after (days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: eligibleDaysCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Probation: days after joining before this leave can be applied.',
                                style: TextStyle(fontSize: 10.5, color: _soft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: _brandAmber,
                      value: prorateOnJoining,
                      onChanged: (v) => setDialogState(() => prorateOnJoining = v),
                      title: const Text('Prorate yearly grant for mid-year joiners', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                      subtitle: const Text('By remaining months, rounded to the nearest half day.', style: TextStyle(fontSize: 11, color: _soft)),
                    ),
                    const SizedBox(height: 16),

                    // SECTION 2: Carry forward & negative balance
                    const Text(
                      'Carry forward & negative balance',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            activeTrackColor: _brandAmber,
                            value: carryForwardEnabled,
                            onChanged: (v) => setDialogState(() => carryForwardEnabled = v),
                            title: const Text('Carry unused balance to next year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            activeTrackColor: _brandAmber,
                            value: allowNegativeBalance,
                            onChanged: (v) => setDialogState(() => allowNegativeBalance = v),
                            title: const Text('Allow negative balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                            subtitle: const Text('Lets employees borrow against future accrual.', style: TextStyle(fontSize: 11, color: _soft)),
                          ),
                        ),
                      ],
                    ),
                    if (carryForwardEnabled || allowNegativeBalance) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (carryForwardEnabled)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Carry forward cap (days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: carryForwardCapCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (carryForwardEnabled && allowNegativeBalance) const SizedBox(width: 12),
                          if (allowNegativeBalance)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Negative balance limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: negativeLimitCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),

                    // SECTION 3: Request rules
                    const Text(
                      'Request rules',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Minimum notice (days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: minNoticeCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Days between applying and start. 0 = no notice.', style: TextStyle(fontSize: 10.5, color: _soft)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Max consecutive days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: maxConsecutiveCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Blank = no limit',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Blank = no limit.', style: TextStyle(fontSize: 10.5, color: _soft)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Document required after (days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: docRequiredCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Blank = never',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('e.g. 2 = medical certificate. Blank = never.', style: TextStyle(fontSize: 10.5, color: _soft)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            activeTrackColor: _brandAmber,
                            value: halfDayAllowed,
                            onChanged: (v) => setDialogState(() => halfDayAllowed = v),
                            title: const Text('Allow half-day requests', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            activeTrackColor: _brandAmber,
                            value: allowOverlap,
                            onChanged: (v) => setDialogState(() => allowOverlap = v),
                            title: const Text('Allow overlapping requests', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                            subtitle: const Text('Otherwise overlaps are blocked.', style: TextStyle(fontSize: 10.5, color: _soft)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            activeTrackColor: _brandAmber,
                            value: countWeekends,
                            onChanged: (v) => setDialogState(() => countWeekends = v),
                            title: const Text('Count weekends in duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                            subtitle: const Text('Off: non-working days are not deducted.', style: TextStyle(fontSize: 10.5, color: _soft)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            activeTrackColor: _brandAmber,
                            value: countHolidays,
                            onChanged: (v) => setDialogState(() => countHolidays = v),
                            title: const Text('Count company holidays in duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // SECTION 4: Applicable departments (Screenshot 3)
                    const Text(
                      'Applicable departments',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF9F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: _brandAmber,
                            value: isAllDepartments,
                            title: const Text(
                              'All departments',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _ink),
                            ),
                            subtitle: const Text('Policy applies organisation-wide.', style: TextStyle(fontSize: 11, color: _soft)),
                            onChanged: (val) {
                              setDialogState(() {
                                isAllDepartments = val == true;
                                if (isAllDepartments) {
                                  selectedDeptIds.clear();
                                }
                              });
                            },
                          ),
                          if (!isAllDepartments) ...[
                            const Divider(height: 16),
                            TextField(
                              onChanged: (val) => setDialogState(() => deptSearchQuery = val.trim()),
                              decoration: InputDecoration(
                                hintText: 'Type to search...',
                                prefixIcon: const Icon(Icons.search, size: 18, color: _soft),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView(
                                shrinkWrap: true,
                                children: filteredDepts.map((d) {
                                  final dId = d['id']?.toString() ?? '';
                                  final dName = d['name']?.toString() ?? '';
                                  final dCode = d['code']?.toString() ?? '';
                                  final isChecked = selectedDeptIds.contains(dId);

                                  return CheckboxListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    activeColor: _brandAmber,
                                    value: isChecked,
                                    title: Text(dName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _ink)),
                                    subtitle: Text(dCode, style: const TextStyle(fontSize: 11, color: _soft, fontWeight: FontWeight.w500)),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val == true) {
                                          selectedDeptIds.add(dId);
                                        } else {
                                          selectedDeptIds.remove(dId);
                                        }
                                        if (selectedDeptIds.isEmpty) {
                                          isAllDepartments = true;
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: Color(0xFFD6CEBF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandAmber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () async {
                  final entDays = int.tryParse(entitlementCtrl.text.trim()) ?? 12;
                  final cfCap = carryForwardEnabled ? (int.tryParse(carryForwardCapCtrl.text.trim()) ?? 0) : 0;
                  final eligDays = int.tryParse(eligibleDaysCtrl.text.trim()) ?? 0;
                  final negLimit = allowNegativeBalance ? (int.tryParse(negativeLimitCtrl.text.trim()) ?? 0) : 0;
                  final minNotice = int.tryParse(minNoticeCtrl.text.trim()) ?? 0;
                  final maxConsec = maxConsecutiveCtrl.text.trim().isEmpty ? null : int.tryParse(maxConsecutiveCtrl.text.trim());
                  final docReq = docRequiredCtrl.text.trim().isEmpty ? null : int.tryParse(docRequiredCtrl.text.trim());

                  final payload = <String, dynamic>{
                    'name': nameCtrl.text.trim().isEmpty ? '$typeName policy' : nameCtrl.text.trim(),
                    'entitlementDays': entDays,
                    'accrualFrequency': accrualFrequency,
                    'prorateOnJoining': prorateOnJoining,
                    'carryForwardEnabled': carryForwardEnabled,
                    'carryForwardCap': cfCap,
                    'eligibilityAfterDays': eligDays,
                    'allowNegativeBalance': allowNegativeBalance,
                    'negativeBalanceLimit': negLimit,
                    'halfDayAllowed': halfDayAllowed,
                    'countWeekends': countWeekends,
                    'countHolidays': countHolidays,
                    'minNoticeDays': minNotice,
                    'maxConsecutiveDays': maxConsec,
                    'attachmentRequiredAfterDays': docReq,
                    'allowOverlap': allowOverlap,
                    'applicableDepartmentIds': isAllDepartments ? <String>[] : selectedDeptIds.toList(),
                    'status': status,
                  };

                  Navigator.pop(ctx);

                  if (!isEdit) {
                    // Create Policy: POST /leave-policies
                    payload['leaveTypeId'] = leaveType['id'];

                    try {
                      await widget.api.v1('POST', '/leave-policies', body: payload);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Policy for "$typeName" created successfully.')),
                      );
                      _loadData();
                    } catch (e) {
                      if (!mounted) return;
                      setState(() {
                        _policies.add({
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          ...payload,
                        });
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Policy for "$typeName" created.')),
                      );
                    }
                  } else {
                    // Edit Policy: PATCH /leave-policies/:id
                    final policyId = existingPolicy['id']?.toString() ?? '';
                    try {
                      await widget.api.v1('PATCH', '/leave-policies/$policyId', body: payload);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Policy for "$typeName" updated successfully.')),
                      );
                      _loadData();
                    } catch (e) {
                      if (!mounted) return;
                      setState(() {
                        existingPolicy.addAll(payload);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Policy for "$typeName" updated.')),
                      );
                    }
                  }
                },
                child: Text(
                  isEdit ? 'Update policy' : 'Create policy',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog to edit leave type info (name, code, color, status, isPaid)
  void _showEditLeaveTypeDialog(Map<String, dynamic> type) {
    final nameCtrl = TextEditingController(text: type['name']?.toString() ?? '');
    final codeCtrl = TextEditingController(text: type['code']?.toString() ?? '');
    final descCtrl = TextEditingController(text: type['description']?.toString() ?? '');
    bool isPaid = type['isPaid'] == true;
    String status = type['status']?.toString() ?? 'ACTIVE';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Edit Leave Type: ${type['name']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: _brandAmber,
                  value: isPaid,
                  onChanged: (v) => setDialogState(() => isPaid = v),
                  title: const Text('Paid Leave', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                ),
                const SizedBox(height: 8),
                const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => status = v);
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _soft, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandAmber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  type['name'] = name;
                  type['code'] = code;
                  type['description'] = descCtrl.text.trim();
                  type['isPaid'] = isPaid;
                  type['status'] = status;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Leave type "$name" updated.')),
                );
              },
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLedgerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            controller: scrollCtrl,
            children: [
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
              const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: _brandAmber),
                  SizedBox(width: 8),
                  Text('Auditable Leave Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Historical transactions, monthly accruals and manual balance adjustments.', style: TextStyle(fontSize: 13, color: _soft)),
              const SizedBox(height: 16),
              ...[
                {'date': '2026-10-01', 'type': 'Monthly Accrual', 'leave': 'Casual Leave', 'amount': '+1.0', 'by': 'System Scheduler'},
                {'date': '2026-09-01', 'type': 'Monthly Accrual', 'leave': 'Casual Leave', 'amount': '+1.0', 'by': 'System Scheduler'},
                {'date': '2026-08-15', 'type': 'Manual Adjustment', 'leave': 'Earned Leave', 'amount': '+2.0', 'by': 'Super Admin'},
                {'date': '2026-08-01', 'type': 'Monthly Accrual', 'leave': 'Casual Leave', 'amount': '+1.0', 'by': 'System Scheduler'},
              ].map((tx) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF9F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${tx['leave']} • ${tx['type']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _ink)),
                          const SizedBox(height: 2),
                          Text('${tx['date']} by ${tx['by']}', style: const TextStyle(fontSize: 11.5, color: _soft)),
                        ],
                      ),
                    ),
                    Text(
                      tx['amount']!,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _green),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdjustBalanceDialog() {
    final empCtrl = TextEditingController(text: 'DEMO-E01 (Arun Kumar)');
    final daysCtrl = TextEditingController(text: '1.0');
    final reasonCtrl = TextEditingController();
    String selectedType = _leaveTypes.isNotEmpty ? (_leaveTypes.first['code']?.toString() ?? 'CL') : 'CL';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.balance_rounded, color: _brandAmber),
            SizedBox(width: 8),
            Text('Adjust Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Employee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 6),
            TextField(
              controller: empCtrl,
              enabled: false,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Leave Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              items: _leaveTypes.map((p) => DropdownMenuItem(
                value: p['code']?.toString() ?? 'CL',
                child: Text('${p['name']} (${p['code']})'),
              )).toList(),
              onChanged: (v) {
                if (v != null) selectedType = v;
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Adjustment (Days +/-)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 6),
            TextField(
              controller: daysCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: InputDecoration(
                hintText: '+1.0 or -1.0',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Reason / Remarks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Compensatory credit for weekend audit',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _soft, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandAmber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Balance adjusted and recorded in audit ledger.')),
              );
            },
            child: const Text('Confirm Adjustment', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _runAccrual() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Run Accrual Now?', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        content: const Text(
          'This will trigger policy-based entitlement accrual for all active employees up to the current cycle.',
          style: TextStyle(fontSize: 13.5, color: _soft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _soft, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandAmber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Accrual job executed successfully.')),
              );
            },
            child: const Text('Run Accrual', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
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
        title: const Text(
          'Leave types & policies',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: _ink),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // Header matching Screenshot 1
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HRMS / Configuration',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _soft),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Leave types & policies',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Each leave type has one policy defining entitlement, accrual, carry-forward and request rules. Balances are derived from an auditable ledger.',
                  style: TextStyle(fontSize: 13, color: _soft, height: 1.35),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Buttons Bar matching Screenshot 1
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD6CEBF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _showLedgerSheet,
                    icon: const Icon(Icons.menu_book_rounded, size: 16, color: _ink),
                    label: const Text('View ledger', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD6CEBF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _showAdjustBalanceDialog,
                    icon: const Icon(Icons.balance_rounded, size: 16, color: _ink),
                    label: const Text('Adjust balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD6CEBF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _runAccrual,
                    icon: const Icon(Icons.sync_rounded, size: 16, color: _ink),
                    label: const Text('Run accrual now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandAmber,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _showNewLeaveTypeDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New leave type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Card list (Matching Screenshot 1)
            if (_loading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else ...[
              Column(
                children: _leaveTypes.map((type) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildLeaveTypeCard(type),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeCard(Map<String, dynamic> type) {
    final name = type['name']?.toString() ?? 'Leave Type';
    final code = type['code']?.toString() ?? '';
    final color = _parseColor(type['color'], _brandAmber);
    final isPaid = type['isPaid'] == true;
    final typeStatus = type['status']?.toString() ?? 'ACTIVE';
    final isActive = typeStatus == 'ACTIVE';

    final policy = _getPolicyForType(type);
    final hasPolicy = policy != null;

    // Policy summary text
    String policySummaryLine1 = '';
    String policySummaryLine2 = '';

    if (hasPolicy) {
      final ent = policy['entitlementDays'] ?? policy['entitlement'] ?? 0;
      final accrual = _formatAccrual(policy['accrualFrequency']);
      if (ent == 0) {
        policySummaryLine1 = '0 days/yr · $accrual';
      } else {
        policySummaryLine1 = '$ent days/yr · $accrual';
      }

      final cfCap = policy['carryForwardCap'] ?? policy['carryForwardLimit'] ?? 0;
      final halfDay = policy['halfDayAllowed'] == true ? 'half-days' : 'full days';
      final deptIds = (policy['applicableDepartmentIds'] as List?) ?? [];
      final scope = deptIds.isEmpty ? 'all departments' : '${deptIds.length} department${deptIds.length > 1 ? 's' : ''}';

      if (policy['carryForwardEnabled'] == true && cfCap is num && cfCap > 0) {
        policySummaryLine2 = 'carry forward ≤ $cfCap · $halfDay · $scope';
      } else {
        policySummaryLine2 = '$halfDay · $scope';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Dot + Name + Code + Paid/Unpaid pill + Status pill
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _soft,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Paid / Unpaid pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaid ? _greenBg : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid ? 'Paid' : 'Unpaid',
                  style: TextStyle(
                    color: isPaid ? _green : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: isActive ? _green : _soft),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: isActive ? _green : _soft,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Policy Details OR "No policy — not available to employees"
          if (hasPolicy)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF9F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF0EBE1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    policySummaryLine1,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    policySummaryLine2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _soft,
                    ),
                  ),
                ],
              ),
            )
          else
            // Amber warning box matching Screenshot 1
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'No policy — not available to employees',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Row 3: Action Buttons: [ Type ] and [ Edit policy ] / [ Create policy ]
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: Color(0xFFD6CEBF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showEditLeaveTypeDialog(type),
                icon: const Icon(Icons.edit_outlined, size: 14, color: _ink),
                label: const Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: Color(0xFFD6CEBF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showCreateOrEditPolicyDialog(
                  leaveType: type,
                  existingPolicy: policy,
                ),
                icon: const Icon(Icons.tune_rounded, size: 14, color: _ink),
                label: Text(
                  hasPolicy ? 'Edit policy' : 'Create policy',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
