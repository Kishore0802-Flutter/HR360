import 'package:flutter/material.dart';
import 'api.dart';
import 'design.dart';

/// Bottom sheet displaying rich, comprehensive task details fetched from GET /tasks/:id,
/// with live status transitions via POST /tasks/:id/status, completion via POST /tasks/:id/complete,
/// reopening via POST /tasks/:id/reopen, task editing via PATCH /tasks/:id,
/// comments via POST /tasks/:id/comments, and activity history.
class TaskDetailSheet extends StatefulWidget {
  final Json task;
  final Api api;
  final VoidCallback? onRefreshNeeded;

  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.api,
    this.onRefreshNeeded,
  });

  static Future<void> show(
    BuildContext context, {
    required Json task,
    required Api api,
    VoidCallback? onRefreshNeeded,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => TaskDetailSheet(
        task: task,
        api: api,
        onRefreshNeeded: onRefreshNeeded,
      ),
    );
  }

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late Json _task;
  bool _loadingDetails = false;
  bool _updatingStatus = false;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _sendingComment = false;

  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _line = Color(0xFFE2E8F0);
  static const Color _taskBrown = Color(0xFFBE5E38);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _amber = Color(0xFFD97706);
  static const Color _red = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _fetchTaskDetails();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTaskDetails() async {
    final taskId = _task['id']?.toString() ?? '';
    if (taskId.isEmpty) return;
    setState(() => _loadingDetails = true);
    try {
      final res = await widget.api.v1('GET', '/tasks/$taskId');
      if (!mounted) return;
      Json? full;
      if (res is Map<String, dynamic>) {
        if (res['data'] is Map<String, dynamic>) {
          full = res['data'] as Map<String, dynamic>;
        } else if (res['data'] is Map) {
          full = Map<String, dynamic>.from(res['data'] as Map);
        } else if (res['id'] != null) {
          full = res;
        }
      }
      if (full != null) {
        setState(() {
          _task = full!;
        });
      }
    } catch (_) {
      // Keep initial task data if network error or test mock
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final taskId = _task['id']?.toString() ?? '';
    if (taskId.isEmpty) return;
    setState(() => _updatingStatus = true);
    try {
      final res = await widget.api.v1(
        'POST',
        '/tasks/$taskId/status',
        body: {'status': newStatus},
      );
      if (!mounted) return;
      message(context, 'Status updated to ${_pretty(newStatus)}');
      widget.onRefreshNeeded?.call();

      if (res is Map<String, dynamic> && res['data'] is Map) {
        setState(() {
          _task = Map<String, dynamic>.from(res['data'] as Map);
        });
      } else {
        await _fetchTaskDetails();
      }
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _showCompleteDialog() async {
    final code = _task['code']?.toString() ?? 'task';
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Complete $code?',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: _soft),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.pop(dlgCtx, false),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The creator and assignees will be notified.',
              style: TextStyle(color: _soft, fontSize: 13),
            ),
            const SizedBox(height: 14),
            const Text(
              'Completion note (optional, added as a comment)',
              style: TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add a note...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _line),
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: Color(0xFFD0D7DE)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Mark completed', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final taskId = _task['id']?.toString() ?? '';
    if (taskId.isEmpty) return;

    setState(() => _updatingStatus = true);
    try {
      final res = await widget.api.v1(
        'POST',
        '/tasks/$taskId/complete',
        body: {'comment': noteCtrl.text.trim()},
      );
      if (!mounted) return;
      message(context, 'Task completed');
      widget.onRefreshNeeded?.call();

      if (res is Map<String, dynamic> && res['data'] is Map) {
        setState(() {
          _task = Map<String, dynamic>.from(res['data'] as Map);
        });
      } else {
        await _fetchTaskDetails();
      }
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _showReopenDialog() async {
    final code = _task['code']?.toString() ?? 'task';
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Reopen $code?',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: _soft),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.pop(dlgCtx, false),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Provide a reason for reopening this task.',
              style: TextStyle(color: _soft, fontSize: 13),
            ),
            const SizedBox(height: 14),
            const Text(
              'Reason (optional)',
              style: TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Why is this task reopened?',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _line),
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: Color(0xFFD0D7DE)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _taskBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reopen task', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final taskId = _task['id']?.toString() ?? '';
    if (taskId.isEmpty) return;

    setState(() => _updatingStatus = true);
    try {
      final res = await widget.api.v1(
        'POST',
        '/tasks/$taskId/reopen',
        body: {'reason': reasonCtrl.text.trim()},
      );
      if (!mounted) return;
      message(context, 'Task reopened');
      widget.onRefreshNeeded?.call();

      if (res is Map<String, dynamic> && res['data'] is Map) {
        setState(() {
          _task = Map<String, dynamic>.from(res['data'] as Map);
        });
      } else {
        await _fetchTaskDetails();
      }
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _showEditDialog() async {
    final titleCtrl = TextEditingController(text: _task['title']?.toString() ?? '');
    final descCtrl = TextEditingController(text: _task['description']?.toString() ?? '');
    String selectedPriority = (_task['priority']?.toString() ?? 'MEDIUM').toUpperCase();
    if (!['LOW', 'MEDIUM', 'HIGH', 'URGENT'].contains(selectedPriority)) {
      selectedPriority = 'MEDIUM';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.edit_outlined, color: _taskBrown, size: 22),
                SizedBox(width: 8),
                Text(
                  'Edit task',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Title *', style: TextStyle(color: _soft, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Task title',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Description', style: TextStyle(color: _soft, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Task description...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Priority', style: TextStyle(color: _soft, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPriority,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _line),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'LOW', child: Text('Low')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                      DropdownMenuItem(value: 'HIGH', child: Text('High')),
                      DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedPriority = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx, false),
                child: const Text('Cancel', style: TextStyle(color: _soft)),
              ),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(dlgCtx, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _taskBrown,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save changes'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    final taskId = _task['id']?.toString() ?? '';
    if (taskId.isEmpty) return;

    try {
      final body = <String, dynamic>{
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'priority': selectedPriority,
      };
      final res = await widget.api.v1('PATCH', '/tasks/$taskId', body: body);
      if (!mounted) return;
      message(context, 'Task updated');
      widget.onRefreshNeeded?.call();

      if (res is Map<String, dynamic> && res['data'] is Map) {
        setState(() {
          _task = Map<String, dynamic>.from(res['data'] as Map);
        });
      } else {
        await _fetchTaskDetails();
      }
    } catch (e) {
      if (mounted) message(context, e);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final taskId = _task['id']?.toString() ?? '';
    if (taskId.isEmpty) return;

    setState(() => _sendingComment = true);
    try {
      await widget.api.v1(
        'POST',
        '/tasks/$taskId/comments',
        body: {'body': text},
      );
      if (!mounted) return;
      _commentCtrl.clear();
      await _fetchTaskDetails();
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _map(_task['project']);
    final category = _map(_task['category']);
    final creator = _map(_task['creator']);
    final schedule = _map(_task['schedule']);
    final permissions = _map(_task['permissions']);

    final assignees = (_task['assignees'] is List)
        ? (_task['assignees'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];

    final watchers = (_task['watchers'] is List)
        ? (_task['watchers'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];

    final subtasks = (_task['subtasks'] is List)
        ? (_task['subtasks'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];

    final comments = (_task['comments'] is List)
        ? (_task['comments'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];

    final activities = (_task['activity'] is List)
        ? (_task['activity'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];

    final status = _task['status']?.toString() ?? 'TODO';
    final priority = _task['priority']?.toString() ?? 'MEDIUM';
    final isOverdue = _task['isOverdue'] == true;
    final canEdit = permissions.isEmpty || permissions['canEdit'] == true;
    final canUpdateStatus = permissions.isEmpty || permissions['canUpdateStatus'] == true;

    final projectName = project['name']?.toString() ?? '';
    final projectColor = _hex(project['color']) ?? _taskBrown;
    final categoryName = category['name']?.toString() ?? '';

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D7DE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Top action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _task['code']?.toString() ?? 'TASK',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (_loadingDetails) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _taskBrown),
                    ),
                  ],
                  const Spacer(),
                  if (canEdit)
                    IconButton(
                      tooltip: 'Edit task',
                      onPressed: _showEditDialog,
                      icon: const Icon(Icons.edit_outlined, size: 19, color: _ink),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20, color: _soft),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  // Badges Row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildStatusBadge(status),
                      _buildPriorityBadge(priority),
                      if (projectName.isNotEmpty)
                        _buildProjectBadge(projectName, projectColor),
                      if (categoryName.isNotEmpty)
                        _buildCategoryBadge(categoryName),
                      if (isOverdue) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(color: _red, fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    _task['title']?.toString() ?? 'Task',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Actions Toolbar (Complete, Reopen, Move back, Edit)
                  _buildActionsToolbar(status, canEdit, canUpdateStatus),
                  const SizedBox(height: 16),

                  // Description Card
                  _sectionHeader('Description'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Text(
                      (_task['description'] != null && _task['description'].toString().isNotEmpty)
                          ? _task['description'].toString()
                          : 'No description provided.',
                      style: TextStyle(
                        color: (_task['description'] != null && _task['description'].toString().isNotEmpty)
                            ? _ink
                            : _soft,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtasks Card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _sectionHeader('Subtasks (${_task['subtaskCompleted'] ?? 0}/${_task['subtaskCount'] ?? 0})'),
                      ),
                      TextButton.icon(
                        onPressed: () => comingSoon(context, 'Add subtask', 'Subtasks support is coming soon.'),
                        icon: const Icon(Icons.add_rounded, size: 16, color: _taskBrown),
                        label: const Text('Add subtask', style: TextStyle(color: _taskBrown, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: subtasks.isEmpty
                        ? const Text(
                            'No subtasks. Break the work into smaller steps with "Add subtask".',
                            style: TextStyle(color: _soft, fontSize: 13),
                          )
                        : Column(
                            children: [
                              for (final st in subtasks)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        st['status'] == 'COMPLETED' ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        size: 16,
                                        color: st['status'] == 'COMPLETED' ? _green : _soft,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          st['title']?.toString() ?? '',
                                          style: TextStyle(
                                            color: _ink,
                                            fontSize: 13,
                                            decoration: st['status'] == 'COMPLETED' ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Comments Card
                  _sectionHeader('Comments (${comments.length})'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'No comments yet. Start the conversation below.',
                              style: TextStyle(color: _soft, fontSize: 13),
                            ),
                          )
                        else
                          for (var i = 0; i < comments.length; i++) ...[
                            if (i > 0) const Divider(height: 18, color: _line),
                            _buildCommentItem(comments[i]),
                          ],
                        const SizedBox(height: 12),
                        // Comment input field
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Write a comment...',
                                  hintStyle: const TextStyle(fontSize: 13, color: _soft),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: _line),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: _line),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _sendingComment
                                ? const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _taskBrown),
                                  )
                                : IconButton(
                                    onPressed: _submitComment,
                                    icon: const Icon(Icons.send_rounded, color: _taskBrown, size: 20),
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFFCE9DA),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Context Card
                  _sectionHeader('Context'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text(
                                'Project',
                                style: TextStyle(color: _soft, fontSize: 12.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(color: projectColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      projectName.isNotEmpty ? projectName : 'None',
                                      style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18, color: _line),
                        _detailRow('Category', categoryName.isNotEmpty ? categoryName : 'None'),
                        const Divider(height: 18, color: _line),
                        _detailRow('Task Type', _pretty(_task['taskType']?.toString() ?? 'GENERAL')),
                        if (creator['fullName'] != null) ...[
                          const Divider(height: 18, color: _line),
                          _detailRow('Created by', creator['fullName'].toString()),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Schedule Card
                  _sectionHeader('Schedule'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      children: [
                        if (_task['startAt'] != null) ...[
                          _detailRow('Starts At', _formatIso(_task['startAt'].toString())),
                          const Divider(height: 18, color: _line),
                        ],
                        _detailRow(
                          'Due Date',
                          _task['dueAt'] != null
                              ? '${_formatIso(_task['dueAt'].toString())}${isOverdue ? ' (Overdue)' : ''}'
                              : 'None',
                        ),
                        if (_task['durationMinutes'] != null) ...[
                          const Divider(height: 18, color: _line),
                          _detailRow('Duration', '${_task['durationMinutes']} mins'),
                        ],
                        if (_task['timezone'] != null) ...[
                          const Divider(height: 18, color: _line),
                          _detailRow('Timezone', _task['timezone'].toString()),
                        ],
                        if (schedule['summary'] != null) ...[
                          const Divider(height: 18, color: _line),
                          _detailRow('Recurrence', schedule['summary'].toString()),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // People
                  _sectionHeader('People'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assignees',
                          style: TextStyle(color: _soft, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        if (assignees.isEmpty)
                          const Text('None', style: TextStyle(color: _ink, fontSize: 13))
                        else
                          for (final a in assignees)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: const Color(0xFFFCE9DA),
                                    child: Text(
                                      (a['fullName']?.toString() ?? 'A')[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 11, color: _taskBrown, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    a['fullName']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                                  ),
                                  if (a['employeeCode'] != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${a['employeeCode']})',
                                      style: const TextStyle(fontSize: 11.5, color: _soft),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        if (watchers.isNotEmpty) ...[
                          const Divider(height: 20, color: _line),
                          const Text(
                            'Watchers',
                            style: TextStyle(color: _soft, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          for (final w in watchers)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.visibility_outlined, size: 14, color: _soft),
                                  const SizedBox(width: 8),
                                  Text(
                                    w['fullName']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Activity Timeline (if any)
                  if (activities.isNotEmpty) ...[
                    _sectionHeader('Activity'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < activities.length; i++) ...[
                            if (i > 0) const Divider(height: 18, color: _line),
                            _buildActivityItem(activities[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsToolbar(String currentStatus, bool canEdit, bool canUpdateStatus) {
    if (_updatingStatus) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: _taskBrown),
        ),
      );
    }

    final s = currentStatus.toUpperCase();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (canUpdateStatus) ...[
            if (s == 'IN_PROGRESS') ...[
              OutlinedButton.icon(
                onPressed: () => _updateStatus('TODO'),
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: const Text('Move back to To Do'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: Color(0xFFD0D7DE)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _showCompleteDialog,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                label: const Text('Complete'),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ] else if (s == 'TODO') ...[
              FilledButton.icon(
                onPressed: () => _updateStatus('IN_PROGRESS'),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Start task'),
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _showCompleteDialog,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                label: const Text('Complete'),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ] else if (s == 'COMPLETED') ...[
              FilledButton.icon(
                onPressed: _showReopenDialog,
                icon: const Icon(Icons.replay_rounded, size: 17),
                label: const Text('Reopen task'),
                style: FilledButton.styleFrom(
                  backgroundColor: _taskBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
          if (canEdit) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _showEditDialog,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: Color(0xFFD0D7DE)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentItem(Json comment) {
    final author = _map(comment['author']);
    final authorName = author['fullName']?.toString() ?? 'User';
    final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U';
    final timeStr = _timeAgo(comment['createdAt']?.toString());
    final body = comment['body']?.toString() ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFF3E8FF),
          child: Text(
            initial,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 11, color: _soft),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(fontSize: 13, color: _ink, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(Json act) {
    final actor = _map(act['actor']);
    final actorName = actor['fullName']?.toString() ?? 'User';
    final type = act['type']?.toString() ?? '';
    final createdAt = act['createdAt']?.toString() ?? '';
    final data = _map(act['data']);

    String actionDesc;
    if (type == 'STATUS_CHANGED') {
      final to = data['to']?.toString() ?? '';
      final from = data['from']?.toString() ?? '';
      final comment = data['comment']?.toString();
      actionDesc = 'changed status from ${_pretty(from)} to ${_pretty(to)}'
          '${(comment != null && comment.isNotEmpty) ? ' ("$comment")' : ''}';
    } else if (type == 'CREATED') {
      actionDesc = 'created this task';
    } else if (type == 'UPDATED') {
      actionDesc = 'updated task details';
    } else {
      actionDesc = _pretty(type);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(color: _taskBrown, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12.5, color: _ink),
                  children: [
                    TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' $actionDesc'),
                  ],
                ),
              ),
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  _formatIso(createdAt),
                  style: const TextStyle(color: _soft, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: _soft, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityBadge(String priority) {
    final (bg, fg) = switch (priority.toUpperCase()) {
      'URGENT' => (const Color(0xFFFEE2E2), _red),
      'HIGH' => (const Color(0xFFFCE9DA), _taskBrown),
      'MEDIUM' => (const Color(0xFFFEF3C7), _amber),
      _ => (const Color(0xFFF1F5F9), _soft),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        '• ${_pretty(priority)}',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final (bg, fg) = switch (status.toUpperCase()) {
      'COMPLETED' || 'RESOLVED' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'IN_PROGRESS' => (const Color(0xFFDBEAFE), _blue),
      'CANCELLED' => (const Color(0xFFF1F5F9), _soft),
      _ => (const Color(0xFFFEF3C7), const Color(0xFF92400E)), // TODO
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        '• ${_pretty(status)}',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildProjectBadge(String name, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: const TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return _formatIso(iso);
  }

  String _formatIso(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hr = d.hour.toString().padLeft(2, '0');
    final mn = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hr:$mn';
  }

  String _pretty(String key) {
    if (key.isEmpty) return '';
    return key
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Map<String, dynamic> _map(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  Color? _hex(Object? v) {
    if (v is! String) return null;
    final clean = v.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return null;
  }
}
