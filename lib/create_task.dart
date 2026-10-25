import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'all_tasks.dart';
import 'api.dart';
import 'design.dart';

/// Screen to create a new task or recurring series.
/// Fetches categories, active projects, and assignees/watchers from the v1 API.
class CreateTaskPage extends StatefulWidget {
  final Api api;
  final VoidCallback? onCreated;
  final bool isRecurringDefault;

  const CreateTaskPage({
    super.key,
    required this.api,
    this.onCreated,
    this.isRecurringDefault = false,
  });

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _intervalCtrl = TextEditingController(text: '1');
  final TextEditingController _occurrencesCtrl = TextEditingController(text: '10');

  // Form State
  String _taskType = 'GENERAL'; // 'GENERAL' or 'OUTLET'
  String? _selectedCategoryId;
  String? _selectedProjectId;
  String _priority = 'MEDIUM'; // 'LOW', 'MEDIUM', 'HIGH', 'URGENT'

  // Schedule State
  bool _repeat = false;
  DateTime? _startAt;
  DateTime? _dueAt;
  String _timezone = 'Asia/Kolkata';

  // Recurrence State
  String _frequency = 'WEEKLY'; // 'DAILY', 'WEEKLY', 'MONTHLY'
  Set<int> _byWeekday = {7}; // 1 = Monday ... 7 = Sunday. Defaults to Sunday.
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  String _endsWith = 'END_TIME'; // 'END_TIME' or 'DURATION'
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  int _durationMinutes = 60;
  String _endType = 'NEVER'; // 'NEVER', 'ON_DATE', 'AFTER_OCCURRENCES'
  DateTime? _untilDate;

  // People State
  final String _assignmentMode = 'SINGLE';
  List<String> _assigneeIds = [];
  List<String> _watcherIds = [];

  // API Data
  List<Json> _categories = [];
  List<Json> _projects = [];
  List<Json> _employees = [];

  bool _loadingLookups = true;
  bool _submitting = false;

  Api get api => widget.api;

  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _line = Color(0xFFE9EDF1);
  static const Color _taskBrown = Color(0xFFBE5E38);
  static const Color _cardBg = Colors.white;

  @override
  void initState() {
    super.initState();
    // Default timezone from user profile if available
    final officeTz = officeTimezone;
    if (officeTz.isNotEmpty) _timezone = officeTz;

    // Default assignee to current user
    final myId = api.profile?['id']?.toString();
    if (myId != null && myId.isNotEmpty) {
      _assigneeIds = [myId];
    }

    // Default byWeekday to today's weekday
    final todayWeekday = DateTime.now().weekday;
    _byWeekday = {todayWeekday};

    if (widget.isRecurringDefault) {
      _repeat = true;
    }

    _loadLookups();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _intervalCtrl.dispose();
    _occurrencesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() => _loadingLookups = true);
    try {
      final results = await Future.wait([
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
          '/employees/lookup',
          query: {'limit': 50},
        ).catchError((_) => null),
      ]);

