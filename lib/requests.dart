import 'package:flutter/material.dart';
import 'api.dart';
import 'design.dart';

class RequestsPage extends StatefulWidget {
  final Api api;
  final String mode;
  const RequestsPage({super.key, required this.api, required this.mode});
  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<Json> rows = [];
  bool loading = true, more = false, loadingMore = false;
  String kind = 'Leave', status = 'All';
  bool showSearch = false;
  DateTimeRange? range;
  final employee = TextEditingController();
  Object? error;
  @override
  void initState() {
    super.initState();
    if (widget.mode == 'approvals') status = 'Pending';
    load();
  }

  @override
  void dispose() {
    employee.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    setState(() {
      error = null;
      if (append) {
        loadingMore = true;
      } else {
        loading = true;
      }
    });
    try {
      final approvalsPending =
          widget.mode == 'approvals' &&
          (status == 'Pending' || status == 'All');
      final r = await widget.api.get(
        kind == 'Attendance' ? '/regularisations' : '/leave-requests',
        query: {
          if (widget.mode != 'approvals') 'mine': 'true',
          if (approvalsPending) 'actionable': 'true',
          if (approvalsPending)
            'status': 'PENDING'
          else if (status != 'All')
            'status': status.toUpperCase(),
          'kind': kind,
          'offset': '${append ? rows.length : 0}',
          if (employee.text.isNotEmpty) 'q': employee.text.trim(),
          if (range != null) 'from': dateOnly(range!.start),
          if (range != null) 'to': dateOnly(range!.end),
        },
      );
      if (mounted) {
        setState(() {
          rows = append ? [...rows, ...items(r)] : items(r);
          more = r['has_more'] == true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> filters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(c).bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (c, update) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('Filter requests'),
              label('Employee name or ID'),
              TextField(controller: employee),
              if (widget.mode != 'approvals') ...[
                label('Status'),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['All', 'Pending', 'Approved', 'Rejected', 'Cancelled']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (s) {
                    status = s!;
                    update(() {});
                  },
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final d = await showDateRangePicker(
                    context: c,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDateRange: range,
                  );
                  if (d != null) update(() => range = d);
                },
                child: Text(
                  range == null
                      ? 'Choose updated-date range'
                      : '${dateOnly(range!.start)} – ${dateOnly(range!.end)}',
                ),
              ),
              TextButton(
                onPressed: () {
                  employee.clear();
                  update(() {
                    range = null;
                    status = widget.mode == 'approvals' ? 'Pending' : 'All';
                  });
                },
                child: const Text('Clear filters'),
              ),
              ActionButton('Apply filters', onPressed: () => Navigator.pop(c)),
            ],
          ),
        ),
      ),
    );
    load();
  }

  Future<void> decide(Json request, String decision) async {
    var note = '';
    if (decision == 'Rejected') {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Reject request'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'Add a comment'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      note = controller.text.trim();
      controller.dispose();
      if (ok != true || !mounted) return;
      if (note.isEmpty) {
        message(context, 'Please add rejection remarks.');
        return;
      }
    } else if (!await confirm(
      context,
      'Approve request?',
      'Approved leave is counted as used for that leave type.',
    )) {
      return;
    }
    try {
      await widget.api.mutate(
        '/leave-requests/${request['id']}/${decision == 'Rejected' ? 'reject' : 'approve'}',
        {'comment': note},
      );
      if (mounted) message(context, 'Request updated.');
      await load();
    } catch (e) {
      if (mounted) message(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == 'approvals') return _approvalBody();
    return _standardBody();
  }

  Widget _approvalBody() {
    final pendingCount = status == 'Pending' ? rows.length : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team approvals',
                      style: TextStyle(
                        color: Color(0xFF1B2A4A),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Review and manage your team’s requests',
                      style: TextStyle(color: Color(0xFF8B93A7), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Material(
                color: const Color(0xFFE7F6EE),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Filter requests',
                  onPressed: filters,
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF1B7F56),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  for (final item in [
                    ('Leave', Icons.spa_outlined),
                    ('Attendance', Icons.calendar_month_outlined),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Material(
                          color: kind == item.$1 ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              kind = item.$1;
                              load();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.$2,
                                    size: 16,
                                    color: kind == item.$1
                                        ? Colors.white
                                        : const Color(0xFF1B2A4A),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.$1,
                                    style: TextStyle(
                                      color: kind == item.$1
                                          ? Colors.white
                                          : const Color(0xFF1B2A4A),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (kind == item.$1 && !loading) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${rows.length}',
                                        style: const TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final name in ['Pending', 'Approved', 'Rejected'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: status == name
                                ? const Color(0xFFE7F6EE)
                                : const Color(0xFFF3F5F7),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                status = name;
                                load();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(
                                  name == 'Pending' && pendingCount != null
                                      ? 'Pending ($pendingCount)'
                                      : name,
                                  style: TextStyle(
                                    color: status == name
                                        ? const Color(0xFF1B7F56)
                                        : const Color(0xFF6E7C8A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Material(
                color: const Color(0xFFF3F5F7),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Search employee',
                  onPressed: () => setState(() => showSearch = !showSearch),
                  icon: const Icon(Icons.search, color: Color(0xFF6E7C8A)),
                ),
              ),
            ],
          ),
        ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: employee,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Employee name or ID',
                isDense: true,
              ),
              onSubmitted: (_) => load(),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: loading
              ? const DashboardShimmer()
              : error != null
              ? FailureView(error!, load)
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      if (rows.isEmpty)
                        const EmptyView(
                          'All clear here.',
                          'No requests match this view.',
                        ),
                      ...rows.map(
                        (r) => RequestTile(
                          r,
                          showEmployee: true,
                          approval: true,
                          onApprove: r['status'] == 'Pending'
                              ? () => decide(r, 'Approved')
                              : null,
                          onReject: r['status'] == 'Pending'
                              ? () => decide(r, 'Rejected')
                              : null,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RequestDetails(
                                  api: widget.api,
                                  id: r['id'],
                                  review: true,
                                ),
                              ),
                            );
                            load();
                          },
                        ),
                      ),
                      if (more)
                        ActionButton(
                          'Load more',
                          busy: loadingMore,
                          onPressed: () => load(append: true),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _standardBody() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: heading(
                    widget.mode == 'approvals'
                        ? 'Team approvals'
                        : widget.mode == 'history'
                        ? 'Approval history'
                        : 'My requests',
                  ),
                ),
                IconButton(
                  tooltip: 'Filter requests',
                  onPressed: filters,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            if (widget.mode == 'approvals')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Decision history')),
                          body: RequestsPage(api: widget.api, mode: 'history'),
                        ),
                      ),
                    );
                    load();
                  },
                  child: const Text('View history →'),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Leave', label: Text('Leave')),
                  ButtonSegment(value: 'Attendance', label: Text('Attendance')),
                ],
                selected: {kind},
                onSelectionChanged: (s) {
                  kind = s.first;
                  load();
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
      Expanded(
        child: loading
            ? const DashboardShimmer()
            : error != null
            ? FailureView(error!, load)
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  children: [
                    if (rows.isEmpty)
                      const EmptyView(
                        'All clear here.',
                        'No requests match this view.',
                      ),
                    ...rows.map(
                      (r) => RequestTile(
                        r,
                        showEmployee: widget.mode != 'requests',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RequestDetails(api: widget.api, id: r['id']),
                            ),
                          );
                          load();
                        },
                      ),
                    ),
                    if (more)
                      ActionButton(
                        'Load more',
                        busy: loadingMore,
                        onPressed: () => load(append: true),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    ],
  );
}

