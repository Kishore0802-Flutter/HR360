import 'package:flutter/material.dart';
import 'api.dart';
import 'design.dart';
import 'module_switch.dart';

const _ink = Color(0xFF1B2A4A);
const _soft = Color(0xFF8B93A7);
const _line = Color(0xFFE9EDF1);
const _page = Color(0xFFF7F4F0);
const _amber = Color(0xFFE59A2F);
const _red = Color(0xFFE15B64);
const _blue = Color(0xFF4F7DF3);

/// Shared shell for the Tasks tabs: title, subtitle, optional filters, and
/// a create button that is held for a later release.
class _TaskScaffold extends StatelessWidget {
  final String title, subtitle;
  final Widget? filters;
  final Widget body;
  const _TaskScaffold({
    required this.title,
    required this.subtitle,
    required this.body,
    this.filters,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _page,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _soft, fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => comingSoon(
                  context,
                  'Create task',
                  'Creating and assigning tasks from the app is coming soon.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: tasksAccent,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create'),
              ),
            ],
          ),
        ),
        if (filters != null) ...[const SizedBox(height: 12), filters!],
        const SizedBox(height: 8),
        Expanded(child: body),
      ],
    ),
  );
}

class _Segments extends StatelessWidget {
  final List<(String, String)> items;
  final String value;
  final ValueChanged<String> onChanged;
  const _Segments({
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: item.$1 == value ? const Color(0xFFFCE9DA) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onChanged(item.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: item.$1 == value
                          ? tasksAccent.withValues(alpha: 0.4)
                          : _line,
                    ),
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      color: item.$1 == value ? tasksAccent : _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class MyTasksPage extends StatefulWidget {
  final Api api;
  const MyTasksPage({super.key, required this.api});
  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  String bucket = 'ongoing';
  bool mine = true;
  List<Json>? rows;
  Object? error;

  bool get canSeeOthers => widget.api.scope.toUpperCase() != 'SELF';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final data = await widget.api.v1(
        'GET',
        '/tasks',
        query: {'pageSize': 50, 'bucket': bucket, if (mine) 'mine': 'true'},
      );
      if (mounted) setState(() => rows = _rows(data));
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TaskScaffold(
      title: mine ? 'My tasks' : 'All tasks',
      subtitle: bucket == 'ongoing'
          ? 'Open work, soonest due first'
          : 'Finished work',
      filters: _Segments(
        value: '${mine ? 'mine' : 'all'}:$bucket',
        items: [
          ('mine:ongoing', 'Ongoing'),
          ('mine:completed', 'Completed'),
          if (canSeeOthers) ...[
            ('all:ongoing', 'Team ongoing'),
            ('all:completed', 'Team completed'),
          ],
        ],
        onChanged: (value) {
          final parts = value.split(':');
          setState(() {
            mine = parts[0] == 'mine';
            bucket = parts[1];
            rows = null;
          });
          load();
        },
      ),
      body: _ListState(
        rows: rows,
        error: error,
        retry: load,
        emptyTitle: 'Nothing here yet',
        emptyBody: mine
            ? 'Tasks assigned to you will show up here.'
            : 'No tasks match this view.',
        itemBuilder: (row) => _TaskCard(row),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Json task;
  const _TaskCard(this.task);

  @override
  Widget build(BuildContext context) {
    final project = _map(task['project']);
    final color = _hex(project['color']) ?? tasksAccent;
    final overdue = task['isOverdue'] == true;
    final due = task['dueAt']?.toString();
    final subtasks = _n(task['subtaskCount']);
    final assignees = _list(task['assignees'])
        .map((a) => a['fullName']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .join(', ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showTask(context, task),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              task['code']?.toString() ?? '',
                              style: const TextStyle(
                                color: _soft,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            _Tag(
                              _pretty(task['priority']?.toString() ?? ''),
                              _priorityTone(task['priority']?.toString() ?? ''),
                            ),
                            const SizedBox(width: 6),
                            _Tag(
                              _pretty(task['status']?.toString() ?? ''),
                              _statusTone(task['status']?.toString() ?? ''),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          task['title']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            if ((project['name'] ?? '').toString().isNotEmpty)
                              project['name'],
                            if (_map(task['outlet'])['name'] != null)
                              _map(task['outlet'])['name'],
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _soft, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              overdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.event_outlined,
                              size: 15,
                              color: overdue ? _red : _soft,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                due == null
                                    ? 'No due date'
                                    : '${overdue ? 'Overdue · ' : 'Due '}${shortDate(due)} ${clockText(due)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: overdue ? _red : _ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (subtasks > 0) ...[
                              const Icon(
                                Icons.checklist_rounded,
                                size: 15,
                                color: _soft,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${_n(task['subtaskCompleted'])}/$subtasks',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (assignees.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Assigned to $assignees',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _soft,
                              fontSize: 11.5,
                            ),
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
}

void _showTask(BuildContext context, Json task) {
  final project = _map(task['project']);
  final category = _map(task['category']);
  final outlet = _map(task['outlet']);
  final creator = _map(task['creator']);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  task['code']?.toString() ?? '',
                  style: const TextStyle(
                    color: _soft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _Tag(
                  _pretty(task['status']?.toString() ?? ''),
                  _statusTone(task['status']?.toString() ?? ''),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task['title']?.toString() ?? '',
              style: const TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            if ((task['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task['description'].toString(),
                style: const TextStyle(color: _ink, height: 1.4),
              ),
            ],
            const SizedBox(height: 16),
            for (final row in [
              ('Project', project['name']),
              ('Outlet', outlet['name']),
              ('Category', category['name']),
              ('Priority', _pretty(task['priority']?.toString() ?? '')),
              ('Starts', _when(task['startAt'])),
              ('Due', _when(task['dueAt'])),
              ('Created by', creator['fullName']),
              (
                'Subtasks',
                _n(task['subtaskCount']) == 0
                    ? null
                    : '${_n(task['subtaskCompleted'])} of ${_n(task['subtaskCount'])} done',
              ),
            ])
              if (row.$2 != null && row.$2.toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          row.$1,
                          style: const TextStyle(color: _soft, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.$2.toString(),
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => comingSoon(
                sheet,
                'Update task',
                'Changing status, adding comments, and completing tasks from the app is coming soon.',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: tasksAccent,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Update status'),
            ),
          ],
        ),
      ),
    ),
  );
}

class IssuesPage extends StatefulWidget {
  final Api api;
  const IssuesPage({super.key, required this.api});
  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  String status = '';
  List<Json>? rows;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final data = await widget.api.v1(
        'GET',
        '/issues',
        query: {'pageSize': 50, if (status.isNotEmpty) 'status': status},
      );
      if (mounted) setState(() => rows = _rows(data));
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => _TaskScaffold(
    title: 'Issues',
    subtitle: 'Problems reported on the floor and in projects',
    filters: _Segments(
      value: status,
      items: const [
        ('', 'All'),
        ('OPEN', 'Open'),
        ('IN_PROGRESS', 'In progress'),
        ('RESOLVED', 'Resolved'),
      ],
      onChanged: (value) {
        setState(() {
          status = value;
          rows = null;
        });
        load();
      },
    ),
    body: _ListState(
      rows: rows,
      error: error,
      retry: load,
      emptyTitle: 'No issues',
      emptyBody: 'Nothing has been reported in this view.',
      itemBuilder: (row) => _IssueCard(row),
    ),
  );
}

class _IssueCard extends StatelessWidget {
  final Json issue;
  const _IssueCard(this.issue);
  @override
  Widget build(BuildContext context) {
    final reporter = _map(issue['reporter']);
    final assignee = _map(issue['assignee']);
    final where = [
      _map(issue['outlet'])['name'],
      _map(issue['project'])['name'],
    ].where((part) => part != null).join(' · ');
    final status = issue['status']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _statusTone(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  status == 'RESOLVED'
                      ? Icons.task_alt_rounded
                      : Icons.report_gmailerrorred_rounded,
                  size: 19,
                  color: _statusTone(status),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue['title']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${issue['code'] ?? ''} · ${_pretty(issue['category']?.toString() ?? '')}',
                      style: const TextStyle(color: _soft, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((issue['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              issue['description'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontSize: 12.5, height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(_pretty(status), _statusTone(status)),
              _Tag(
                _pretty(issue['priority']?.toString() ?? ''),
                _priorityTone(issue['priority']?.toString() ?? ''),
              ),
              if (where.isNotEmpty) _Tag(where, _blue),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 15, color: _soft),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${reporter['fullName'] ?? 'Someone'} → ${assignee['fullName'] ?? 'Unassigned'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _soft, fontSize: 12),
                ),
              ),
              Text(
                _when(issue['createdAt']) ?? '',
                style: const TextStyle(color: _soft, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TaskCalendarPage extends StatefulWidget {
  final Api api;
  const TaskCalendarPage({super.key, required this.api});
  @override
  State<TaskCalendarPage> createState() => _TaskCalendarPageState();
}

class _TaskCalendarPageState extends State<TaskCalendarPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool mine = true;
  List<Json>? rows;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    final from = DateTime(month.year, month.month);
    final to = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(seconds: 1));
    try {
      final data = await widget.api.v1(
        'GET',
        '/calendar/events',
        query: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          if (mine) 'mine': 'true',
        },
      );
      final list = _rows(data)
        ..sort(
          (a, b) => (a['start'] ?? '').toString().compareTo(
            (b['start'] ?? '').toString(),
          ),
        );
      if (mounted) setState(() => rows = list);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  void shift(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      rows = null;
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Json>>{};
    for (final row in rows ?? const <Json>[]) {
      final start = DateTime.tryParse(row['start']?.toString() ?? '');
      if (start == null) continue;
      groups.putIfAbsent(dateOnly(start.toLocal()), () => []).add(row);
    }
    return _TaskScaffold(
      title: 'Calendar',
      subtitle: 'Tasks and recurring occurrences, day by day',
      filters: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => shift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => shift(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              if (widget.api.scope.toUpperCase() != 'SELF')
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(mine ? 'Mine' : 'Team'),
                    selected: mine,
                    onSelected: (_) {
                      setState(() {
                        mine = !mine;
                        rows = null;
                      });
                      load();
                    },
                    selectedColor: const Color(0xFFFCE9DA),
                    showCheckmark: false,
                    labelStyle: const TextStyle(
                      color: tasksAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: error != null
          ? FailureView(error!, load)
          : rows == null
          ? const DashboardShimmer()
          : RefreshIndicator(
              color: tasksAccent,
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                children: [
                  if (groups.isEmpty)
                    const EmptyView(
                      'A clear month',
                      'No tasks are scheduled in this month.',
                    ),
                  for (final entry in groups.entries) ...[
                    _DayHeader(entry.key),
                    for (final event in entry.value) _AgendaRow(event),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String day;
  const _DayHeader(this.day);
  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(day);
    final today = dateOnly(DateTime.now()) == day;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: today ? tasksAccent : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: today ? tasksAccent : _line),
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: today ? Colors.white : _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_weekdays[date.weekday - 1]}${today ? ' · Today' : ''}',
            style: TextStyle(
              color: today ? tasksAccent : _soft,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final Json event;
  const _AgendaRow(this.event);
  @override
  Widget build(BuildContext context) {
    final color = _hex(_map(event['project'])['color']) ?? tasksAccent;
    final overdue = event['isOverdue'] == true;
    final allDay = event['allDay'] == true;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(
                allDay ? 'All day' : clockText(event['start']),
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    [
                          _pretty(event['status']?.toString() ?? ''),
                          if (overdue) 'Overdue',
                          _map(event['project'])['name'],
                        ]
                        .where((p) => p != null && p.toString().isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: overdue ? _red : _soft,
                      fontSize: 11.5,
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

class _ListState extends StatelessWidget {
  final List<Json>? rows;
  final Object? error;
  final Future<void> Function() retry;
  final String emptyTitle, emptyBody;
  final Widget Function(Json row) itemBuilder;
  const _ListState({
    required this.rows,
    required this.error,
    required this.retry,
    required this.emptyTitle,
    required this.emptyBody,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) return FailureView(error!, retry);
    if (rows == null) return const DashboardShimmer();
    return RefreshIndicator(
      color: tasksAccent,
      onRefresh: retry,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
        itemCount: rows!.isEmpty ? 1 : rows!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => rows!.isEmpty
            ? EmptyView(emptyTitle, emptyBody)
            : itemBuilder(rows![i]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

const _monthNames = [
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
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

int _n(Object? value) => (value as num?)?.toInt() ?? 0;

Json _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Json> _list(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Json>[];

List<Json> _rows(Object? data) =>
    data is List ? _list(data) : _list(_map(data)['items']);

String _pretty(String raw) {
  final text = raw.toLowerCase().replaceAll('_', ' ');
  return text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1);
}

String? _when(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return '${shortDate(text)} · ${clockText(text)}';
}

Color? _hex(Object? value) {
  final text = value?.toString().replaceFirst('#', '') ?? '';
  if (text.length != 6) return null;
  final parsed = int.tryParse(text, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

Color _statusTone(String raw) => switch (raw.toUpperCase()) {
  'COMPLETED' || 'RESOLVED' => primary,
  'IN_PROGRESS' => _blue,
  'OPEN' => _red,
  _ => const Color(0xFF9C8466),
};

Color _priorityTone(String raw) => switch (raw.toUpperCase()) {
  'URGENT' => _red,
  'HIGH' => tasksAccent,
  'MEDIUM' => _amber,
  _ => _soft,
};