      if (!mounted) return;
      setState(() {
        final cData = results[0];
        if (cData is Map && cData['items'] is List) {
          _categories = _list(cData['items']);
        } else if (cData is List) {
          _categories = _list(cData);
        }

        final pData = results[1];
        if (pData is Map && pData['items'] is List) {
          _projects = _list(pData['items']);
        } else if (pData is List) {
          _projects = _list(pData);
        }

        final eData = results[2];
        if (eData is List) {
          _employees = _list(eData);
        } else if (eData is Map && eData['items'] is List) {
          _employees = _list(eData['items']);
        }

        _loadingLookups = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLookups = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      message(context, 'Please enter a task title.');
      return;
    }

    setState(() => _submitting = true);

    try {
      // Build recurrence object if repeat is active
      Map<String, dynamic>? recurrence;
      if (_repeat) {
        final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
        final count = int.tryParse(_occurrencesCtrl.text.trim());

        String formatHhMm(TimeOfDay t) =>
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

        final sortedWeekdays = _byWeekday.toList()..sort();
        recurrence = {
          'frequency': _frequency,
          'interval': interval,
          'byWeekday': _frequency == 'WEEKLY' ? sortedWeekdays : <int>[],
          'byMonthDay': <int>[],
          'startDate': dateOnly(_startDate),
          'startTime': formatHhMm(_startTime),
          'endTime': _endsWith == 'END_TIME' ? formatHhMm(_endTime) : null,
          'timezone': _timezone,
          'endType': _endType,
          'untilDate': _endType == 'ON_DATE' && _untilDate != null ? dateOnly(_untilDate!) : null,
          'count': _endType == 'AFTER_OCCURRENCES' ? count : null,
        };
      }

      // If no assignee specified, ensure current user is assigned
      final myId = api.profile?['id']?.toString();
      final finalAssignees = _assigneeIds.isNotEmpty
          ? _assigneeIds
          : (myId != null ? [myId] : <String>[]);

      final payload = <String, dynamic>{
        'title': title,
        'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        'taskType': _taskType,
        'outletId': null,
        'templateId': null,
        'categoryId': _selectedCategoryId,
        'projectId': _selectedProjectId,
        'priority': _priority,
        'startAt': !_repeat && _startAt != null ? _startAt!.toUtc().toIso8601String() : null,
        'dueAt': !_repeat && _dueAt != null ? _dueAt!.toUtc().toIso8601String() : null,
        'timezone': _timezone,
        'assignmentMode': _assignmentMode,
        'assigneeIds': finalAssignees,
        'teamId': null,
        'watcherIds': _watcherIds,
        'recurrence': recurrence,
      };

      await api.v1(
        'POST',
        '/tasks',
        body: payload,
      );

      if (!mounted) return;
      message(context, _repeat ? 'Recurring task series created!' : 'Task created successfully!');
      widget.onCreated?.call();

      // Navigate to All Tasks Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AllTasksPage(api: api),
        ),
      );
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: _ink),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              if (_loadingLookups)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    color: _taskBrown,
                    backgroundColor: Color(0xFFFCE9DA),
                  ),
                ),
              // ── Header & Breadcrumb ───────────────────────────────────
              const Text(
                'Tasks / New task',
                style: TextStyle(
                  color: _soft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create task',
                style: TextStyle(
                  color: _ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Plan the work, choose who does it, and optionally make it repeat.',
                style: TextStyle(
                  color: _soft,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // ── Card 1: Details ───────────────────────────────────────
              _buildDetailsCard(),
              const SizedBox(height: 18),

              // ── Card 2: Schedule ──────────────────────────────────────
              _buildScheduleCard(),
              const SizedBox(height: 18),

              // ── Card 3: People ────────────────────────────────────────
              _buildPeopleCard(),
              const SizedBox(height: 24),

              // ── Bottom Action Bar ─────────────────────────────────────
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Card 1: Details ─────────────────────────────────────────────────────
  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Divider(height: 24, color: _line),

          // Title *
          _fieldLabel('Title', required: true),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleCtrl,
            style: const TextStyle(color: _ink, fontSize: 14),
            decoration: _inputDecoration('e.g. Prepare monthly sales report'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: 16),

          // Task type
          _fieldLabel('Task type'),
          const SizedBox(height: 6),
          _dropdownContainer(
            value: _taskType == 'GENERAL' ? 'General task' : 'Outlet / site task',
            onTap: _pickTaskType,
          ),
          const SizedBox(height: 16),

          // Category & Project in a responsive Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 480;
              final catWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Category'),
                  const SizedBox(height: 6),
                  _dropdownContainer(
                    value: _selectedCategoryName ?? 'No category',
                    onTap: _pickCategory,
                  ),
                ],
              );

              final projWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Project'),
                  const SizedBox(height: 6),
                  _dropdownContainer(
                    value: _selectedProjectName ?? 'No project',
                    onTap: _pickProject,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Only active projects can receive new tasks.',
                    style: TextStyle(color: _soft, fontSize: 11),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: catWidget),
                    const SizedBox(width: 14),
                    Expanded(child: projWidget),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  catWidget,
                  const SizedBox(height: 14),
                  projWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Priority *
          _fieldLabel('Priority', required: true),
          const SizedBox(height: 6),
          _dropdownContainer(
            value: _pretty(_priority),
            onTap: _pickPriority,
          ),
          const SizedBox(height: 16),

          // Description
          _fieldLabel('Description'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descCtrl,
            minLines: 4,
            maxLines: 6,
            maxLength: 5000,
            style: const TextStyle(color: _ink, fontSize: 13.5),
            decoration: _inputDecoration('Instructions, acceptance criteria, links...'),
          ),
        ],
      ),
    );
  }

  // ── Card 2: Schedule ────────────────────────────────────────────────────
  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _repeat
                          ? 'This creates a recurring series; each occurrence becomes its own task.'
                          : 'Times use your local clock ($_timezone).',
                      style: const TextStyle(color: _soft, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _repeat,
                    activeThumbColor: _taskBrown,
                    onChanged: (val) => setState(() => _repeat = val),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Repeat',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, color: _line),

          if (!_repeat) ...[
            // ── One-time task fields ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 480;
                final startWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Start'),
                    const SizedBox(height: 6),
                    _dateTimeSelector(
                      value: _startAt,
                      placeholder: 'dd/mm/yyyy, --:-- --',
                      onPick: () => _pickDateTime(isStart: true),
                      onClear: () => setState(() => _startAt = null),
                    ),
                  ],
                );
                final dueWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Due'),
                    const SizedBox(height: 6),
                    _dateTimeSelector(
                      value: _dueAt,
                      placeholder: 'dd/mm/yyyy, --:-- --',
                      onPick: () => _pickDateTime(isStart: false),
                      onClear: () => setState(() => _dueAt = null),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: startWidget),
                      const SizedBox(width: 14),
                      Expanded(child: dueWidget),
                    ],
                  );
                }
                return Column(
                  children: [
                    startWidget,
                    const SizedBox(height: 14),
                    dueWidget,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Timezone
            _fieldLabel('Task timezone'),
            const SizedBox(height: 6),
            _dropdownContainer(value: _timezone, onTap: _pickTimezone),
            const SizedBox(height: 4),
            const Text(
              'Used for reminders and how times show to others.',
              style: TextStyle(color: _soft, fontSize: 11),
            ),
          ] else ...[
            // ── Recurring task fields (Image 2) ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 540;
                final repeatsWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Repeats', required: true),
                    const SizedBox(height: 6),
                    _dropdownContainer(
                      value: _pretty(_frequency),
                      onTap: _pickFrequency,
                    ),
                  ],
                );

                final everyWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Every', required: true),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _intervalCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: _ink, fontSize: 14),
                            decoration: _inputDecoration('1'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _frequencyUnitText,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every ${_intervalCtrl.text.trim()} $_frequencyUnitText',
                      style: const TextStyle(color: _soft, fontSize: 11),
                    ),
                  ],
                );

                final tzWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Timezone', required: true),
                    const SizedBox(height: 6),
                    _dropdownContainer(value: _timezone, onTap: _pickTimezone),
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: repeatsWidget),
                      const SizedBox(width: 12),
                      Expanded(child: everyWidget),
                      const SizedBox(width: 12),
                      Expanded(child: tzWidget),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    repeatsWidget,
                    const SizedBox(height: 14),
                    everyWidget,
                    const SizedBox(height: 14),
                    tzWidget,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // On these days (when Weekly)
            if (_frequency == 'WEEKLY') ...[
              _fieldLabel('On these days'),
              const SizedBox(height: 8),
              _buildWeekdaySelector(),
              const SizedBox(height: 16),
            ],

            // Starts on & Start time & Ends with & End time (Image 2)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 540;
                final startsOnWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Starts on', required: true),
                    const SizedBox(height: 6),
                    _clickBox(
                      text: _formatDmy(_startDate),
                      icon: Icons.calendar_today_outlined,
                      onTap: _pickStartDate,
                    ),
                  ],
                );

                final startTimeWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Start time', required: true),
                    const SizedBox(height: 6),
                    _clickBox(
                      text: _startTime.format(context),
                      icon: Icons.access_time_rounded,
                      onTap: _pickStartTime,
                    ),
                  ],
                );

                final endsWithWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Ends with'),
                    const SizedBox(height: 6),
                    _dropdownContainer(
                      value: _endsWith == 'END_TIME' ? 'End time' : 'Duration',
                      onTap: () {
                        setState(() {
                          _endsWith = _endsWith == 'END_TIME' ? 'DURATION' : 'END_TIME';
                        });
                      },
                    ),
                  ],
                );

                final endTimeWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(_endsWith == 'END_TIME' ? 'End time' : 'Duration', required: true),
                    const SizedBox(height: 6),
                    if (_endsWith == 'END_TIME')
                      _clickBox(
                        text: _endTime.format(context),
                        icon: Icons.access_time_rounded,
                        onTap: _pickEndTime,
                      )
                    else
                      _dropdownContainer(
                        value: '$_durationMinutes mins',
                        onTap: _pickDuration,
                      ),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: startsOnWidget),
                      const SizedBox(width: 10),
                      Expanded(child: startTimeWidget),
                      const SizedBox(width: 10),
                      Expanded(child: endsWithWidget),
                      const SizedBox(width: 10),
                      Expanded(child: endTimeWidget),
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: startsOnWidget),
                        const SizedBox(width: 10),
                        Expanded(child: startTimeWidget),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: endsWithWidget),
                        const SizedBox(width: 10),
                        Expanded(child: endTimeWidget),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Series ends
            _fieldLabel('Series ends'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _radioOption('NEVER', 'Never'),
                _radioOption('ON_DATE', 'On date'),
                _radioOption('AFTER_OCCURRENCES', 'After'),
              ],
            ),
            if (_endType == 'ON_DATE') ...[
              const SizedBox(height: 8),
              _clickBox(
                text: _untilDate != null ? _formatDmy(_untilDate!) : 'Select end date',
                icon: Icons.calendar_today_outlined,
                onTap: _pickUntilDate,
              ),
            ],
            if (_endType == 'AFTER_OCCURRENCES') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _occurrencesCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: _inputDecoration('10'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('occurrences', style: TextStyle(color: _ink, fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 18),

            // ── Live Preview Box (Image 2) ──
            _buildRecurrencePreviewBox(context),
          ],
        ],
      ),
    );
  }

  // ── Weekday Selector ────────────────────────────────────────────────────
  Widget _buildWeekdaySelector() {
    final days = [
      (1, 'Mon'),
      (2, 'Tue'),
      (3, 'Wed'),
      (4, 'Thu'),
      (5, 'Fri'),
      (6, 'Sat'),
      (7, 'Sun'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final day in days)
          GestureDetector(
            onTap: () {
              setState(() {
                if (_byWeekday.contains(day.$1)) {
                  if (_byWeekday.length > 1) _byWeekday.remove(day.$1);
                } else {
                  _byWeekday.add(day.$1);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _byWeekday.contains(day.$1) ? _taskBrown : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _byWeekday.contains(day.$1) ? _taskBrown : _line,
                ),
              ),
              child: Text(
                day.$2,
                style: TextStyle(
                  color: _byWeekday.contains(day.$1) ? Colors.white : _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Recurrence Preview Box ──────────────────────────────────────────────
  Widget _buildRecurrencePreviewBox(BuildContext context) {
    final summary = _computeRecurrenceSummary();
    final occurrences = _computeNextOccurrences(6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFE8DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.refresh_rounded, size: 16, color: _taskBrown),
              SizedBox(width: 6),
              Text(
                'Preview',
                style: TextStyle(
                  color: _taskBrown,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (final occ in occurrences)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.calendar_today_outlined, size: 13, color: _soft),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_formatShortDmy(occ)}, ${_formatTimeHm(occ)} · your time ${_formatShortDmy(occ)}, ${_formatTimeHm(occ)}',
                          style: const TextStyle(color: Color(0xFF5A6672), fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card 3: People ──────────────────────────────────────────────────────
  Widget _buildPeopleCard() {
    final myName = api.profile?['name']?.toString() ?? 'You';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'People',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Divider(height: 24, color: _line),

          // Primary assignee notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _assigneeIds.isEmpty
                        ? 'This task will be assigned to you ($myName).'
                        : 'Assigned to ${_assigneeNames.join(', ')}.',
                    style: const TextStyle(
                      color: Color(0xFF1E40AF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _pickAssignees,
                  child: const Text('Change', style: TextStyle(color: Color(0xFF2563EB))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Watchers
          _fieldLabel('Watchers'),
          const SizedBox(height: 6),
          _dropdownContainer(
            value: _watcherIds.isEmpty
                ? 'Select employees...'
                : '${_watcherIds.length} employee${_watcherIds.length > 1 ? 's' : ''} selected',
            onTap: _pickWatchers,
          ),
          if (_watcherIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final wid in _watcherIds)
                  _watcherChip(wid),
              ],
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'Watchers are notified about comments and status changes.',
            style: TextStyle(color: _soft, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _watcherChip(String empId) {
    final match = _employees.cast<Json?>().firstWhere(
      (e) => e?['id']?.toString() == empId,
      orElse: () => null,
    );
    final name = match?['fullName']?.toString() ?? 'Employee';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: const Color(0xFFFCE9DA),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'W',
              style: const TextStyle(fontSize: 9, color: _taskBrown, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _watcherIds.remove(empId)),
            child: const Icon(Icons.close, size: 14, color: _soft),
          ),
        ],
      ),
    );
  }

  // ── Bottom Action Bar ───────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: Color(0xFFD0D7DE)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_task_rounded, size: 17),
              label: Text(
                _submitting
                    ? 'Creating...'
                    : (_repeat ? 'Create recurring task' : 'Create task'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _taskBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form Pickers ────────────────────────────────────────────────────────
  void _pickTaskType() {
    _showOptionsSheet(
      title: 'Task Type',
      options: [
        ('GENERAL', 'General task'),
        ('OUTLET', 'Outlet / site task'),
      ],
      selected: _taskType,
      onSelect: (val) => setState(() => _taskType = val ?? 'GENERAL'),
    );
  }

  void _pickPriority() {
    _showOptionsSheet(
      title: 'Priority',
      options: [
        ('LOW', 'Low'),
        ('MEDIUM', 'Medium'),
        ('HIGH', 'High'),
        ('URGENT', 'Urgent'),
      ],
      selected: _priority,
      onSelect: (val) => setState(() => _priority = val ?? 'MEDIUM'),
    );
  }

  void _pickFrequency() {
    _showOptionsSheet(
      title: 'Repeats',
      options: [
        ('WEEKLY', 'Weekly'),
        ('DAILY', 'Daily'),
        ('MONTHLY', 'Monthly'),
      ],
      selected: _frequency,
      onSelect: (val) => setState(() => _frequency = val ?? 'WEEKLY'),
    );
  }

  void _pickCategory() {
    final opts = [
      (null, 'No category'),
      for (final c in _categories)
        (c['id']?.toString(), c['name']?.toString() ?? 'Category'),
    ];
    _showOptionsSheet(
      title: 'Category',
      options: opts,
      selected: _selectedCategoryId,
      onSelect: (val) => setState(() => _selectedCategoryId = val),
    );
  }

  void _pickProject() {
    final opts = [
      (null, 'No project'),
      for (final p in _projects)
        (p['id']?.toString(), p['name']?.toString() ?? 'Project'),
    ];
    _showOptionsSheet(
      title: 'Project',
      options: opts,
      selected: _selectedProjectId,
      onSelect: (val) => setState(() => _selectedProjectId = val),
    );
  }

  void _pickTimezone() {
    final timezones = [
      'Asia/Kolkata',
      'UTC',
      'America/New_York',
      'Europe/London',
      'Asia/Singapore',
      'Asia/Dubai',
    ];
    _showOptionsSheet(
      title: 'Timezone',
      options: [for (final tz in timezones) (tz, tz)],
      selected: _timezone,
      onSelect: (val) => setState(() => _timezone = val ?? 'Asia/Kolkata'),
    );
  }

  void _pickDuration() {
    final durations = [15, 30, 45, 60, 90, 120, 240, 480];
    _showOptionsSheet(
      title: 'Duration',
      options: [for (final d in durations) ('$d', '$d minutes')],
      selected: '$_durationMinutes',
      onSelect: (val) => setState(() => _durationMinutes = int.tryParse(val ?? '60') ?? 60),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initialDate = (isStart ? _startAt : _dueAt) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startAt = combined;
      } else {
        _dueAt = combined;
      }
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickUntilDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _untilDate ?? _startDate.add(const Duration(days: 90)),
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _untilDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  void _pickAssignees() {
    _openEmployeePicker(
      title: 'Select Assignee(s)',
      selected: _assigneeIds,
      isMulti: true,
      onDone: (ids) => setState(() => _assigneeIds = ids),
    );
  }

  void _pickWatchers() {
    _openEmployeePicker(
      title: 'Select Watchers',
      selected: _watcherIds,
      isMulti: true,
      onDone: (ids) => setState(() => _watcherIds = ids),
    );
  }

  void _openEmployeePicker({
    required String title,
    required List<String> selected,
    required bool isMulti,
    required ValueChanged<List<String>> onDone,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _EmployeeMultiPickerSheet(
          title: title,
          employees: _employees,
          initialSelected: selected,
          isMulti: isMulti,
          onDone: onDone,
        );
      },
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
                    Text(
                      title,
                      style: const TextStyle(
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
              const SizedBox(height: 6),
              for (final opt in options)
                ListTile(
                  title: Text(
                    opt.$2,
                    style: TextStyle(
                      fontWeight: opt.$1 == selected ? FontWeight.w800 : FontWeight.w600,
                      color: opt.$1 == selected ? _taskBrown : _ink,
                    ),
                  ),
                  trailing: opt.$1 == selected
                      ? const Icon(Icons.check, color: _taskBrown)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelect(opt.$1);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Calculation Helpers ─────────────────────────────────────────────────
  String get _frequencyUnitText {
    return switch (_frequency) {
      'DAILY' => 'day',
      'MONTHLY' => 'month',
      _ => 'week',
    };
  }

  String _computeRecurrenceSummary() {
    final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
    final unit = interval == 1 ? _frequencyUnitText : '${_frequencyUnitText}s';

    final daysMap = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    final dayNames = _byWeekday.map((d) => daysMap[d] ?? '').where((s) => s.isNotEmpty).join(', ');

    String timeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    int durMins = _durationMinutes;
    if (_endsWith == 'END_TIME') {
      final startTotal = _startTime.hour * 60 + _startTime.minute;
      final endTotal = _endTime.hour * 60 + _endTime.minute;
      durMins = endTotal >= startTotal ? endTotal - startTotal : (24 * 60 - startTotal + endTotal);
    }
    final durStr = durMins >= 60 ? '${durMins ~/ 60}h${durMins % 60 > 0 ? ' ${durMins % 60}m' : ''}' : '${durMins}m';

    if (_frequency == 'WEEKLY') {
      return 'Every $interval $unit on $dayNames at $timeStr for $durStr ($_timezone)';
    }
    return 'Every $interval $unit at $timeStr for $durStr ($_timezone)';
  }

  List<DateTime> _computeNextOccurrences(int count) {
    final list = <DateTime>[];
    DateTime current = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    int maxLoops = 200;
    while (list.length < count && maxLoops > 0) {
      maxLoops--;
      if (_frequency == 'WEEKLY') {
        if (_byWeekday.contains(current.weekday)) {
          list.add(current);
        }
        current = current.add(const Duration(days: 1));
      } else if (_frequency == 'DAILY') {
        final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
        list.add(current);
        current = current.add(Duration(days: math.max(1, interval)));
      } else {
        // Monthly
        final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
        list.add(current);
        current = DateTime(current.year, current.month + math.max(1, interval), current.day, current.hour, current.minute);
      }
    }
    return list;
  }

  // ── Sub-component UI ────────────────────────────────────────────────────
  Widget _fieldLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE15B64), fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8B93A7), fontSize: 13.5),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _taskBrown, width: 1.5),
      ),
    );
  }

  Widget _dropdownContainer({
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD0D7DE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: _soft),
          ],
        ),
      ),
    );
  }

  Widget _clickBox({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD0D7DE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(icon, size: 16, color: _soft),
          ],
        ),
      ),
    );
  }

  Widget _dateTimeSelector({
    required DateTime? value,
    required String placeholder,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasVal = value != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0D7DE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasVal ? '${_formatDmy(value)} ${_formatTimeHm(value)}' : placeholder,
                        style: TextStyle(
                          color: hasVal ? _ink : const Color(0xFF8B93A7),
                          fontSize: 13,
                          fontWeight: hasVal ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 16, color: _soft),
                  ],
                ),
              ),
            ),
          ),
          if (hasVal)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: _soft),
              onPressed: onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _radioOption(String val, String label) {
    final selected = _endType == val;
    return GestureDetector(
      onTap: () => setState(() => _endType = val),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? _taskBrown : _soft, width: 2),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _taskBrown,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? _ink : _soft,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String? get _selectedCategoryName {
    if (_selectedCategoryId == null) return null;
    final match = _categories.cast<Json?>().firstWhere(
      (c) => c?['id']?.toString() == _selectedCategoryId,
      orElse: () => null,
    );
    return match?['name']?.toString();
  }

  String? get _selectedProjectName {
    if (_selectedProjectId == null) return null;
    final match = _projects.cast<Json?>().firstWhere(
      (p) => p?['id']?.toString() == _selectedProjectId,
      orElse: () => null,
    );
    return match?['name']?.toString();
  }

  List<String> get _assigneeNames {
    return _assigneeIds.map((id) {
      final match = _employees.cast<Json?>().firstWhere(
        (e) => e?['id']?.toString() == id,
        orElse: () => null,
      );
      return match?['fullName']?.toString() ?? 'Employee';
    }).toList();
  }

  String _formatDmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatShortDmy(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTimeHm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _pretty(String key) {
    if (key.isEmpty) return '';
    return key
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// ── Multi-employee Picker Sheet ───────────────────────────────────────────
class _EmployeeMultiPickerSheet extends StatefulWidget {
  final String title;
  final List<Json> employees;
  final List<String> initialSelected;
  final bool isMulti;
  final ValueChanged<List<String>> onDone;

  const _EmployeeMultiPickerSheet({
    required this.title,
    required this.employees,
    required this.initialSelected,
    required this.isMulti,
    required this.onDone,
  });

  @override
  State<_EmployeeMultiPickerSheet> createState() => _EmployeeMultiPickerSheetState();
}

class _EmployeeMultiPickerSheetState extends State<_EmployeeMultiPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Json> get _filtered {
    if (_query.isEmpty) return widget.employees;
    final q = _query.toLowerCase();
    return widget.employees.where((e) {
      final name = e['fullName']?.toString().toLowerCase() ?? '';
      final code = e['employeeCode']?.toString().toLowerCase() ?? '';
      final dept = e['department']?.toString().toLowerCase() ?? '';
      return name.contains(q) || code.contains(q) || dept.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFF1B2A4A),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onDone(_selected);
                    Navigator.pop(context);
                  },
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFBE5E38))),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Search box
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search employees...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8B93A7)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF8B93A7)),
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
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final emp = _filtered[i];
                  final id = emp['id']?.toString() ?? '';
                  final name = emp['fullName']?.toString() ?? 'Employee';
                  final code = emp['employeeCode']?.toString() ?? '';
                  final dept = emp['department']?.toString() ?? '';
                  final isChecked = _selected.contains(id);

                  return CheckboxListTile(
                    value: isChecked,
                    activeColor: const Color(0xFFBE5E38),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: Text('$code · $dept', style: const TextStyle(fontSize: 11.5, color: Color(0xFF6E7C8A))),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          if (!widget.isMulti) _selected.clear();
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _list(Object? v) {
  if (v is! List) return const [];
  return v
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}
