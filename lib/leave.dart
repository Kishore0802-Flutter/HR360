import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api.dart';
import 'design.dart';

class LeavePage extends StatefulWidget {
  final Api api;
  const LeavePage({super.key, required this.api});
  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  int _selectedTab = 0; // 0: My leave, 1: Calendar
  int _selectedYear = 2026;
  String _statusFilter = 'All';
  Json? balances;
  List<Json> requests = [];
  bool loading = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final b = await widget.api.get(
        '/leave-balances/me',
        query: {'year': '$_selectedYear'},
      );
      balances = b;
    } catch (e) {
      error = e;
    }
    try {
      final r = await widget.api.get(
        '/leave-requests',
        query: {
          'mine': 'true',
          'page': '1',
          'pageSize': '20',
          'sortBy': 'createdAt',
          'sortDir': 'desc',
        },
      );
      requests = items(r);
    } catch (_) {
      requests = [];
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _handleWithdraw(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Request'),
        content: const Text(
          'Are you sure you want to withdraw this leave request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBA4728),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.post('/leave-requests/$id/withdraw', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request withdrawn successfully.'),
            backgroundColor: Color(0xFF1B7F56),
          ),
        );
        load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to withdraw request: $e'),
            backgroundColor: const Color(0xFFC24127),
          ),
        );
      }
    }
  }

  Future<void> _handleCancel(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Leave'),
        content: const Text(
          'Are you sure you want to cancel this approved leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBA4728),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.post('/leave-requests/$id/cancel', {
        'reason': 'Cancelled by employee',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave cancelled successfully.'),
            backgroundColor: Color(0xFF1B7F56),
          ),
        );
        load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel leave: $e'),
            backgroundColor: const Color(0xFFC24127),
          ),
        );
      }
    }
  }

  List<Json> get _filteredRequests {
    if (_statusFilter == 'All') return requests;
    return requests.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      return s == _statusFilter.toLowerCase();
    }).toList();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final parsed = DateTime.parse(raw);
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
      return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
    } catch (_) {
      return raw;
    }
  }

  String _formatDateRange(String? start, String? end) {
    if (start == null || start.isEmpty) return '—';
    final s = _formatDate(start);
    if (end == null || end.isEmpty || start == end) return s;
    final e = _formatDate(end);
    return '$s - $e';
  }

  Color _parseColor(
    dynamic colorValue, {
    Color fallback = const Color(0xFF3B82F6),
  }) {
    if (colorValue == null) return fallback;
    if (colorValue is Color) return colorValue;
    final s = colorValue.toString().trim();
    if (s.startsWith('#')) {
      final hex = s.replaceFirst('#', '');
      if (hex.length == 6) {
        final val = int.tryParse('FF$hex', radix: 16);
        if (val != null) return Color(val);
      } else if (hex.length == 8) {
        final val = int.tryParse(hex, radix: 16);
        if (val != null) return Color(val);
      }
    }
    return fallback;
  }

  Widget _buildTopTabs() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFEB),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton('My leave', 0),
          _buildTabButton('Calendar', 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: isSelected
              ? Border.all(color: const Color(0xFFE5DFD7), width: 1)
              : null,
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF1E242B)
                : const Color(0xFF6B7280),
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    final currentYear = DateTime.now().year;
    final years = [
      currentYear - 1,
      currentYear,
      currentYear + 1,
      currentYear + 2,
    ];
    return PopupMenuButton<int>(
      initialValue: _selectedYear,
      onSelected: (year) {
        if (year != _selectedYear) {
          setState(() => _selectedYear = year);
          load();
        }
      },
      itemBuilder: (context) {
        return years.map((y) {
          return PopupMenuItem<int>(
            value: y,
            child: Text(
              '$y',
              style: TextStyle(
                fontWeight: y == _selectedYear
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: const Color(0xFF1E242B),
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5EFEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5DFD7), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_selectedYear',
              style: const TextStyle(
                color: Color(0xFF1E242B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFBA4728),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      onPressed: () async {
        final applied = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => ApplyLeavePage(api: widget.api)),
        );
        if (applied == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave request submitted successfully.'),
              backgroundColor: Color(0xFF1B7F56),
            ),
          );
          load();
        }
      },
      icon: const Icon(Icons.add, size: 16),
      label: const Text(
        'Apply for leave',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildBalanceCard(Json item) {
    final type = item['leaveType'] is Map ? item['leaveType'] as Map : item;
    final name = (item['name'] ?? type['name'] ?? 'Leave').toString();
    final color = _parseColor(item['color'] ?? type['color']);
    final isPaid =
        item['paid'] == true ||
        item['isPaid'] == true ||
        type['isPaid'] == true;
    final available = _num(item['available']);
    final balance = _num(item['balance']);
    final pending = _num(item['pending'] ?? item['reserved']);
    final used = _num(item['used']);
    final carried = _num(item['carried_forward'] ?? item['carriedForward']);
    final allowNegative =
        item['allow_negative'] == true || item['allowNegativeBalance'] == true;
    final negativeLimit = _num(
      item['negative_limit'] ?? item['negativeBalanceLimit'],
    );

    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFE8DE), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF1E242B),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isPaid)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4EFEB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Unpaid',
                    style: TextStyle(
                      color: Color(0xFF8C7B70),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _count(available),
                style: const TextStyle(
                  color: Color(0xFF1E242B),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  'available',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF4EFEB)),
          const SizedBox(height: 10),
          _balanceRow('Balance', _count(balance)),
          const SizedBox(height: 4),
          _balanceRow('Pending', _count(pending)),
          const SizedBox(height: 4),
          _balanceRow('Used', _count(used)),
          const SizedBox(height: 4),
          _balanceRow('Carried forward', _count(carried)),
          if (allowNegative && negativeLimit > 0) ...[
            const SizedBox(height: 8),
            Text(
              'May go negative up to ${_count(negativeLimit)} days',
              style: const TextStyle(
                color: Color(0xFF8C7B70),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E242B),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    Color dot;
    String label = status;

    if (s == 'pending') {
      bg = const Color(0xFFFBF1D8);
      fg = const Color(0xFF926315);
      dot = const Color(0xFFD97706);
      label = 'Pending';
    } else if (s == 'approved') {
      bg = const Color(0xFFE7F6ED);
      fg = const Color(0xFF1D7C4D);
      dot = const Color(0xFF16A34A);
      label = 'Approved';
    } else if (s == 'rejected') {
      bg = const Color(0xFFFDECEC);
      fg = const Color(0xFFB91C1C);
      dot = const Color(0xFFDC2626);
      label = 'Rejected';
    } else if (s == 'withdrawn') {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      dot = const Color(0xFF94A3B8);
      label = 'Withdrawn';
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      dot = const Color(0xFF94A3B8);
      label = status.isNotEmpty ? status : 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterDropdown() {
    const statuses = [
      'All',
      'Pending',
      'Approved',
      'Rejected',
      'Cancelled',
      'Withdrawn',
    ];
    return PopupMenuButton<String>(
      initialValue: _statusFilter,
      onSelected: (status) {
        setState(() => _statusFilter = status);
      },
      itemBuilder: (context) {
        return statuses.map((s) {
          return PopupMenuItem<String>(
            value: s,
            child: Text(
              s,
              style: TextStyle(
                fontWeight: s == _statusFilter
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: const Color(0xFF1E242B),
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF5EFEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5DFD7), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusFilter == 'All' ? 'By Status' : _statusFilter,
              style: const TextStyle(
                color: Color(0xFF59534E),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Json req) {
    final type = req['leaveType'] is Map ? req['leaveType'] as Map : req;
    final typeName = (req['type_name'] ?? type['name'] ?? 'Leave').toString();
    final typeColor = _parseColor(req['type_color'] ?? type['color']);
    final status = (req['status'] ?? 'Pending').toString();
    final days = req['days'] ?? 1;
    final start = req['start'] ?? req['startDate'];
    final end = req['end'] ?? req['endDate'];
    final decidedBy = req['approver_name'] ?? req['decidedBy'] ?? '';
    final applied = _formatDate(req['created'] ?? req['createdAt']);
    final isPending = status.toLowerCase() == 'pending';
    final isApproved = status.toLowerCase() == 'approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFE8DE), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (req['id'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeaveDetailsPage(
                    api: widget.api,
                    id: req['id'].toString(),
                  ),
                ),
              ).then((_) => load());
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              typeName,
                              style: const TextStyle(
                                color: Color(0xFF1E242B),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatDateRange(start?.toString(), end?.toString()),
                        style: const TextStyle(
                          color: Color(0xFF1E242B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EFEB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$days ${days == 1 ? 'day' : 'days'}',
                        style: const TextStyle(
                          color: Color(0xFF59534E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF4EFEB),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Decided by: ${decidedBy.toString().isNotEmpty ? decidedBy : '—'}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Applied: $applied',
                            style: const TextStyle(
                              color: Color(0xFF8C7B70),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPending && req['id'] != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFBA4728),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _handleWithdraw(req['id'].toString()),
                        child: const Text(
                          'Withdraw',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (isApproved && req['id'] != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _handleCancel(req['id'].toString()),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalancesSection(List<Json> bs) {
    if (bs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: const Text(
          'No leave allocation for this year.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < bs.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _buildBalanceCard(bs[i])),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < bs.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                _buildBalanceCard(bs[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestsSection() {
    final filtered = _filteredRequests;
    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 38,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 8),
            Text(
              _statusFilter == 'All'
                  ? 'No leave requests submitted yet.'
                  : 'No $_statusFilter requests found.',
              style: const TextStyle(
                color: Color(0xFF1E242B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your applied leaves will appear here.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return Column(children: filtered.map(_buildRequestCard).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (error != null && balances == null) return FailureView(error!, load);
    if (balances == null && loading) return const DashboardShimmer();
    final bs = items(balances);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          color: const Color(0xFFBA4728),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Segmented Tab Bar at top
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildTopTabs(),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedTab == 0) ...[
                // Card 1: My balances
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEFE8DE),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My balances',
                        style: TextStyle(
                          color: Color(0xFF1E242B),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Computed from the leave ledger: grants, accruals, carry-forward, adjustments and usage.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildYearSelector(),
                          const SizedBox(width: 8),
                          Flexible(child: _buildApplyButton()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildBalancesSection(bs),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Card 2: My requests (Card View)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEFE8DE),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'My requests',
                              style: TextStyle(
                                color: Color(0xFF1E242B),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusFilterDropdown(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRequestsSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Card 3: Leave calendar
                //   Container(
                //     width: double.infinity,
                //     padding: const EdgeInsets.all(16),
                //     decoration: BoxDecoration(
                //       color: Colors.white,
                //       borderRadius: BorderRadius.circular(16),
                //       border: Border.all(
                //         color: const Color(0xFFEFE8DE),
                //         width: 1,
                //       ),
                //     ),
                //     child: _LeaveCalendar(api: widget.api),
                //   ),
                // ] else ...[
                //   // Calendar tab view
                //   Container(
                //     width: double.infinity,
                //     padding: const EdgeInsets.all(16),
                //     decoration: BoxDecoration(
                //       color: Colors.white,
                //       borderRadius: BorderRadius.circular(16),
                //       border: Border.all(
                //         color: const Color(0xFFEFE8DE),
                //         width: 1,
                //       ),
                //     ),
                //     child: _LeaveCalendar(api: widget.api),
                //   ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Month view of approved and pending leave plus company holidays.
class _LeaveCalendar extends StatefulWidget {
  final Api api;
  const _LeaveCalendar({required this.api});

  @override
  State<_LeaveCalendar> createState() => _LeaveCalendarState();
}

class _LeaveCalendarState extends State<_LeaveCalendar> {
  static const _ink = Color(0xFF1B2A4A);
  static const _soft = Color(0xFF8B93A7);
  static const _amber = Color(0xFFE0A100);
  static const _holiday = Color(0xFFE07A5F);
  static const _months = [
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
  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  late DateTime month;
  late DateTime selected;
  List<Json>? remoteLeaves;
  List<Json> holidays = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
    selected = DateTime(now.year, now.month, now.day);
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1, 0);
    List<Json>? leaves;
    var days = <Json>[];
    try {
      final result = await widget.api.get(
        '/leave-requests/calendar',
        query: {'from': dateOnly(from), 'to': dateOnly(to)},
      );
      if (result['leaves'] is List) {
        leaves = _rows(result['leaves']);
        days = _rows(result['holidays']);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      remoteLeaves = leaves;
      holidays = days;
      loading = false;
    });
  }

  List<Json> get leaves => remoteLeaves ?? const [];

  Set<int> get workWeek {
    final list = widget.api.profile?['work_week'];
    if (list is List && list.isNotEmpty) {
      return list.map((d) => (d as num).toInt()).toSet();
    }
    return {1, 2, 3, 4, 5};
  }

  List<Json> leavesOn(DateTime day) {
    if (!workWeek.contains(day.weekday)) return const [];
    final key = dateOnly(day);
    return leaves
        .where(
          (row) =>
              row['start'].toString().compareTo(key) <= 0 &&
              row['end'].toString().compareTo(key) >= 0,
        )
        .toList();
  }

  Json? holidayOn(DateTime day) {
    final key = dateOnly(day);
    for (final row in holidays) {
      if (row['date'] == key) return row;
    }
    return null;
  }

  void shift(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      selected = DateTime(month.year, month.month, 1);
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7;
    final cells = ((offset + count) / 7).ceil() * 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var approved = 0, pending = 0;
    for (var d = 1; d <= count; d++) {
      final rows = leavesOn(DateTime(month.year, month.month, d));
      if (rows.any((r) => r['status'] == 'Approved')) approved++;
      if (rows.any((r) => r['status'] == 'Pending')) pending++;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F6EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_note_outlined,
                    color: primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave calendar',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$approved approved · $pending pending · ${holidays.length} holiday${holidays.length == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _soft, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: const Color(0xFFF3F5F7),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeaveCalendarPage(
                          api: widget.api,
                          initialMonth: month,
                          initialDate: selected,
                        ),
                      ),
                    ).then((_) => load()),
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        color: Color(0xFF1B7F56),
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => shift(-1),
                    icon: const Icon(Icons.chevron_left_rounded, color: _ink),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[month.month - 1]} ${month.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => shift(1),
                    icon: const Icon(Icons.chevron_right_rounded, color: _ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Text(
                      _weekdays[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: workWeek.contains(i == 0 ? 7 : i)
                            ? _soft
                            : _soft.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: loading ? 0.45 : 1,
              child: Column(
                children: [
                  for (var row = 0; row < cells ~/ 7; row++)
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(
                            child: _cell(
                              row * 7 + col - offset + 1,
                              count,
                              today,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _CalendarKey(color: primary, label: 'Approved', filled: true),
                _CalendarKey(color: _amber, label: 'Pending', filled: false),
                _CalendarKey(color: _holiday, label: 'Holiday', filled: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int date, int count, DateTime today) {
    if (date < 1 || date > count) return const SizedBox(height: 44);
    final day = DateTime(month.year, month.month, date);
    final rows = leavesOn(day);
    final holiday = holidayOn(day);
    final approved = rows.where((r) => r['status'] == 'Approved').toList();
    final waiting = rows.any((r) => r['status'] == 'Pending');
    final isSelected = day == selected;
    final isToday = day == today;
    final weekend = !workWeek.contains(day.weekday);
    final tone = approved.isNotEmpty
        ? _hex(approved.first['color']) ?? primary
        : null;
    Color? fill;
    Color text = weekend ? _soft : _ink;
    Border? border;
    if (tone != null) {
      fill = tone.withValues(alpha: 0.16);
      text = tone;
    } else if (waiting) {
      fill = _amber.withValues(alpha: 0.08);
      border = Border.all(color: _amber, width: 1.4);
      text = const Color(0xFFB07D00);
    } else if (holiday != null) {
      fill = _holiday.withValues(alpha: 0.14);
      text = _holiday;
    }
    if (isSelected) {
      fill = _ink;
      text = Colors.white;
      border = null;
    } else if (isToday && border == null) {
      border = Border.all(color: _ink, width: 1.4);
    }
    final others = rows.where((r) => r['own'] != true).length;
    return GestureDetector(
      onTap: () => setState(() => selected = day),
      child: SizedBox(
        height: 44,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: border,
                ),
                child: Text(
                  '$date',
                  style: TextStyle(
                    color: text,
                    fontWeight: tone != null || waiting || isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (others > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C6BF2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$others',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarKey extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;
  const _CalendarKey({
    required this.color,
    required this.label,
    required this.filled,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color.withValues(alpha: 0.3) : null,
          border: Border.all(color: color, width: 1.4),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF6E7C8A), fontSize: 11.5),
      ),
    ],
  );
}

/// Dedicated full-screen calendar view for leaves and company holidays.
class LeaveCalendarPage extends StatefulWidget {
  final Api api;
  final DateTime? initialMonth;
  final DateTime? initialDate;
  const LeaveCalendarPage({
    super.key,
    required this.api,
    this.initialMonth,
    this.initialDate,
  });

  @override
  State<LeaveCalendarPage> createState() => _LeaveCalendarPageState();
}

class _LeaveCalendarPageState extends State<LeaveCalendarPage> {
  static const _ink = Color(0xFF1B2A4A);
  static const _soft = Color(0xFF8B93A7);
  static const _amber = Color(0xFFE0A100);
  static const _holiday = Color(0xFFE07A5F);
  static const _months = [
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
  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  late DateTime month;
  late DateTime selected;
  List<Json>? remoteLeaves;
  List<Json> holidays = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = widget.initialMonth ?? DateTime(now.year, now.month);
    selected = widget.initialDate ?? DateTime(now.year, now.month, now.day);
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);
    try {
      final result = await widget.api.get(
        '/leave-requests/calendar',
        query: {'from': dateOnly(from), 'to': dateOnly(to)},
      );
      if (!mounted) return;
      setState(() {
        if (result['leaves'] is List) {
          remoteLeaves = _rows(result['leaves']);
          holidays = _rows(result['holidays']);
        }
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  List<Json> get leaves => remoteLeaves ?? const [];

  Set<int> get workWeek {
    final list = widget.api.profile?['work_week'];
    if (list is List && list.isNotEmpty) {
      return list.map((d) => (d as num).toInt()).toSet();
    }
    return {1, 2, 3, 4, 5};
  }

  List<Json> leavesOn(DateTime day) {
    final key = dateOnly(day);
    return leaves
        .where(
          (row) =>
              (row['start'] ?? row['startDate']).toString().compareTo(key) <=
                  0 &&
              (row['end'] ?? row['endDate']).toString().compareTo(key) >= 0,
        )
        .toList();
  }

  Json? holidayOn(DateTime day) {
    final key = dateOnly(day);
    for (final row in holidays) {
      if (row['date'] == key) return row;
    }
    return null;
  }

  void shift(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      selected = DateTime(month.year, month.month, 1);
    });
    load();
  }

  void goToToday() {
    final now = DateTime.now();
    setState(() {
      month = DateTime(now.year, now.month);
      selected = DateTime(now.year, now.month, now.day);
    });
    load();
  }

  List<Json> get monthEvents {
    final list = <Json>[];
    for (final h in holidays) {
      list.add({
        'kind': 'holiday',
        'date': h['date'],
        'title': h['name'] ?? 'Holiday',
        'subtitle': h['optional'] == true
            ? 'Optional holiday'
            : 'Company holiday',
        'raw': h,
      });
    }
    for (final l in leaves) {
      final status = (l['status'] ?? 'Pending').toString();
      final type = l['type'] ?? l['type_name'] ?? 'Leave';
      final name = l['name'] ?? l['employee_name'] ?? '';
      final session = switch (l['session']) {
        'FIRST_HALF' => 'First half',
        'SECOND_HALF' => 'Second half',
        _ => 'Full day',
      };
      final reason = (l['reason'] ?? '').toString();
      list.add({
        'kind': 'leave',
        'date': l['start'] ?? l['startDate'],
        'title': name.isNotEmpty ? '$name · $type' : type,
        'subtitle':
            '$session • ${l['days'] ?? 1} day(s)${reason.isNotEmpty ? ' • $reason' : ''}',
        'status': status,
        'color': l['color'],
        'raw': l,
      });
    }
    list.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7;
    final cells = ((offset + count) / 7).ceil() * 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var approved = 0, pending = 0;
    for (var d = 1; d <= count; d++) {
      final rows = leavesOn(DateTime(month.year, month.month, d));
      if (rows.any((r) => r['status'] == 'Approved')) approved++;
      if (rows.any((r) => r['status'] == 'Pending')) pending++;
    }

    final events = monthEvents;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _ink,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave & Holiday Calendar',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            Text(
              '${_months[month.month - 1]} ${month.year}',
              style: const TextStyle(
                color: primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: primary,
                backgroundColor: const Color(0xFFE7F6EE),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.today_rounded, size: 15),
              label: const Text(
                'Today',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              onPressed: goToToday,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            // Month Highlights Cards
            Row(
              children: [
                Expanded(
                  child: _highlightCard(
                    title: 'Approved',
                    count: '$approved',
                    color: primary,
                    bg: const Color(0xFFE7F6EE),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _highlightCard(
                    title: 'Pending',
                    count: '$pending',
                    color: _amber,
                    bg: const Color(0xFFFFF6E0),
                    icon: Icons.schedule_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _highlightCard(
                    title: 'Holidays',
                    count: '${holidays.length}',
                    color: _holiday,
                    bg: const Color(0xFFFDECEC),
                    icon: Icons.celebration_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Month Navigator Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8EDF2)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => shift(-1),
                    icon: const Icon(Icons.chevron_left_rounded, color: _ink),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[month.month - 1]} ${month.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => shift(1),
                    icon: const Icon(Icons.chevron_right_rounded, color: _ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Full Calendar Grid Card
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE8EDF2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Text(
                              _weekdays[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: workWeek.contains(i == 0 ? 7 : i)
                                    ? _soft
                                    : _soft.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: loading ? 0.45 : 1,
                      child: Column(
                        children: [
                          for (var row = 0; row < cells ~/ 7; row++)
                            Row(
                              children: [
                                for (var col = 0; col < 7; col++)
                                  Expanded(
                                    child: _cell(
                                      row * 7 + col - offset + 1,
                                      count,
                                      today,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _CalendarKey(
                          color: primary,
                          label: 'Approved',
                          filled: true,
                        ),
                        _CalendarKey(
                          color: _amber,
                          label: 'Pending',
                          filled: false,
                        ),
                        _CalendarKey(
                          color: _holiday,
                          label: 'Holiday',
                          filled: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Day Detail Card
            _dayDetailCard(),
            const SizedBox(height: 16),

            // Month Agenda Section (All Events in Month)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EDF2)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F6EE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: primary,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Schedule for ${_months[month.month - 1]}',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        '${events.length} event${events.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: _soft,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'No leaves or company holidays scheduled this month.',
                          style: TextStyle(color: _soft, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    for (final ev in events) ...[
                      _monthEventRow(ev),
                      if (ev != events.last)
                        const Divider(height: 16, color: Color(0xFFF1F3F5)),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Apply for leave button
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApplyLeavePage(api: widget.api),
                  ),
                );
                load();
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Apply for leave',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightCard({
    required String title,
    required String count,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int date, int count, DateTime today) {
    if (date < 1 || date > count) return const SizedBox(height: 48);
    final day = DateTime(month.year, month.month, date);
    final rows = leavesOn(day);
    final holiday = holidayOn(day);
    final approved = rows.where((r) => r['status'] == 'Approved').toList();
    final waiting = rows.any((r) => r['status'] == 'Pending');
    final isSelected = day == selected;
    final isToday = day == today;
    final weekend = !workWeek.contains(day.weekday);
    final tone = approved.isNotEmpty
        ? _hex(approved.first['color']) ?? primary
        : null;

    Color? fill;
    Color text = weekend ? _soft : _ink;
    Border? border;

    if (tone != null) {
      fill = tone.withValues(alpha: 0.16);
      text = tone;
    } else if (waiting) {
      fill = _amber.withValues(alpha: 0.08);
      border = Border.all(color: _amber, width: 1.4);
      text = const Color(0xFFB07D00);
    } else if (holiday != null) {
      fill = _holiday.withValues(alpha: 0.14);
      text = _holiday;
    }

    if (isSelected) {
      fill = _ink;
      text = Colors.white;
      border = null;
    } else if (isToday && border == null) {
      border = Border.all(color: _ink, width: 1.4);
    }

    return GestureDetector(
      onTap: () => setState(() => selected = day),
      child: SizedBox(
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: border,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$date',
                  style: TextStyle(
                    color: text,
                    fontWeight: tone != null || waiting || isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (!isSelected && (holiday != null || rows.isNotEmpty))
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (holiday != null)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: const BoxDecoration(
                            color: _holiday,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (approved.isNotEmpty)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: const BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (waiting)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: const BoxDecoration(
                            color: _amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayDetailCard() {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final rows = leavesOn(selected);
    final holiday = holidayOn(selected);
    final isWeekend = !workWeek.contains(selected.weekday);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selected.day} ${_months[selected.month - 1].substring(0, 3)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dayNames[selected.weekday - 1]}, ${selected.day} ${_months[selected.month - 1]} ${selected.year}',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      isWeekend
                          ? 'Weekend • Non-working day'
                          : 'Scheduled working day',
                      style: const TextStyle(color: _soft, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (holiday != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCDFD8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: _holiday,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          holiday['name'].toString(),
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          holiday['optional'] == true
                              ? 'Optional holiday'
                              : 'Company holiday • Paid non-working day',
                          style: const TextStyle(
                            color: _holiday,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (final row in rows) ...[
            _leaveDetailCard(row),
            const SizedBox(height: 10),
          ],
          if (holiday == null && rows.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isWeekend
                        ? Icons.weekend_outlined
                        : Icons.work_outline_rounded,
                    color: _soft,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isWeekend
                          ? 'Weekend — No shifts scheduled.'
                          : 'A regular working day. No leave or holiday.',
                      style: const TextStyle(color: _soft, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _leaveDetailCard(Json row) {
    final status = row['status']?.toString() ?? 'Pending';
    final isApproved = status == 'Approved';
    final statusColor = isApproved ? primary : _amber;
    final statusBg = isApproved
        ? const Color(0xFFE7F6EE)
        : const Color(0xFFFFF6E0);
    final typeColor = _hex(row['color']) ?? const Color(0xFF3B82F6);
    final name = (row['name'] ?? row['employee_name'] ?? '').toString();
    final reason = (row['reason'] ?? '').toString();
    final session = switch (row['session']) {
      'FIRST_HALF' => 'First half',
      'SECOND_HALF' => 'Second half',
      _ => 'Full day',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row['type']?.toString() ?? 'Leave',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (name.isNotEmpty) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                if ((row['employee_code'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${row['employee_code']})',
                    style: const TextStyle(color: _soft, fontSize: 11.5),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: _soft),
              const SizedBox(width: 5),
              Text(
                '$session • ${row['days'] ?? 1} day(s)',
                style: const TextStyle(color: _soft, fontSize: 12),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes_rounded, size: 13, color: _soft),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
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

  Widget _monthEventRow(Json ev) {
    final isHoliday = ev['kind'] == 'holiday';
    final dateStr = ev['date']?.toString() ?? '';
    final parsed = DateTime.tryParse(dateStr);
    final isSelected =
        parsed != null &&
        parsed.year == selected.year &&
        parsed.month == selected.month &&
        parsed.day == selected.day;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (parsed != null) {
          setState(() {
            selected = DateTime(parsed.year, parsed.month, parsed.day);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE7F6EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isHoliday
                    ? const Color(0xFFFDECEC)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isHoliday
                    ? Icons.celebration_outlined
                    : Icons.event_note_outlined,
                color: isHoliday ? _holiday : const Color(0xFF3B82F6),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ev['title'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${parsed != null ? '${parsed.day} ${_months[parsed.month - 1].substring(0, 3)} • ' : ''}${ev['subtitle']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _soft, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (ev['status'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ev['status'] == 'Approved'
                      ? const Color(0xFFE7F6EE)
                      : const Color(0xFFFFF6E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ev['status'].toString(),
                  style: TextStyle(
                    color: ev['status'] == 'Approved' ? primary : _amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<Json> _rows(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Json>[];

Color? _hex(Object? value) {
  final text = value?.toString().replaceFirst('#', '') ?? '';
  if (text.length != 6) return null;
  final parsed = int.tryParse(text, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

num _num(dynamic value) => value is num ? value : 0;

String _count(num value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

class LeaveDetailsPage extends StatefulWidget {
  final Api api;
  final String id;
  const LeaveDetailsPage({super.key, required this.api, required this.id});
  @override
  State<LeaveDetailsPage> createState() => _LeaveDetailsPageState();
}

class _LeaveDetailsPageState extends State<LeaveDetailsPage> {
  Json? request;
  Object? error;
  bool busy = false;
  bool isWithdrawing = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = await widget.api.get('/leave-requests/${widget.id}');
      if (mounted) {
        setState(() {
          request = res['data'] is Map
              ? Map<String, dynamic>.from(res['data'] as Map)
              : res;
          busy = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          busy = false;
        });
      }
    }
  }

  Future<void> _showWithdrawDialog() async {
    final reasonController = TextEditingController();
    String? validationError;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Withdraw this request?',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E242B),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: Color(0xFF6B7280),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEFE8DE),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'The request will no longer be reviewed.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      const TextSpan(
                        text: 'Reason',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E242B),
                        ),
                        children: [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 4,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF1E242B),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter reason for withdrawal...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5DFD7),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: validationError != null
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFE5DFD7),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: validationError != null
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFBA4728),
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (validationError != null) {
                          setDialogState(() => validationError = null);
                        }
                      },
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        validationError!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E242B),
                            side: const BorderSide(color: Color(0xFFE5DFD7)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            backgroundColor: const Color(0xFFB91C1C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final text = reasonController.text.trim();
                            if (text.isEmpty) {
                              setDialogState(() {
                                validationError =
                                    'Reason is mandatory to cancel leave';
                              });
                              return;
                            }
                            Navigator.pop(dialogCtx, true);
                          },
                          child: const Text(
                            'Withdraw',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final reason = reasonController.text.trim();
      reasonController.dispose();
      await _executeWithdraw(reason);
    } else {
      reasonController.dispose();
    }
  }

  Future<void> _executeWithdraw(String reason) async {
    setState(() => isWithdrawing = true);
    try {
      await widget.api.mutate('/leave-requests/${widget.id}/cancel', {
        'reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request withdrawn successfully.'),
            backgroundColor: Color(0xFF1B7F56),
          ),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        final msg = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('ApiFailure: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.isEmpty ? 'Failed to withdraw leave request.' : msg,
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isWithdrawing = false);
    }
  }

  Future<void> _openAttachment(String attachmentId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFBA4728)),
        ),
      );

      final res = await widget.api.call('GET', '/files/$attachmentId/url');
      if (mounted) Navigator.pop(context);

      final data = res['data'] is Map ? (res['data'] as Map) : res;
      final rawUrl = data['url']?.toString() ?? '';
      final name = data['name']?.toString() ?? 'Document';
      final mimeType = data['mimeType']?.toString().toLowerCase() ?? '';

      if (rawUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document URL is not available.')),
          );
        }
        return;
      }

      final fullUrl = rawUrl.startsWith('http')
          ? rawUrl
          : 'https://hrms-demo-api.giraffai.in$rawUrl';

      if (!mounted) return;

      final isImage =
          mimeType.startsWith('image/') ||
          fullUrl.contains('.png') ||
          fullUrl.contains('.jpg') ||
          fullUrl.contains('.jpeg') ||
          fullUrl.contains('.webp');

      showDialog(
        context: context,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 20,
                      color: Color(0xFF1E242B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E242B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEFE8DE)),
              if (isImage)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 450),
                  child: InteractiveViewer(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.network(
                        fullUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                color: Color(0xFFBA4728),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: Color(0xFF9CA3AF),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Failed to preview image',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 56,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mimeType,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        foregroundColor: const Color(0xFF1E242B),
                        side: const BorderSide(color: Color(0xFFE5DFD7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attachment: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  String _formatHeaderDate(dynamic startRaw, dynamic endRaw) {
    if (startRaw == null) return '';
    final s = DateTime.tryParse(startRaw.toString());
    if (s == null) return startRaw.toString();
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
    if (endRaw == null || endRaw == startRaw) {
      return '${s.day} ${months[s.month - 1]} ${s.year}';
    }
    final e = DateTime.tryParse(endRaw.toString());
    if (e == null ||
        (s.year == e.year && s.month == e.month && s.day == e.day)) {
      return '${s.day} ${months[s.month - 1]} ${s.year}';
    }
    return '${s.day} ${months[s.month - 1]} – ${e.day} ${months[e.month - 1]} ${e.year}';
  }

  String _formatDatesRow(dynamic startRaw, dynamic endRaw, String? session) {
    if (startRaw == null) return '';
    final s = DateTime.tryParse(startRaw.toString());
    if (s == null) return startRaw.toString();
    const daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final sessionText = switch (session?.toUpperCase()) {
      'FIRST_HALF' => 'First half',
      'SECOND_HALF' => 'Second half',
      _ => 'Full day',
    };
    if (endRaw == null || endRaw == startRaw) {
      return '${daysOfWeek[s.weekday - 1]}, ${s.day} ${months[s.month - 1]} ${s.year} · $sessionText';
    }
    final e = DateTime.tryParse(endRaw.toString());
    if (e == null ||
        (s.year == e.year && s.month == e.month && s.day == e.day)) {
      return '${daysOfWeek[s.weekday - 1]}, ${s.day} ${months[s.month - 1]} ${s.year} · $sessionText';
    }
    return '${s.day} ${months[s.month - 1]} – ${e.day} ${months[e.month - 1]} ${e.year} · $sessionText';
  }

  String _formatDateTime(dynamic iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso.toString())?.toLocal();
    if (dt == null) return iso.toString();
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
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _capitalizeAction(String action) {
    final a = action.trim().toLowerCase();
    return switch (a) {
      'submitted' => 'Submitted',
      'withdrawn' => 'Withdrawn',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ =>
        action.isEmpty
            ? 'Action'
            : '${action[0].toUpperCase()}${action.substring(1).toLowerCase()}',
    };
  }

  Widget _buildStatusBadge(String status) {
    final s = status.trim().toUpperCase();
    Color bg;
    Color fg;
    Color dot;
    String label;

    switch (s) {
      case 'APPROVED':
        bg = const Color(0xFFE7F6ED);
        fg = const Color(0xFF1D7C4D);
        dot = const Color(0xFF16A34A);
        label = 'Approved';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFDECEC);
        fg = const Color(0xFFB91C1C);
        dot = const Color(0xFFDC2626);
        label = 'Rejected';
        break;
      case 'WITHDRAWN':
      case 'CANCELLED':
        bg = const Color(0xFFF5EFEB);
        fg = const Color(0xFF6B7280);
        dot = const Color(0xFF8C7B70);
        label = 'Withdrawn';
        break;
      case 'PENDING':
      default:
        bg = const Color(0xFFFBF1D8);
        fg = const Color(0xFF926315);
        dot = const Color(0xFFD97706);
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required Widget child,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 105,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFEFE8DE)),
      ],
    );
  }

  Widget _buildHistoryItem({
    required String action,
    required String at,
    required String actor,
    String? comment,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFBA4728),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE5DFD7),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E242B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$at · $actor',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  if (comment != null && comment.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '“$comment”',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E242B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCFAF6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFCFAF6),
          surfaceTintColor: const Color(0xFFFCFAF6),
          title: const Text('Leave Details'),
        ),
        body: FailureView(error!, load),
      );
    }

    final d = request;
    if (d == null || (busy && request == null)) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCFAF6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFCFAF6),
          surfaceTintColor: const Color(0xFFFCFAF6),
          title: const Text('Leave Details'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFBA4728)),
        ),
      );
    }

    final emp = d['employee'] is Map
        ? (d['employee'] as Map)
        : <String, dynamic>{};
    final empName =
        (d['employee_name'] ?? emp['fullName'] ?? emp['name'] ?? 'Employee')
            .toString();
    final empCode = (d['code'] ?? emp['employeeCode'] ?? '').toString();
    final empDesig =
        (d['designation'] ?? emp['designation'] ?? emp['department'] ?? '')
            .toString();

    final lt = d['leaveType'] is Map
        ? (d['leaveType'] as Map)
        : <String, dynamic>{};
    final ltName = (d['type_name'] ?? lt['name'] ?? d['name'] ?? 'Leave')
        .toString();

    final startDate = d['startDate'] ?? d['start'];
    final endDate = d['endDate'] ?? d['end'];
    final session = (d['startSession'] ?? d['session'] ?? 'FULL').toString();
    final days = _num(d['days'] ?? 1);
    final reason = d['reason']?.toString() ?? '';
    final attachmentId = (d['attachmentId'] ?? d['attachment_id'])?.toString();
    final createdAt = d['createdAt'] ?? d['created'];
    final status = (d['status'] ?? 'PENDING').toString();
    final isPending = status.toUpperCase() == 'PENDING';

    final historyList =
        (d['history'] is List
                ? (d['history'] as List)
                : (d['events'] is List ? (d['events'] as List) : const []))
            .cast<dynamic>();

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFAF6),
        surfaceTintColor: const Color(0xFFFCFAF6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E242B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isPending)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: busy || isWithdrawing ? null : _showWithdrawDialog,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                ),
                child: isWithdrawing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFB91C1C),
                        ),
                      )
                    : const Text(
                        'Withdraw',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          final detailsCard = Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEFE8DE)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E242B),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFEFE8DE),
                ),
                _buildDetailRow(
                  label: 'Employee',
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFBA4728),
                        child: Text(
                          _initials(empName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              empName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E242B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (empCode.isNotEmpty) empCode,
                                if (empDesig.isNotEmpty) empDesig,
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDetailRow(
                  label: 'Leave type',
                  child: Text(
                    ltName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E242B),
                    ),
                  ),
                ),
                _buildDetailRow(
                  label: 'Dates',
                  child: Text(
                    _formatDatesRow(startDate, endDate, session),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E242B),
                    ),
                  ),
                ),
                _buildDetailRow(
                  label: 'Duration',
                  child: Text(
                    '${_count(days)} day${days == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E242B),
                    ),
                  ),
                ),
                _buildDetailRow(
                  label: 'Reason',
                  child: Text(
                    reason.isEmpty ? '—' : reason,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF1E242B),
                    ),
                  ),
                ),
                _buildDetailRow(
                  label: 'Attachment',
                  child: (attachmentId != null && attachmentId.isNotEmpty)
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1E242B),
                              side: const BorderSide(color: Color(0xFFE5DFD7)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () => _openAttachment(attachmentId),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.attach_file_rounded,
                                  size: 16,
                                  color: Color(0xFF1E242B),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Open document',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E242B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Text(
                          '—',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                ),
                _buildDetailRow(
                  label: 'Applied',
                  showDivider: false,
                  child: Text(
                    _formatDateTime(createdAt),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF1E242B),
                    ),
                  ),
                ),
              ],
            ),
          );

          final historyCard = Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEFE8DE)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E242B),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFEFE8DE),
                ),
                const SizedBox(height: 16),
                if (historyList.isEmpty)
                  const Text(
                    'No history available',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  )
                else
                  for (var i = 0; i < historyList.length; i++) ...[
                    () {
                      final item = historyList[i] is Map
                          ? (historyList[i] as Map)
                          : <String, dynamic>{};
                      final action = _capitalizeAction(
                        (item['action'] ?? '').toString(),
                      );
                      final at = _formatDateTime(item['at'] ?? item['created']);
                      final byName = (item['byName'] ?? item['actor'] ?? '')
                          .toString();
                      final isSelf =
                          item['byEmployeeId']?.toString() ==
                              emp['id']?.toString() ||
                          byName == empName;
                      final actor = isSelf
                          ? 'You'
                          : (byName.isNotEmpty ? byName : 'Manager');
                      final comment =
                          (item['comment'] ??
                                  item['remarks'] ??
                                  item['decisionComment'])
                              ?.toString();
                      final isLast = i == historyList.length - 1;

                      return _buildHistoryItem(
                        action: action,
                        at: at,
                        actor: actor,
                        comment: comment,
                        isLast: isLast,
                      );
                    }(),
                  ],
              ],
            ),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const Text(
                'Leave / My request',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    '$ltName request',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E242B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatHeaderDate(startDate, endDate)} · ${_count(days)} day${days == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              if (isPending) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: busy || isWithdrawing
                        ? null
                        : _showWithdrawDialog,
                    icon: isWithdrawing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFB91C1C),
                            ),
                          )
                        : const Icon(
                            Icons.cancel_outlined,
                            size: 16,
                            color: Color(0xFFB91C1C),
                          ),
                    label: const Text(
                      'Withdraw request',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: detailsCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: historyCard),
                  ],
                )
              else ...[
                detailsCard,
                const SizedBox(height: 20),
                historyCard,
              ],
            ],
          );
        },
      ),
    );
  }
}

class ApplyLeavePage extends StatefulWidget {
  final Api api;
  const ApplyLeavePage({super.key, required this.api});
  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();
  String session = 'FULL'; // 'FULL', 'FIRST_HALF', 'SECOND_HALF'
  List<Json>? balances;
  String? selectedTypeId;
  final TextEditingController reasonController = TextEditingController();
  String? attachmentName;
  List<int>? attachmentBytes;

  bool loadingBalances = true;
  bool previewLoading = false;
  Json? previewData;
  String? previewError;
  bool isSubmitting = false;
  int _previewRequestId = 0;

  @override
  void initState() {
    super.initState();
    reasonController.addListener(() {
      if (mounted) setState(() {});
    });
    loadBalances();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  Future<void> loadBalances() async {
    setState(() => loadingBalances = true);
    try {
      final r = await widget.api.get(
        '/leave-balances/me',
        query: {'year': '${startDate.year}'},
      );
      final raw = items(r);
      if (mounted) {
        setState(() {
          balances = raw;
          if (balances != null && balances!.isNotEmpty) {
            final first = balances!.first;
            final type = first['leaveType'] is Map
                ? first['leaveType'] as Map
                : first;
            selectedTypeId = (first['type_id'] ?? first['id'] ?? type['id'])
                ?.toString();
          }
          loadingBalances = false;
        });
        _fetchPreview();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingBalances = false;
          previewError = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('ApiFailure: ', '');
        });
      }
    }
  }

  Json? get selectedBalance {
    if (balances == null || selectedTypeId == null) return null;
    for (final b in balances!) {
      final type = b['leaveType'] is Map ? b['leaveType'] as Map : b;
      final id = (b['type_id'] ?? b['id'] ?? type['id'])?.toString();
      if (id == selectedTypeId) return b;
    }
    return null;
  }

  Future<void> _fetchPreview() async {
    if (selectedTypeId == null) return;
    final requestId = ++_previewRequestId;
    setState(() {
      previewLoading = true;
      previewError = null;
    });

    final payload = {
      'leaveTypeId': selectedTypeId,
      'startDate': dateOnly(startDate),
      'endDate': dateOnly(endDate),
      'startSession': session,
      'endSession': session,
      'reason': reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : 'Preview',
    };

    try {
      final res = await widget.api.call(
        'POST',
        '/leave-requests/preview',
        body: payload,
      );
      if (mounted && requestId == _previewRequestId) {
        setState(() {
          previewData = res;
          previewError = null;
          previewLoading = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _previewRequestId) {
        final rawMsg = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('ApiFailure: ', '');
        setState(() {
          previewData = null;
          previewError = rawMsg;
          previewLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? startDate : endDate;
    final first = isStart ? DateTime(DateTime.now().year - 1) : startDate;
    final last = DateTime(DateTime.now().year + 2, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFBA4728),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E242B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate.isBefore(startDate)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
        }
      });
      _fetchPreview();
    }
  }

  void _chooseLeaveType() {
    if (balances == null || balances!.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5DFD7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Leave Type',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E242B),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: balances!.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF4EFEB)),
                    itemBuilder: (context, index) {
                      final item = balances![index];
                      final type = item['leaveType'] is Map
                          ? item['leaveType'] as Map
                          : item;
                      final id = (item['type_id'] ?? item['id'] ?? type['id'])
                          ?.toString();
                      final name = (item['name'] ?? type['name'] ?? 'Leave')
                          .toString();
                      final available = _num(item['available']);
                      final pending = _num(item['pending'] ?? item['reserved']);
                      final isSelected = id == selectedTypeId;
                      final color = _parseColor(item['color'] ?? type['color']);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          '$name — ${_count(available)} available',
                          style: TextStyle(
                            color: const Color(0xFF1E242B),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14.5,
                          ),
                        ),
                        subtitle: Text(
                          pending > 0
                              ? 'Available: ${_count(available)} day(s) · ${_count(pending)} pending'
                              : 'Available: ${_count(available)} day(s)',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFFBA4728),
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (id != selectedTypeId) {
                            setState(() => selectedTypeId = id);
                            _fetchPreview();
                          }
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

  void _chooseSession() {
    const sessions = [
      ('Full day', 'FULL'),
      ('First half', 'FIRST_HALF'),
      ('Second half', 'SECOND_HALF'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5DFD7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Session',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E242B),
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in sessions)
                  ListTile(
                    title: Text(
                      item.$1,
                      style: TextStyle(
                        fontWeight: item.$2 == session
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: const Color(0xFF1E242B),
                      ),
                    ),
                    trailing: item.$2 == session
                        ? const Icon(
                            Icons.check,
                            color: Color(0xFFBA4728),
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (session != item.$2) {
                        setState(() => session = item.$2);
                        _fetchPreview();
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _chooseDocument() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5DFD7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Attach Supporting Document',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E242B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload a file, photo, or scan (PDF or image up to 10 MB)',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Take Photo (Camera)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E242B),
                  ),
                ),
                subtitle: const Text(
                  'Use camera to capture document',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
                onTap: () => _pickFromCamera(ctx),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF16A34A),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Photo Library / Gallery',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E242B),
                  ),
                ),
                subtitle: const Text(
                  'Select existing photo from gallery',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
                onTap: () => _pickFromGallery(ctx),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    color: Color(0xFFEA580C),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Browse Files & Documents',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E242B),
                  ),
                ),
                subtitle: const Text(
                  'Pick PDF or document from storage',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
                onTap: () => _pickFromFileSystem(ctx),
              ),
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text(
                    'Quick Sample Documents (Demo)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        Icons.picture_as_pdf,
                        color: Color(0xFFBA4728),
                        size: 20,
                      ),
                      title: const Text(
                        'medical_certificate.pdf',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text(
                        'PDF document (245 KB)',
                        style: TextStyle(fontSize: 11),
                      ),
                      onTap: () {
                        setState(() {
                          attachmentName = 'medical_certificate.pdf';
                          attachmentBytes = utf8.encode(
                            'medical_certificate_content',
                          );
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        Icons.image,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                      title: const Text(
                        'doctor_prescription.png',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Image document (512 KB)',
                        style: TextStyle(fontSize: 11),
                      ),
                      onTap: () {
                        setState(() {
                          attachmentName = 'doctor_prescription.png';
                          attachmentBytes = utf8.encode(
                            'doctor_prescription_content',
                          );
                        });
                        Navigator.pop(ctx);
                      },
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

  Future<void> _pickFromCamera(BuildContext ctx) async {
    Navigator.pop(ctx);
    try {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (mounted) {
          _showPermissionDialog(
            'Camera permission is required to capture photos of documents.',
          );
        }
        return;
      }
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (mounted) {
          setState(() {
            attachmentName = photo.name.isNotEmpty
                ? photo.name
                : 'doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
            attachmentBytes = bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera: $e'),
            backgroundColor: const Color(0xFFC24127),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext ctx) async {
    Navigator.pop(ctx);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          setState(() {
            attachmentName = image.name;
            attachmentBytes = bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick from gallery: $e'),
            backgroundColor: const Color(0xFFC24127),
          ),
        );
      }
    }
  }

  Future<void> _pickFromFileSystem(BuildContext ctx) async {
    Navigator.pop(ctx);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        List<int>? bytes = file.bytes;
        final path = file.path;
        if (bytes == null && path != null) {
          bytes = await File(path).readAsBytes();
        }
        if (bytes != null && mounted) {
          setState(() {
            attachmentName = file.name;
            attachmentBytes = bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not select file: $e'),
            backgroundColor: const Color(0xFFC24127),
          ),
        );
      }
    }
  }

  void _showPermissionDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(
          Icons.security_rounded,
          color: Color(0xFFC24127),
          size: 36,
        ),
        title: const Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialog);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    final trimmedReason = reasonController.text.trim();
    if (trimmedReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reason for the leave.'),
          backgroundColor: Color(0xFFC24127),
        ),
      );
      return;
    }
    if (selectedTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a leave type.'),
          backgroundColor: Color(0xFFC24127),
        ),
      );
      return;
    }
    if (previewError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(previewError!),
          backgroundColor: const Color(0xFFC24127),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final body = {
        'leaveTypeId': selectedTypeId,
        'startDate': dateOnly(startDate),
        'endDate': dateOnly(endDate),
        'startSession': session,
        'endSession': session,
        'reason': trimmedReason,
        if (attachmentBytes != null) 'attachmentBytes': attachmentBytes,
        if (attachmentName != null) 'attachmentName': attachmentName,
      };

      await widget.api.mutate('/leave-requests', body);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSubmitting = false);
        final msg = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('ApiFailure: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFC24127),
          ),
        );
      }
    }
  }

  String _formatDdMmYyyy(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _sessionLabel(String s) {
    return switch (s) {
      'FIRST_HALF' => 'First half',
      'SECOND_HALF' => 'Second half',
      _ => 'Full day',
    };
  }

  Widget _previewStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E242B),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBalance = selectedBalance;
    final currentType = currentBalance != null
        ? (currentBalance['leaveType'] is Map
              ? currentBalance['leaveType'] as Map
              : currentBalance)
        : null;
    final currentTypeName =
        (currentBalance?['name'] ?? currentType?['name'] ?? 'Select leave type')
            .toString();
    final currentAvailable = _num(currentBalance?['available']);
    final currentPending = _num(
      currentBalance?['pending'] ?? currentBalance?['reserved'],
    );

    final canSubmit =
        !isSubmitting &&
        previewError == null &&
        previewData != null &&
        reasonController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text(
          'Apply for leave',
          style: TextStyle(
            color: Color(0xFF1E242B),
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF6B7280), size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            const Text(
              'Weekends and holidays are excluded unless the leave policy counts them.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Field 1: Leave type *
            _buildFieldLabel('Leave type'),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _chooseLeaveType,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5DFD7), width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentBalance != null
                            ? '$currentTypeName — ${_count(currentAvailable)} available'
                            : 'Select leave type',
                        style: const TextStyle(
                          color: Color(0xFF1E242B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (currentBalance != null) ...[
              const SizedBox(height: 6),
              Text(
                currentPending > 0
                    ? 'Available: ${_count(currentAvailable)} day(s) · ${_count(currentPending)} pending'
                    : 'Available: ${_count(currentAvailable)} day(s)',
                style: const TextStyle(color: Color(0xFF8C7B70), fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),

            // Fields 2 & 3: Start date * & End date *
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Start date'),
                      const SizedBox(height: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _pickDate(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFE5DFD7),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatDdMmYyyy(startDate),
                                  style: const TextStyle(
                                    color: Color(0xFF1E242B),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: Color(0xFF6B7280),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('End date'),
                      const SizedBox(height: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _pickDate(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFE5DFD7),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatDdMmYyyy(endDate),
                                  style: const TextStyle(
                                    color: Color(0xFF1E242B),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: Color(0xFF6B7280),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Field 4: Session
            _buildFieldLabel('Session', isRequired: false),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _chooseSession,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5DFD7), width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sessionLabel(session),
                        style: const TextStyle(
                          color: Color(0xFF1E242B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Field 5: Reason *
            _buildFieldLabel('Reason'),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(color: Color(0xFF1E242B), fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Enter reason for leave...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13.5,
                ),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5DFD7)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5DFD7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFBA4728),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Field 6: Supporting document (optional)
            _buildFieldLabel(
              'Supporting document (optional)',
              isRequired: false,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5EFEB),
                    foregroundColor: const Color(0xFF1E242B),
                    side: const BorderSide(color: Color(0xFFE5DFD7)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _chooseDocument,
                  child: const Text(
                    'Choose file',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          attachmentName ?? 'No file chosen',
                          style: TextStyle(
                            color: attachmentName != null
                                ? const Color(0xFF1E242B)
                                : const Color(0xFF6B7280),
                            fontSize: 13,
                            fontWeight: attachmentName != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (attachmentName != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              attachmentName = null;
                              attachmentBytes = null;
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'PDF or image, up to 10 MB.',
              style: TextStyle(color: Color(0xFF8C7B70), fontSize: 11.5),
            ),
            const SizedBox(height: 18),

            // Preview Result Section (Error Banner or Deduction Card)
            if (previewLoading)
              Container(
                height: 50,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFBA4728),
                  ),
                ),
              )
            else if (previewError != null)
              // Error banner matching Image 1
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF87171), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        previewError!,
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (previewData != null)
              // Deduction card matching Image 2
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6F1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEFE8DE), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: Color(0xFFBA4728),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${previewData!['days'] ?? 1} ${previewData!['days'] == 1 ? 'day' : 'days'} will be deducted',
                          style: const TextStyle(
                            color: Color(0xFF1E242B),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _previewStat(
                          'Balance',
                          '${previewData!['balance'] ?? 0}',
                        ),
                        _previewStat(
                          'Pending',
                          '${previewData!['pending'] ?? 0}',
                        ),
                        _previewStat(
                          'Available after',
                          '${previewData!['availableAfter'] ?? 0}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Bottom Action Buttons matching Image 1 & 2
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E242B),
                    side: const BorderSide(color: Color(0xFFE5DFD7)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: canSubmit
                        ? const Color(0xFFBA4728)
                        : const Color(0xFFD49A87),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    elevation: 0,
                  ),
                  onPressed: canSubmit ? _submitRequest : null,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit request',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = true}) {
    if (!isRequired) {
      return Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1E242B),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF1E242B),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(
    dynamic colorValue, {
    Color fallback = const Color(0xFF3B82F6),
  }) {
    if (colorValue == null) return fallback;
    if (colorValue is Color) return colorValue;
    final s = colorValue.toString().trim();
    if (s.startsWith('#')) {
      final hex = s.replaceFirst('#', '');
      if (hex.length == 6) {
        final val = int.tryParse('FF$hex', radix: 16);
        if (val != null) return Color(val);
      } else if (hex.length == 8) {
        final val = int.tryParse(hex, radix: 16);
        if (val != null) return Color(val);
      }
    }
    return fallback;
  }
}