class RequestDetails extends StatefulWidget {
  final Api api;
  final String id;
  final bool review;
  const RequestDetails({
    super.key,
    required this.api,
    required this.id,
    this.review = false,
  });
  @override
  State<RequestDetails> createState() => _RequestDetailsState();
}

class _RequestDetailsState extends State<RequestDetails> {
  Json? r;
  Object? error;
  bool busy = false;
  final remarks = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    remarks.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final d = await widget.api.get('/leave-requests/${widget.id}');
      if (mounted) {
        setState(() {
          r = d;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> action(String a) async {
    if (a == 'cancel') {
      await comingSoon(
        context,
        'Cancel request',
        'Cancelling a leave request is coming soon.',
      );
      return;
    }
    if (a == 'Rejected' && remarks.text.trim().isEmpty) {
      message(context, 'Please add rejection remarks.');
      return;
    }
    if (!await confirm(
      context,
      a == 'cancel'
          ? 'Cancel this request?'
          : '${a == 'Approved' ? 'Approve' : 'Reject'} request?',
      'This action will be recorded in the request history.',
    )) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.api.mutate(
        '/leave-requests/${widget.id}/${switch (a) {
          'cancel' => 'cancel',
          'Rejected' => 'reject',
          _ => 'approve',
        }}',
        a == 'cancel' ? {} : {'comment': remarks.text.trim()},
      );
      await load();
      if (mounted) message(context, 'Request updated.');
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _reviewBody() {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave request details')),
        body: FailureView(error!, load),
      );
    }
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave request details')),
        body: const DashboardShimmer(),
      );
    }
    final d = r!;
    final own = d['user_id'] == widget.api.profile?['id'];
    final canDecide =
        d['status'] == 'Pending' &&
        d['approver_id'] == widget.api.profile?['id'] &&
        widget.api.manager &&
        (!own || widget.api.offline);
    final leave = d['kind'] == 'Leave';
    final name = d['employee_name']?.toString() ?? '';
    final manager = d['approver_name']?.toString().trim();
    final managerName = manager == null || manager.isEmpty
        ? 'Manager'
        : manager;
    final status = d['status']?.toString() ?? '';
    Json? submitted;
    for (final event in (d['events'] as List?) ?? const []) {
      if (event is Map && event['action'] == 'Submitted') {
        submitted = Map<String, dynamic>.from(event);
      }
    }
    final balance = d['balance'] is Map
        ? Map<String, dynamic>.from(d['balance'] as Map)
        : null;
    final tone = switch (status) {
      'Approved' => (const Color(0xFFE7F6EE), const Color(0xFF1B7F56)),
      'Rejected' => (const Color(0xFFFDECEC), const Color(0xFFE15B64)),
      _ => (const Color(0xFFFFF6E0), const Color(0xFFC48A00)),
    };
    final managerTitle = switch (status) {
      'Approved' => 'Approved by $managerName',
      'Rejected' => 'Rejected by $managerName',
      _ => 'Pending with $managerName (Manager)',
    };
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F8),
        centerTitle: true,
        title: Text(
          leave ? 'Leave request details' : 'Attendance request',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          if (own && leave && status == 'Pending')
            PopupMenuButton<String>(
              enabled: !busy,
              onSelected: (_) => action('cancel'),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'cancel', child: Text('Cancel request')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _whiteCard(
            child: Row(
              children: [
                PersonMark(name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF1B2A4A),
                        ),
                      ),
                      Text(
                        'Employee ID: ${(d['code']?.toString().isNotEmpty ?? false) ? d['code'] : d['user_id']}',
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
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: tone.$1,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: tone.$2,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  Icons.calendar_today_outlined,
                  'Applied on',
                  shortDate(d['created'].toString()),
                  clockText(d['created']),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  Icons.schedule_outlined,
                  leave ? 'Leave duration' : 'When',
                  leave
                      ? '${d['days']} days'
                      : shortDate(d['start'].toString()),
                  leave
                      ? '${shortDate(d['start'].toString())}${d['end'] == d['start'] ? '' : ' – ${shortDate(d['end'].toString())}'}'
                      : shortDate(d['end'].toString()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  Icons.spa_outlined,
                  leave ? 'Leave type' : 'Type',
                  '${d['type_name'] ?? d['kind']}',
                  '',
                ),
              ),
            ],
          ),
          if (!leave && d['proposed_in'] != null) ...[
            const SizedBox(height: 12),
            _whiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  detail('Original clock in', clockText(d['original_in'])),
                  detail('Original clock out', clockText(d['original_out'])),
                  detail('Proposed clock in', clockText(d['proposed_in'])),
                  detail('Proposed clock out', clockText(d['proposed_out'])),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _whiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: Color(0xFF8B93A7),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reason',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${d['reason'] ?? ''}',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          if (balance != null) ...[
            const SizedBox(height: 12),
            _whiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.hourglass_bottom_outlined,
                        size: 18,
                        color: Color(0xFF1B7F56),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Leave balance after approval',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3FBF7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _balanceBit(
                            '${balance['name']}',
                            '${balance['available']} days',
                            'remaining',
                            highlight: true,
                          ),
                        ),
                        Expanded(
                          child: _balanceBit(
                            'Total',
                            '${balance['allocation']} days',
                            '',
                          ),
                        ),
                        Expanded(
                          child: _balanceBit(
                            'Used',
                            '${balance['used']} days',
                            '',
                          ),
                        ),
                        Expanded(
                          child: _balanceBit(
                            'Requested',
                            '${d['days']} days',
                            '',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _whiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: Color(0xFF1B7F56),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Approval timeline',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _timelineStep(
                  color: const Color(0xFF1B7F56),
                  title: 'Request Submitted',
                  when: submitted?['at'] == null
                      ? ''
                      : '${shortDate(submitted!['at'].toString())}, ${clockText(submitted['at'])}',
                  side: 'By: ${submitted?['actor'] ?? name}',
                  line: true,
                ),
                _timelineStep(
                  color: status == 'Rejected'
                      ? const Color(0xFFE15B64)
                      : status == 'Approved'
                      ? const Color(0xFF1B7F56)
                      : const Color(0xFFE0A100),
                  title: managerTitle,
                  when: '',
                  side:
                      'Since: ${shortDate(d['created'].toString())}, ${clockText(d['created'])}',
                  line: false,
                ),
              ],
            ),
          ),
          if (canDecide) ...[
            const SizedBox(height: 12),
            _whiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 18,
                        color: Color(0xFF8B93A7),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Comments',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: remarks,
                    maxLines: 3,
                    maxLength: 500,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Add a comment (optional)',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      counterText: '${remarks.text.length}/500',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFDECEC),
                      foregroundColor: const Color(0xFFE15B64),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: busy ? null : () => action('Rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: busy ? null : () => action('Approved'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Approve',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.review) return _reviewBody();
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request')),
        body: FailureView(error!, load),
      );
    }
    if (r == null) {
      return Scaffold(appBar: AppBar(), body: const DashboardShimmer());
    }
    final d = r!,
        own = d['user_id'] == widget.api.profile?['id'],
        canDecide =
            d['status'] == 'Pending' &&
            d['approver_id'] == widget.api.profile?['id'] &&
            widget.api.manager &&
            (!own || widget.api.offline);
    final events = (d['events'] as List);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          d['kind'] == 'Leave' ? 'Leave tracking' : 'Attendance request',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d['employee_name'],
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                StatusBadge(d['status']),
              ],
            ),
            heading(d['type_name']),
            Text(
              '${shortDate(d['start'])} – ${shortDate(d['end'])}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d['kind'] == 'Leave')
                    detail('Duration', '${d['days']} working days'),
                  detail('Employee ID', d['user_id']),
                  if (d['balance'] != null)
                    detail(
                      'Available balance',
                      '${d['balance']['available']} days (after pending reservations)',
                    ),
                  if (d['proposed_in'] != null) ...[
                    detail('Original clock in', clockText(d['original_in'])),
                    detail('Original clock out', clockText(d['original_out'])),
                    detail('Proposed clock in', clockText(d['proposed_in'])),
                    detail('Proposed clock out', clockText(d['proposed_out'])),
                  ],
                  label('Reason'),
                  Text(
                    d['reason'],
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
            const Text(
              'Your request journey',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 15),
            Panel(
              child: Column(
                children: [
                  ...events.map<Widget>(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 13,
                            backgroundColor: mint,
                            child: Icon(Icons.check, size: 16, color: ink),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e['action'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${e['actor']} · ${shortDate(e['at'])} ${clockText(e['at'])}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                                if (e['remarks'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      e['remarks'],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (d['status'] == 'Pending')
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 13,
                          backgroundColor: Color(0xFFF5D5B2),
                          child: Icon(Icons.more_horiz, size: 16),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Awaiting ${d['stage']} approval\n${d['approver_name'] ?? 'Approver not assigned'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (canDecide) ...[
              label('Decision remarks'),
              TextField(
                controller: remarks,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Required when rejecting',
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      'Reject',
                      busy: busy,
                      onPressed: () => action('Rejected'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      'Approve',
                      busy: busy,
                      onPressed: () => action('Approved'),
                    ),
                  ),
                ],
              ),
            ],
            if (own && d['kind'] == 'Leave' && d['status'] == 'Pending')
              ActionButton(
                'Cancel pending request',
                busy: busy,
                onPressed: () => action('cancel'),
              ),
            const SizedBox(height: 20),
            SelectableText(
              'Reference: ${d['id']}',
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  final Api api;
  const NotificationsPage({super.key, required this.api});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Json>? rows;
  bool more = false, busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    setState(() => busy = true);
    try {
      final r = await widget.api.get(
        '/notifications',
        query: {'offset': '${append ? rows?.length ?? 0 : 0}'},
      );
      if (mounted) {
        setState(() {
          rows = append ? [...?rows, ...items(r)] : items(r);
          more = r['has_more'] == true;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: error != null
        ? FailureView(error!, load)
        : rows == null
        ? const DashboardShimmer()
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                heading('Your latest updates'),
                if (rows!.isEmpty)
                  const EmptyView(
                    'You’re up to date.',
                    'Leave and HR updates will appear here.',
                  ),
                ...rows!.map(
                  (n) => Panel(
                    color: n['read'] == 0
                        ? const Color(0xFFEAF1EA)
                        : Colors.white,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text(
                        n['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${n['body']}\n${shortDate(n['created'])} · ${clockText(n['created'])}',
                        style: const TextStyle(fontSize: 11, height: 1.6),
                      ),
                      onTap: () async {
                        try {
                          await widget.api.patch(
                            '/notifications/${n['id']}/read',
                            {'read': true},
                          );
                          if (!context.mounted) return;
                          if (n['request_id'] != null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RequestDetails(
                                  api: widget.api,
                                  id: n['request_id'],
                                ),
                              ),
                            );
                          } else {
                            await showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(n['title']),
                                content: Text(n['body']),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          }
                          load();
                        } catch (e) {
                          if (context.mounted) message(context, e);
                        }
                      },
                    ),
                  ),
                ),
                if (more)
                  ActionButton(
                    'Load more',
                    busy: busy,
                    onPressed: () => load(append: true),
                  ),
              ],
            ),
          ),
  );
}

Widget _whiteCard({required Widget child}) => DecoratedBox(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
  ),
  child: Padding(padding: const EdgeInsets.all(14), child: child),
);

Widget _statCard(IconData icon, String label, String value, String sub) =>
    DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF8B93A7)),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.2,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8B93A7),
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
          ],
        ),
      ),
    );

Widget _balanceBit(
  String label,
  String value,
  String caption, {
  bool highlight = false,
}) => Column(
  children: [
    Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Color(0xFF6E7C8A), fontSize: 11),
    ),
    const SizedBox(height: 4),
    Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: highlight ? primary : const Color(0xFF1B2A4A),
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    ),
    if (caption.isNotEmpty)
      Text(
        caption,
        style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10),
      ),
  ],
);

Widget _timelineStep({
  required Color color,
  required String title,
  required String when,
  required String side,
  required bool line,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(
      width: 16,
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          if (line)
            Container(width: 2, height: 42, color: const Color(0xFFD7E8DF)),
        ],
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            if (when.isNotEmpty)
              Text(
                when,
                style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
              ),
          ],
        ),
      ),
    ),
    const SizedBox(width: 8),
    Flexible(
      child: Text(
        side,
        textAlign: TextAlign.end,
        style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
      ),
    ),
  ],
);
